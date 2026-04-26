-- ============================================================================
-- V4: APP-SIGNAL PILLARS
-- ============================================================================
-- Splits the conflated `quality_score` into separable pillars so the
-- recommender can blend them with explicit weights:
--
--   APP signal (~80% of final blend)
--     - app_engagement_score   (saves/dislikes/been_to from app)
--     - social_score           (friend graph; computed in Python)
--     - collaborative_score    (item-item similarity; computed in Python)
--     - video_insight_score    (count + sentiment + creator diversity + recency)
--
--   CATALOG signal (~20% of final blend)
--     - google_baseline_score  (Bayesian rating × log(reviews))
--     - vibe_score             (computed in Python from vectors)
--     - dietary_score          (computed in Python from vectors)
--
-- Plus a denormalised `share_count` cached on location_popularity_app so the
-- post-blend share_boost multiplier can be applied without per-request joins.
-- share_count = number of `user_location_actions` rows where
--    action = 'save' AND saved_method IN ('tiktok', 'instagram').
-- This counts saves originating from a social-video flow only.
--
-- NON-DESTRUCTIVE: this migration is purely additive.
--   * New columns on location_popularity_app are nullable / default 0.
--   * The existing `get_locations_with_quality` and `compute_quality_score`
--     functions are LEFT IN PLACE so the live API keeps working unchanged.
--   * `get_locations_with_pillars` is a NEW sibling function the v4 ranker
--     reads from. Old callers that still hit the legacy RPC continue to
--     work; the legacy `quality_score` it returns is unaffected.

-- ============================================================================
-- 1. NEW PILLAR COLUMNS ON location_popularity_app
-- ============================================================================

ALTER TABLE public.location_popularity_app
    ADD COLUMN IF NOT EXISTS share_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS app_engagement_score NUMERIC,
    ADD COLUMN IF NOT EXISTS google_baseline_score NUMERIC,
    ADD COLUMN IF NOT EXISTS video_insight_score NUMERIC,
    -- Denormalised geography copied from locations.geog. Lets the spatial
    -- filter for engaged places hit a small, hot table with its own GIST
    -- index instead of joining the full locations table.
    ADD COLUMN IF NOT EXISTS geog GEOGRAPHY(Point, 4326);

CREATE INDEX IF NOT EXISTS idx_lpa_share_count
    ON public.location_popularity_app (share_count DESC);

CREATE INDEX IF NOT EXISTS idx_lpa_geog
    ON public.location_popularity_app USING GIST (geog);


-- ============================================================================
-- 2. APP ENGAGEMENT SCORE
-- ============================================================================
-- Pure in-app behaviour. No Google rating mixed in. Range [0, 1].
-- Combines volume (log-saturated) with negative-feedback ratio.

CREATE OR REPLACE FUNCTION compute_app_engagement_score(
    p_saves_count INTEGER,
    p_dislikes_count INTEGER,
    p_been_to_count INTEGER
) RETURNS NUMERIC AS $$
DECLARE
    saves INTEGER := COALESCE(p_saves_count, 0);
    dislikes INTEGER := COALESCE(p_dislikes_count, 0);
    been_to INTEGER := COALESCE(p_been_to_count, 0);
    -- been_to is the strongest positive signal (user actually visited)
    weighted_positive NUMERIC := saves + 1.5 * been_to;
    volume_score NUMERIC;
    dislike_ratio NUMERIC;
BEGIN
    -- Log-saturated volume in [0, 1]; ~50 weighted positives → 0.85
    volume_score := LEAST(LN(1 + weighted_positive) / LN(75), 1.0);

    -- Penalise high-dislike places. Soft additive smoothing.
    IF (weighted_positive + dislikes) > 0 THEN
        dislike_ratio := dislikes::NUMERIC / (weighted_positive + dislikes + 1);
    ELSE
        dislike_ratio := 0.0;
    END IF;

    RETURN GREATEST(0.0, volume_score * (1.0 - dislike_ratio));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ============================================================================
-- 3. GOOGLE BASELINE SCORE
-- ============================================================================
-- Catalog signal, separated from app behaviour. Bayesian-shrunk rating with
-- review-count trust. Range [0, 1].

CREATE OR REPLACE FUNCTION compute_google_baseline_score(
    p_rating FLOAT,
    p_user_ratings_total NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
    bayesian_rating NUMERIC;
    review_trust NUMERIC;
BEGIN
    -- Shrink towards 3.8 prior with 50 pseudo-reviews
    bayesian_rating := (COALESCE(p_rating, 3.8) * COALESCE(p_user_ratings_total, 0)
                        + 3.8 * 50)
                       / (COALESCE(p_user_ratings_total, 0) + 50);

    -- Log-power trust curve: ~500 reviews → 0.95
    review_trust := LEAST(
        0.95 * POWER(LN(1 + COALESCE(p_user_ratings_total, 0)) / LN(501), 0.6),
        1.0
    );

    -- Anti-mispricing cap so review volume can't overwhelm rating
    RETURN (bayesian_rating / 5.0)
           * LEAST(review_trust, 0.85 + 0.15 * (bayesian_rating / 5.0));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ============================================================================
-- 4. VIDEO INSIGHT SCORE
-- ============================================================================
-- Built from video_insights rows. Distinct creators count more than repeats
-- from one creator (independent endorsements). Sentiment shifts the score up
-- or down. Recency decay over 180 days. Range [0, 1].

CREATE OR REPLACE FUNCTION compute_video_insight_score(
    p_location_id BIGINT
) RETURNS NUMERIC AS $$
DECLARE
    distinct_creators INTEGER;
    total_videos INTEGER;
    pos_videos INTEGER;
    neg_videos INTEGER;
    avg_age_days NUMERIC;
    volume_score NUMERIC;
    sentiment_factor NUMERIC;
    recency_factor NUMERIC;
BEGIN
    SELECT
        COUNT(DISTINCT NULLIF(creator_handle, '')),
        COUNT(*),
        COUNT(*) FILTER (WHERE sentiment IN ('positive', 'very_positive')),
        COUNT(*) FILTER (WHERE sentiment IN ('negative', 'very_negative')),
        COALESCE(AVG(EXTRACT(EPOCH FROM (NOW() - extracted_at)) / 86400.0), 180)
    INTO distinct_creators, total_videos, pos_videos, neg_videos, avg_age_days
    FROM public.video_insights
    WHERE location_id = p_location_id;

    IF COALESCE(total_videos, 0) = 0 THEN
        RETURN 0.0;
    END IF;

    -- Distinct creators dominate volume (3 creators → 0.7, 10 → ~1.0)
    volume_score := LEAST(LN(1 + COALESCE(distinct_creators, 0)) / LN(11), 1.0);

    -- Sentiment factor in [0.4, 1.2]: very negative drags down, positive lifts
    IF total_videos > 0 THEN
        sentiment_factor := 0.8
            + 0.4 * (pos_videos::NUMERIC / total_videos)
            - 0.4 * (neg_videos::NUMERIC / total_videos);
    ELSE
        sentiment_factor := 1.0;
    END IF;
    sentiment_factor := GREATEST(0.4, LEAST(sentiment_factor, 1.2));

    -- Recency: half-life 180 days
    recency_factor := EXP(-avg_age_days / 180.0);

    RETURN GREATEST(0.0, LEAST(volume_score * sentiment_factor * recency_factor, 1.0));
END;
$$ LANGUAGE plpgsql STABLE;


-- ============================================================================
-- 5. SHARE COUNT MAINTENANCE
-- ============================================================================
-- share_count = COUNT(user_location_actions) where:
--     action = 'save' AND saved_method IN ('tiktok', 'instagram').
--
-- This intentionally only counts saves that originated from a social-video
-- flow. video_insights rows are NOT counted here because a single video can
-- exist independent of a user save and is captured by `video_insight_score`.

CREATE OR REPLACE FUNCTION recompute_location_share_count(p_location_id BIGINT)
RETURNS VOID AS $$
DECLARE
    total INTEGER;
BEGIN
    SELECT COUNT(*) INTO total
    FROM public.user_location_actions
    WHERE location_id = p_location_id
      AND action = 'save'
      AND saved_method IN ('tiktok', 'instagram');

    INSERT INTO public.location_popularity_app (location_id, share_count)
    VALUES (p_location_id, COALESCE(total, 0))
    ON CONFLICT (location_id) DO UPDATE
        SET share_count = EXCLUDED.share_count,
            updated_at = NOW();
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION trg_user_location_actions_share_count()
RETURNS TRIGGER AS $$
DECLARE
    is_relevant_old BOOLEAN := FALSE;
    is_relevant_new BOOLEAN := FALSE;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') AND OLD IS NOT NULL THEN
        is_relevant_old := (OLD.action = 'save'
                            AND OLD.saved_method IN ('tiktok', 'instagram'));
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') AND NEW IS NOT NULL THEN
        is_relevant_new := (NEW.action = 'save'
                            AND NEW.saved_method IN ('tiktok', 'instagram'));
    END IF;

    -- Recompute when the row touches the predicate on either side.
    IF is_relevant_new THEN
        PERFORM recompute_location_share_count(NEW.location_id);
    END IF;
    IF is_relevant_old AND (NEW IS NULL OR OLD.location_id IS DISTINCT FROM NEW.location_id) THEN
        PERFORM recompute_location_share_count(OLD.location_id);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS user_location_actions_share_count_trg ON public.user_location_actions;
CREATE TRIGGER user_location_actions_share_count_trg
    AFTER INSERT OR UPDATE OR DELETE ON public.user_location_actions
    FOR EACH ROW EXECUTE FUNCTION trg_user_location_actions_share_count();

-- The video_insights → share_count trigger from earlier drafts is removed:
-- video_insights rows no longer contribute to share_count under the new
-- definition. (They still feed `video_insight_score` directly via the
-- compute_video_insight_score function below.) Defensively drop it in
-- case a previous deploy applied it.
DROP TRIGGER IF EXISTS video_insights_share_count_trg ON public.video_insights;
DROP FUNCTION IF EXISTS trg_video_insights_share_count();


-- ============================================================================
-- 6. BACKFILL HELPER (run once after deploy)
-- ============================================================================

CREATE OR REPLACE FUNCTION backfill_app_signal_pillars()
RETURNS INTEGER AS $$
DECLARE
    rows_updated INTEGER := 0;
    loc RECORD;
BEGIN
    FOR loc IN
        SELECT
            l.location_id,
            l.rating,
            l.user_ratings_total,
            COALESCE(lp.saves_count, 0) AS saves_count,
            COALESCE(lp.dislikes_count, 0) AS dislikes_count,
            COALESCE(lp.been_to_count, 0) AS been_to_count
        FROM public.locations l
        LEFT JOIN public.location_popularity_app lp ON lp.location_id = l.location_id
    LOOP
        INSERT INTO public.location_popularity_app (
            location_id,
            saves_count, dislikes_count, been_to_count,
            app_engagement_score,
            google_baseline_score,
            video_insight_score
        )
        VALUES (
            loc.location_id,
            loc.saves_count, loc.dislikes_count, loc.been_to_count,
            compute_app_engagement_score(loc.saves_count, loc.dislikes_count, loc.been_to_count),
            compute_google_baseline_score(loc.rating, loc.user_ratings_total),
            compute_video_insight_score(loc.location_id)
        )
        ON CONFLICT (location_id) DO UPDATE SET
            app_engagement_score  = EXCLUDED.app_engagement_score,
            google_baseline_score = EXCLUDED.google_baseline_score,
            video_insight_score   = EXCLUDED.video_insight_score,
            updated_at            = NOW();

        PERFORM recompute_location_share_count(loc.location_id);
        rows_updated := rows_updated + 1;
    END LOOP;
    RETURN rows_updated;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- 7. NEW RPC: surface the pillar columns to the API
-- ============================================================================
-- Returns the four pillars individually so the Python ranker can apply
-- request-specific weights without recomputing.
--
-- IMPORTANT: this is added as a NEW function alongside the existing
-- `get_locations_with_quality`. The legacy RPC is intentionally NOT
-- dropped — live API code paths that still call it must keep working
-- through the rollout. Once all callers migrate to
-- `get_locations_with_pillars`, the legacy function can be removed in a
-- follow-up migration.

CREATE OR REPLACE FUNCTION get_locations_with_pillars(
    center_lat DOUBLE PRECISION,
    center_lng DOUBLE PRECISION,
    radius_meters DOUBLE PRECISION,
    result_limit INT DEFAULT 1000
)
RETURNS TABLE(
    location_id BIGINT,
    name TEXT,
    vicinity TEXT,
    lat NUMERIC,
    lng NUMERIC,
    cuisine TEXT,
    cuisine_primary TEXT,
    rating REAL,
    user_ratings_total NUMERIC,
    price_level NUMERIC,
    google_place_id TEXT,
    types TEXT,
    emoji TEXT,
    vibe_vector INT[],
    dietary_requirement_vector INT[],
    distance_km FLOAT,
    -- Pillar scores (precomputed, 0..1)
    app_engagement_score NUMERIC,
    google_baseline_score NUMERIC,
    video_insight_score NUMERIC,
    share_count INTEGER,
    -- Provenance: TRUE if the row had a location_popularity_app entry
    -- (i.e. it's a "known" place with engagement); FALSE for the fill set.
    has_app_signal BOOLEAN,
    -- Backwards-compat: legacy quality_score = blended pillar for old callers
    quality_score NUMERIC
) AS $$
BEGIN
    -- Inventory strategy:
    --   1) PRIMARY  – locations that have a row in location_popularity_app
    --                 within the radius, ordered by distance, up to result_limit.
    --   2) FILL     – if primary < result_limit, top up with locations
    --                 NOT in location_popularity_app within the same radius,
    --                 ordered by distance. These get null/zero pillar scores
    --                 so they rank below known places naturally.
    --
    -- This favours places with real app engagement signal while still
    -- letting the recommender surface unknown-but-nearby Google-only
    -- locations when the engaged set is sparse (new market, late-night, etc).

    RETURN QUERY
    WITH point AS (
        SELECT ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography AS g
    ),
    -- ── 1) PRIMARY: locations with an entry in location_popularity_app.
    -- Spatial filter runs against lp.geog (denormalised + GIST-indexed)
    -- so the engaged-places lookup never touches the full locations table.
    primary_set AS (
        SELECT
            l.*,
            ST_Distance(lp.geog, (SELECT g FROM point)) / 1000.0 AS dist_km,
            lp.app_engagement_score   AS lp_app_engagement,
            lp.google_baseline_score  AS lp_google_baseline,
            lp.video_insight_score    AS lp_video_insight,
            lp.share_count            AS lp_share_count,
            TRUE                      AS has_signal
        FROM public.location_popularity_app lp
        INNER JOIN public.locations l ON l.location_id = lp.location_id
        WHERE lp.geog IS NOT NULL
          AND ST_DWithin(lp.geog, (SELECT g FROM point), radius_meters)
        ORDER BY ST_Distance(lp.geog, (SELECT g FROM point)) ASC
        LIMIT result_limit
    ),
    -- ── 2) FILL: nearby locations NOT in location_popularity_app ───────
    fill_set AS (
        SELECT
            l.*,
            ST_Distance(l.geog, (SELECT g FROM point)) / 1000.0 AS dist_km,
            NULL::NUMERIC  AS lp_app_engagement,
            NULL::NUMERIC  AS lp_google_baseline,
            NULL::NUMERIC  AS lp_video_insight,
            NULL::INTEGER  AS lp_share_count,
            FALSE          AS has_signal
        FROM public.locations l
        WHERE l.geog IS NOT NULL
          AND ST_DWithin(l.geog, (SELECT g FROM point), radius_meters)
          AND NOT EXISTS (
              SELECT 1 FROM public.location_popularity_app lp
              WHERE lp.location_id = l.location_id
          )
        ORDER BY ST_Distance(l.geog, (SELECT g FROM point)) ASC
        LIMIT GREATEST(result_limit - (SELECT COUNT(*) FROM primary_set)::INT, 0)
    ),
    combined AS (
        SELECT * FROM primary_set
        UNION ALL
        SELECT * FROM fill_set
    )
    SELECT
        c.location_id,
        c.name,
        c.vicinity,
        c.lat,
        c.lng,
        c.cuisine,
        c.cuisine_primary,
        c.rating,
        c.user_ratings_total,
        c.price_level,
        c.google_place_id,
        c.types,
        c.emoji,
        c.vibe_vector,
        c.dietary_requirement_vector,
        c.dist_km AS distance_km,
        COALESCE(c.lp_app_engagement, 0.0) AS app_engagement_score,
        COALESCE(c.lp_google_baseline,
                 compute_google_baseline_score(c.rating, c.user_ratings_total)) AS google_baseline_score,
        COALESCE(c.lp_video_insight, 0.0) AS video_insight_score,
        COALESCE(c.lp_share_count, 0) AS share_count,
        c.has_signal AS has_app_signal,
        -- Legacy blended score so callers reading `quality_score` keep working
        (0.55 * COALESCE(c.lp_app_engagement, 0.0)
         + 0.30 * COALESCE(c.lp_google_baseline,
                           compute_google_baseline_score(c.rating, c.user_ratings_total))
         + 0.15 * COALESCE(c.lp_video_insight, 0.0)) AS quality_score
    FROM combined c
    -- Primary set first (has_signal=TRUE), then fill, then by distance
    ORDER BY c.has_signal DESC, c.dist_km ASC;
END;
$$ LANGUAGE plpgsql STABLE;


-- ============================================================================
-- 7b. AUTO-POPULATE `geog` ON locations
-- ============================================================================
-- New locations are coming in with lat/lng but no geog, which silently
-- excludes them from PostGIS spatial filtering. This trigger derives geog
-- from lat/lng on INSERT and on UPDATE-of-coordinates so the application
-- code doesn't need to remember to set it.

CREATE OR REPLACE FUNCTION trg_locations_set_geog()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL THEN
        -- Only recompute when geog is missing OR the coords changed.
        IF NEW.geog IS NULL
           OR TG_OP = 'INSERT'
           OR OLD.lat IS DISTINCT FROM NEW.lat
           OR OLD.lng IS DISTINCT FROM NEW.lng
        THEN
            NEW.geog := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS locations_set_geog_trg ON public.locations;
CREATE TRIGGER locations_set_geog_trg
    BEFORE INSERT OR UPDATE OF lat, lng, geog ON public.locations
    FOR EACH ROW EXECUTE FUNCTION trg_locations_set_geog();


-- Backfill any existing rows that have lat/lng but no geog.
CREATE OR REPLACE FUNCTION backfill_locations_geog()
RETURNS INTEGER AS $$
DECLARE
    updated INTEGER;
BEGIN
    WITH upd AS (
        UPDATE public.locations
        SET geog = ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
        WHERE geog IS NULL
          AND lat IS NOT NULL
          AND lng IS NOT NULL
        RETURNING 1
    )
    SELECT COUNT(*) INTO updated FROM upd;
    RETURN updated;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- 7c. KEEP location_popularity_app.geog IN SYNC WITH locations.geog
-- ============================================================================
-- The popularity table denormalises geog from locations so the engaged-
-- places spatial filter can run against a small indexed table directly.
-- Maintained two ways:
--   (a) when locations.geog changes, propagate to popularity_app
--   (b) when a popularity_app row is inserted with no geog, look it up
--       from locations on the spot.

CREATE OR REPLACE FUNCTION trg_locations_propagate_geog()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.geog IS DISTINCT FROM OLD.geog THEN
        UPDATE public.location_popularity_app
        SET geog = NEW.geog,
            updated_at = NOW()
        WHERE location_id = NEW.location_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS locations_propagate_geog_trg ON public.locations;
CREATE TRIGGER locations_propagate_geog_trg
    AFTER UPDATE OF geog ON public.locations
    FOR EACH ROW EXECUTE FUNCTION trg_locations_propagate_geog();


CREATE OR REPLACE FUNCTION trg_lpa_fill_geog()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.geog IS NULL THEN
        SELECT l.geog INTO NEW.geog
        FROM public.locations l
        WHERE l.location_id = NEW.location_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS lpa_fill_geog_trg ON public.location_popularity_app;
CREATE TRIGGER lpa_fill_geog_trg
    BEFORE INSERT OR UPDATE OF location_id ON public.location_popularity_app
    FOR EACH ROW EXECUTE FUNCTION trg_lpa_fill_geog();


-- Backfill geog for existing popularity_app rows.
CREATE OR REPLACE FUNCTION backfill_lpa_geog()
RETURNS INTEGER AS $$
DECLARE
    updated INTEGER;
BEGIN
    WITH upd AS (
        UPDATE public.location_popularity_app lp
        SET geog = l.geog,
            updated_at = NOW()
        FROM public.locations l
        WHERE lp.location_id = l.location_id
          AND lp.geog IS DISTINCT FROM l.geog
          AND l.geog IS NOT NULL
        RETURNING 1
    )
    SELECT COUNT(*) INTO updated FROM upd;
    RETURN updated;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- 8. PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION compute_app_engagement_score(INTEGER, INTEGER, INTEGER) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION compute_google_baseline_score(FLOAT, NUMERIC) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION compute_video_insight_score(BIGINT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_locations_with_pillars TO authenticated, anon;
GRANT EXECUTE ON FUNCTION recompute_location_share_count(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION backfill_app_signal_pillars() TO authenticated;
GRANT EXECUTE ON FUNCTION backfill_locations_geog() TO authenticated;
GRANT EXECUTE ON FUNCTION backfill_lpa_geog() TO authenticated;
