-- ============================================================================
-- ADD: get_fill_locations RPC for cache warming fill-set queries
-- ============================================================================
-- The API cache path loads engaged places from the Redis LPA snapshot, then
-- calls this RPC only for nearby locations that are not in LPA. This keeps
-- warm-cache refreshes and cache misses from running the full two-branch
-- get_locations_with_pillars RPC for every zone.
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_fill_locations(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT
);

CREATE OR REPLACE FUNCTION public.get_fill_locations(
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
) LANGUAGE sql STABLE
AS $$
    WITH center AS (
        SELECT ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography AS g
    ),
    fill_candidates AS (
        SELECT
            l.location_id,
            l.name,
            l.vicinity,
            l.lat,
            l.lng,
            l.cuisine,
            l.cuisine_primary,
            l.rating,
            l.user_ratings_total,
            l.price_level,
            l.google_place_id,
            l.types,
            l.emoji,
            l.vibe_vector,
            l.dietary_requirement_vector,
            (ST_Distance(l.geog, center.g) / 1000.0)::FLOAT AS distance_km,
            0.0::NUMERIC AS app_engagement_score,
            compute_google_baseline_score(l.rating, l.user_ratings_total) AS google_baseline_score,
            0.0::NUMERIC AS video_insight_score,
            0::INTEGER AS share_count,
            FALSE AS has_app_signal,
            0.0::NUMERIC AS quality_bias,
            ROW_NUMBER() OVER (ORDER BY l.geog <-> center.g, l.location_id ASC) AS rn
        FROM public.locations l
        CROSS JOIN center
        WHERE l.geog IS NOT NULL
          AND ST_DWithin(l.geog, center.g, radius_meters)
          AND NOT EXISTS (
              SELECT 1
              FROM public.location_popularity_app lp
              WHERE lp.location_id = l.location_id
          )
        ORDER BY l.geog <-> center.g
        LIMIT result_limit
    )
    SELECT
        fc.location_id,
        fc.name,
        fc.vicinity,
        fc.lat,
        fc.lng,
        fc.cuisine,
        fc.cuisine_primary,
        fc.rating,
        fc.user_ratings_total,
        fc.price_level,
        fc.google_place_id,
        fc.types,
        fc.emoji,
        fc.vibe_vector,
        fc.dietary_requirement_vector,
        fc.distance_km,
        fc.app_engagement_score,
        fc.google_baseline_score,
        fc.video_insight_score,
        fc.share_count,
        fc.has_app_signal,
        fc.quality_bias
    FROM fill_candidates fc
    WHERE fc.rn <= result_limit
    ORDER BY fc.distance_km ASC, fc.location_id ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_fill_locations(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT
) TO authenticated, anon, service_role;
