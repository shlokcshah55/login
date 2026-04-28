-- ============================================================================
-- FIX: get_locations_with_pillars return signature uses REAL[] vibe vectors
-- ============================================================================
-- The 2026-04-27 v6 migration reintroduced `vibe_vector INT[]` in the RPC
-- signature even though `locations.vibe_vector` is `REAL[]`. Postgres then
-- rejects every RPC call with:
--   returned type real[] does not match expected type integer[] in column 14
--
-- Apply a forward migration so already-migrated Supabase databases are
-- repaired in place. The query body is otherwise unchanged.
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_locations_with_pillars(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT
);

CREATE OR REPLACE FUNCTION public.get_locations_with_pillars(
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
    vibe_vector REAL[],
    dietary_requirement_vector INT[],
    distance_km FLOAT,
    app_engagement_score NUMERIC,
    google_baseline_score NUMERIC,
    video_insight_score NUMERIC,
    share_count INTEGER,
    has_app_signal BOOLEAN,
    quality_bias NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH point AS (
        SELECT ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography AS g
    ),
    primary_set AS (
        SELECT
            l.*,
            ST_Distance(lp.geog, (SELECT g FROM point)) / 1000.0 AS dist_km,
            lp.app_engagement_score   AS lp_app_engagement,
            lp.google_baseline_score  AS lp_google_baseline,
            lp.video_insight_score    AS lp_video_insight,
            lp.share_count            AS lp_share_count,
            lp.quality_score          AS lp_quality_bias,
            TRUE                      AS has_signal
        FROM public.location_popularity_app lp
        INNER JOIN public.locations l ON l.location_id = lp.location_id
        WHERE lp.geog IS NOT NULL
          AND ST_DWithin(lp.geog, (SELECT g FROM point), radius_meters)
        ORDER BY ST_Distance(lp.geog, (SELECT g FROM point)) ASC
        LIMIT result_limit
    ),
    fill_set AS (
        SELECT
            l.*,
            ST_Distance(l.geog, (SELECT g FROM point)) / 1000.0 AS dist_km,
            NULL::NUMERIC  AS lp_app_engagement,
            NULL::NUMERIC  AS lp_google_baseline,
            NULL::NUMERIC  AS lp_video_insight,
            NULL::INTEGER  AS lp_share_count,
            NULL::NUMERIC  AS lp_quality_bias,
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
        COALESCE(
            c.lp_google_baseline,
            compute_google_baseline_score(c.rating, c.user_ratings_total)
        ) AS google_baseline_score,
        COALESCE(c.lp_video_insight, 0.0) AS video_insight_score,
        COALESCE(c.lp_share_count, 0) AS share_count,
        c.has_signal AS has_app_signal,
        COALESCE(c.lp_quality_bias, 0.0) AS quality_bias
    FROM combined c
    ORDER BY c.has_signal DESC, c.dist_km ASC;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION public.get_locations_with_pillars(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT
) TO authenticated, anon, service_role;
