-- ============================================================================
-- V4: SIMPLE APP-FIRST QUALITY SCORE
-- ============================================================================
-- Replaces the v3 Bayesian/velocity/cold-start composite with a simple,
-- app-driven score that is precomputed by a nightly pg_cron job and stored
-- on location_popularity_app.quality_score. The RPC just reads the cached
-- value, making request-time scoring effectively free.
--
-- Components (per location):
--   shares_count    = count of user_location_actions where source_video_url IS NOT NULL
--   been_to_count   = count of user_location_actions where action = 'been_to'
--   saves_count     = count of user_location_actions where action = 'save'
--   dislikes_count  = count of user_location_actions where action = 'dislike'
--   review_signal   = sentiment-weighted sum of location_reviews.rating (0-10 scale)
--   google rating   = sanity-check multiplier only
-- ============================================================================


-- ============================================================================
-- 1. DROP THE OLD V3 SCORING FUNCTION
-- ============================================================================
-- The 8-arg Bayesian function is no longer used; the RPC reads quality_score
-- directly from location_popularity_app.

DROP FUNCTION IF EXISTS compute_quality_score(
  FLOAT, NUMERIC, SMALLINT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
);


-- ============================================================================
-- 2. NEW: compute_app_quality_score
-- ============================================================================
-- Pure formula. Takes already-aggregated counts and the precomputed
-- review_signal (in [-1, +1]) and returns a quality score in [0, 1].
--
-- Tuning handles:
--   * Saturation thresholds: 50 / 100 / 200 (shares / been_to / saves)
--   * Component weights:     0.30 / 0.30 / 0.20 / 0.20
--   * Google penalty levels: 0.75 (no data), 0.5 (sub-4-star)

CREATE OR REPLACE FUNCTION compute_app_quality_score(
  p_shares_count   INTEGER,
  p_been_to_count  INTEGER,
  p_saves_count    INTEGER,
  p_review_signal  NUMERIC,   -- pre-aggregated sentiment in [-1, +1]
  p_dislikes_count INTEGER,
  p_google_rating  REAL,
  p_google_total   NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
  s_shares       NUMERIC;
  s_been_to      NUMERIC;
  s_saves        NUMERIC;
  app_engagement NUMERIC;
  pos_total      INTEGER;
  dislike_factor NUMERIC;
  google_mult    NUMERIC;
BEGIN
  -- 1. Log-normalize the count signals to [0, 1]
  s_shares  := LEAST(LN(1 + COALESCE(p_shares_count,  0)) / LN(1 + 50),  1.0);
  s_been_to := LEAST(LN(1 + COALESCE(p_been_to_count, 0)) / LN(1 + 100), 1.0);
  s_saves   := LEAST(LN(1 + COALESCE(p_saves_count,   0)) / LN(1 + 200), 1.0);

  -- 2. Weighted app engagement (review_signal is signed, so this can be negative)
  app_engagement := (0.30 * s_shares)
                  + (0.30 * s_been_to)
                  + (0.20 * s_saves)
                  + (0.20 * COALESCE(p_review_signal, 0));

  -- 3. Multiplicative dislike penalty
  pos_total := COALESCE(p_saves_count, 0)
             + COALESCE(p_been_to_count, 0)
             + COALESCE(p_shares_count, 0);
  IF (pos_total + COALESCE(p_dislikes_count, 0)) > 0 THEN
    dislike_factor := 1.0 - (COALESCE(p_dislikes_count, 0)::NUMERIC
                             / (pos_total + COALESCE(p_dislikes_count, 0) + 1));
  ELSE
    dislike_factor := 1.0;
  END IF;
  app_engagement := app_engagement * dislike_factor;

  -- 4. Google multiplier — three states
  IF p_google_total IS NULL OR p_google_total < 5 THEN
    google_mult := 0.75;        -- no Google data: mild penalty
  ELSIF p_google_rating IS NULL OR p_google_rating < 4.0 THEN
    google_mult := 0.5;         -- confirmed sub-4-star: bigger penalty
  ELSE
    google_mult := 1.0;         -- 4★ or better with real data: no penalty
  END IF;

  -- 5. Final clamp to [0, 1]
  RETURN GREATEST(0.0, LEAST(1.0, app_engagement * google_mult));
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ============================================================================
-- 3. NEW: refresh_location_quality_scores
-- ============================================================================
-- One-shot batch refresh: aggregates everything from source tables and
-- upserts location_popularity_app for every location. Designed to run
-- nightly via pg_cron, but also callable manually or from Python for
-- backfills and tuning iterations.
--
-- Returns the number of rows touched.

CREATE OR REPLACE FUNCTION refresh_location_quality_scores()
RETURNS INTEGER AS $$
DECLARE
  affected INTEGER;
BEGIN
  WITH action_stats AS (
    SELECT
      location_id,
      COUNT(*) FILTER (WHERE action = 'save')              AS saves_count,
      COUNT(*) FILTER (WHERE action = 'been_to')           AS been_to_count,
      COUNT(*) FILTER (WHERE action = 'dislike')           AS dislikes_count,
      COUNT(*) FILTER (WHERE source_video_url IS NOT NULL) AS shares_count
    FROM user_location_actions
    GROUP BY location_id
  ),
  review_stats AS (
    -- Sentiment-weighted sum: piecewise per-review weight in [-1, +1],
    -- divided by saturation 10 and then clipped at the call site below.
    SELECT
      location_id,
      SUM(
        CASE
          WHEN rating IS NULL THEN 0
          WHEN rating < 5   THEN -((5 - rating) / 5.0)
          WHEN rating > 6.5 THEN  ((rating - 6.5) / 3.5)
          ELSE 0
        END
      )::NUMERIC / 10.0 AS review_signal_raw
    FROM location_reviews
    GROUP BY location_id
  )
  INSERT INTO location_popularity_app (
    location_id, saves_count, dislikes_count, been_to_count, quality_score, updated_at
  )
  SELECT
    l.location_id,
    COALESCE(a.saves_count,    0)::INTEGER,
    COALESCE(a.dislikes_count, 0)::INTEGER,
    COALESCE(a.been_to_count,  0)::INTEGER,
    compute_app_quality_score(
      COALESCE(a.shares_count,    0)::INTEGER,
      COALESCE(a.been_to_count,   0)::INTEGER,
      COALESCE(a.saves_count,     0)::INTEGER,
      GREATEST(-1.0, LEAST(1.0, COALESCE(r.review_signal_raw, 0))),
      COALESCE(a.dislikes_count,  0)::INTEGER,
      l.rating,
      l.user_ratings_total
    ),
    NOW()
  FROM locations l
  LEFT JOIN action_stats a ON a.location_id = l.location_id
  LEFT JOIN review_stats r ON r.location_id = l.location_id
  ON CONFLICT (location_id) DO UPDATE SET
    saves_count    = EXCLUDED.saves_count,
    dislikes_count = EXCLUDED.dislikes_count,
    been_to_count  = EXCLUDED.been_to_count,
    quality_score  = EXCLUDED.quality_score,
    updated_at     = NOW();

  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- 4. REPLACE get_locations_with_quality
-- ============================================================================
-- Simplified RPC: reads quality_score directly from location_popularity_app
-- instead of recomputing per request. Same RETURNS TABLE shape as v3 so
-- the Python side keeps working unchanged.

DROP FUNCTION IF EXISTS get_locations_with_quality(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT
);

CREATE OR REPLACE FUNCTION get_locations_with_quality(
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION,
  result_limit INT DEFAULT 7000
)
RETURNS TABLE(
  location_id BIGINT,
  name TEXT,
  vicinity TEXT,
  lat NUMERIC,
  lng NUMERIC,
  created_at TIMESTAMP,
  cuisine TEXT,
  rating REAL,
  user_ratings_total NUMERIC,
  price_level NUMERIC,
  photo_reference TEXT,
  saved_count SMALLINT,
  google_place_id TEXT,
  business_status TEXT,
  editorial_summary TEXT,
  website TEXT,
  international_phone_number TEXT,
  types TEXT,
  opening_hours_text TEXT[],
  opening_hours_periods JSONB,
  open_now BOOLEAN,
  cuisine_detected TEXT,
  cuisine_source TEXT,
  cuisine_primary TEXT,
  review_language_counts_json JSONB,
  is_open_late BOOLEAN,
  is_open_early BOOLEAN,
  is_sunday_open BOOLEAN,
  price_bucket TEXT,
  derived_attributes JSONB,
  data_version TEXT,
  ingested_at TIMESTAMP,
  emoji TEXT,
  vibe_vector INT[],
  dietary_requirement_vector INT[],
  distance_km FLOAT,
  quality_score FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.location_id,
    l.name,
    l.vicinity,
    l.lat,
    l.lng,
    l.created_at,
    l.cuisine,
    l.rating,
    l.user_ratings_total,
    l.price_level,
    l.photo_reference,
    l.saved_count,
    l.google_place_id,
    l.business_status,
    l.editorial_summary,
    l.website,
    l.international_phone_number,
    l.types,
    l.opening_hours_text,
    l.opening_hours_periods,
    l.open_now,
    l.cuisine_detected,
    l.cuisine_source,
    l.cuisine_primary,
    l.review_language_counts_json,
    l.is_open_late,
    l.is_open_early,
    l.is_sunday_open,
    l.price_bucket,
    l.derived_attributes,
    l.data_version,
    l.ingested_at,
    l.emoji,
    l.vibe_vector,
    l.dietary_requirement_vector,
    (ST_Distance(
      l.geog,
      ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography
    ) / 1000.0)::FLOAT AS distance_km,
    COALESCE(lpa.quality_score, 0.0)::FLOAT AS quality_score
  FROM locations l
  LEFT JOIN location_popularity_app lpa ON lpa.location_id = l.location_id
  WHERE ST_DWithin(
    l.geog,
    ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography,
    radius_meters
  )
  ORDER BY distance_km ASC
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql STABLE;


-- ============================================================================
-- 5. PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION compute_app_quality_score(
  INTEGER, INTEGER, INTEGER, NUMERIC, INTEGER, REAL, NUMERIC
) TO authenticated, anon, service_role;

GRANT EXECUTE ON FUNCTION refresh_location_quality_scores() TO service_role;

GRANT EXECUTE ON FUNCTION get_locations_with_quality(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT
) TO authenticated, anon, service_role;


-- ============================================================================
-- 6. SCHEDULE NIGHTLY REFRESH VIA pg_cron
-- ============================================================================
-- Runs at 03:00 UTC every night. Bump frequency later if needed.

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Idempotent scheduling: unschedule any existing job with the same name first.
DO $$
BEGIN
  PERFORM cron.unschedule('refresh-location-quality')
  WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'refresh-location-quality'
  );
EXCEPTION WHEN OTHERS THEN
  -- cron.unschedule raises if the job doesn't exist; ignore.
  NULL;
END $$;

SELECT cron.schedule(
  'refresh-location-quality',
  '0 3 * * *',
  $$SELECT refresh_location_quality_scores();$$
);


-- ============================================================================
-- 7. SEED THE TABLE NOW
-- ============================================================================
-- Don't wait until 3am for the first run.

SELECT refresh_location_quality_scores();
