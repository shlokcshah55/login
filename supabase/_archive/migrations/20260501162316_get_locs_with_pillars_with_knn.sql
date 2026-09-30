-- ============================================================================
-- FIX: restore KNN get_locations_with_pillars after vibe-vector repair
-- ============================================================================
-- The previous forward fix corrected the RPC return type but restored the
-- older ST_Distance sort and variable LIMIT expression. Re-apply the v6 KNN
-- shape so cold proximal reads stay inside Supabase statement limits.
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
) LANGUAGE sql STABLE
AS $$
    WITH center AS (
        SELECT ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography AS g
    ),
    primary_set AS (
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
            (ST_Distance(lp.geog, center.g) / 1000.0)::FLOAT AS distance_km,
            COALESCE(lp.app_engagement_score, 0.0) AS app_engagement_score,
            COALESCE(
                lp.google_baseline_score,
                compute_google_baseline_score(l.rating, l.user_ratings_total)
            ) AS google_baseline_score,
            COALESCE(lp.video_insight_score, 0.0) AS video_insight_score,
            COALESCE(lp.share_count, 0) AS share_count,
            TRUE AS has_app_signal,
            COALESCE(lp.quality_score, 0.0) AS quality_bias
        FROM public.location_popularity_app lp
        INNER JOIN public.locations l ON l.location_id = lp.location_id
        CROSS JOIN center
        WHERE lp.geog IS NOT NULL
          AND ST_DWithin(lp.geog, center.g, radius_meters)
        ORDER BY lp.geog <-> center.g
        LIMIT result_limit
    ),
    primary_count AS (
        SELECT COUNT(*)::INT AS count FROM primary_set
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
            0.0::NUMERIC AS quality_bias
        FROM public.locations l
        CROSS JOIN center
        CROSS JOIN primary_count pc
        WHERE l.geog IS NOT NULL
          AND pc.count < result_limit
          AND ST_DWithin(l.geog, center.g, radius_meters)
          AND NOT EXISTS (
              SELECT 1
              FROM public.location_popularity_app lp
              WHERE lp.location_id = l.location_id
          )
        ORDER BY l.geog <-> center.g
        LIMIT result_limit
    ),
    fill_ranked AS (
        SELECT
            fc.*,
            ROW_NUMBER() OVER (ORDER BY fc.distance_km ASC, fc.location_id ASC) AS rn
        FROM fill_candidates fc
    ),
    fill_set AS (
        SELECT
            fr.location_id,
            fr.name,
            fr.vicinity,
            fr.lat,
            fr.lng,
            fr.cuisine,
            fr.cuisine_primary,
            fr.rating,
            fr.user_ratings_total,
            fr.price_level,
            fr.google_place_id,
            fr.types,
            fr.emoji,
            fr.vibe_vector,
            fr.dietary_requirement_vector,
            fr.distance_km,
            fr.app_engagement_score,
            fr.google_baseline_score,
            fr.video_insight_score,
            fr.share_count,
            fr.has_app_signal,
            fr.quality_bias
        FROM fill_ranked fr
        CROSS JOIN primary_count pc
        WHERE fr.rn <= GREATEST(result_limit - pc.count, 0)
    )
    SELECT *
    FROM (
        SELECT * FROM primary_set
        UNION ALL
        SELECT * FROM fill_set
    ) combined
    ORDER BY has_app_signal DESC, distance_km ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_locations_with_pillars(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT
) TO authenticated, anon, service_role;
