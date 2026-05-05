CREATE OR REPLACE FUNCTION public.get_ranked_proximal_recommendations(p_supabase_id uuid, center_lat double precision, center_lng double precision, radius_meters double precision, quality_weight double precision DEFAULT 0.33, vibe_weight double precision DEFAULT 0.34, dietary_weight double precision DEFAULT 0.33, result_limit integer DEFAULT 1000, p_social_blend_prior double precision DEFAULT 3.0, p_social_blend_cap double precision DEFAULT 0.5)
 RETURNS TABLE(location_id bigint, name text, vicinity text, lat numeric, lng numeric, created_at timestamp without time zone, cuisine text, rating real, user_ratings_total numeric, price_level numeric, photo_reference text, saved_count smallint, google_place_id text, business_status text, editorial_summary text, website text, international_phone_number text, types text, opening_hours_text text[], opening_hours_periods jsonb, open_now boolean, cuisine_detected text, cuisine_source text, cuisine_primary text, review_language_counts_json jsonb, is_open_late boolean, is_open_early boolean, is_sunday_open boolean, price_bucket text, derived_attributes jsonb, data_version text, ingested_at timestamp without time zone, emoji text, image_stored boolean, image_unavailable boolean, photos jsonb, extra_photos_stored smallint, vibe_vector integer[], dietary_requirement_vector integer[], distance_km double precision, vibe_score double precision, dietary_score double precision, quality_score double precision, final_score double precision, rank integer, social_count integer, social_place_story text, social_top_dishes jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
  WITH user_data AS (
    -- Get user's vector affinities
    SELECT
      vibe_tag_affinity AS vibe_affinity_vector,
      dietary_requirement_tag_affinity AS dietary_requirement_affinity_vector
    FROM users
    WHERE supabase_id = p_supabase_id
  ),
  nearby_locations AS (
    -- Get ALL location columns within radius with distance
    SELECT
      l.*,  -- Select all location columns
      -- Calculate distance in kilometers
      ST_Distance(
        l.geog,
        ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography
      ) / 1000.0 AS distance_km
    FROM locations l
    WHERE ST_DWithin(
      l.geog,
      ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography,
      radius_meters
    )
  ),
  scored_locations AS (
    SELECT
      nl.*,
      0::int AS social_count,
      NULL::text AS social_place_story,
      NULL::jsonb AS social_top_dishes,
      COALESCE(
        centered_cosine_similarity(
          u.vibe_affinity_vector,
          nl.vibe_vector
        ),
        0.0
      ) AS vibe_score,
      -- Dietary score using normalized dot product
      COALESCE(
        normalized_dot_product(
          u.dietary_requirement_affinity_vector,
          nl.dietary_requirement_vector
        ),
        0.0
      ) AS dietary_score,
      -- Quality score based on ratings and social proof
      compute_quality_score(
        nl.rating,
        nl.user_ratings_total,
        nl.saved_count
      ) AS quality_score
    FROM nearby_locations nl
    CROSS JOIN user_data u
  ),
  final_ranked AS (
    -- Calculate final weighted score and rank
    SELECT
      sl.*,
      (
        quality_weight * sl.quality_score +
        vibe_weight * sl.vibe_score +
        dietary_weight * sl.dietary_score
      ) AS final_score
    FROM scored_locations sl
    ORDER BY
      (
        quality_weight * sl.quality_score +
        vibe_weight * sl.vibe_score +
        dietary_weight * sl.dietary_score
      ) DESC,
      sl.distance_km ASC
    LIMIT result_limit
  )
  SELECT
    fr.location_id,
    fr.name,
    fr.vicinity,
    fr.lat,
    fr.lng,
    fr.created_at,
    fr.cuisine,
    fr.rating,
    fr.user_ratings_total,
    fr.price_level,
    fr.photo_reference,
    fr.saved_count,
    fr.google_place_id,
    fr.business_status,
    fr.editorial_summary,
    fr.website,
    fr.international_phone_number,
    fr.types,
    fr.opening_hours_text,
    fr.opening_hours_periods,
    fr.open_now,
    fr.cuisine_detected,
    fr.cuisine_source,
    fr.cuisine_primary,
    fr.review_language_counts_json,
    fr.is_open_late,
    fr.is_open_early,
    fr.is_sunday_open,
    fr.price_bucket,
    fr.derived_attributes,
    fr.data_version,
    fr.ingested_at,
    fr.emoji,
    fr.image_stored,
    fr.image_unavailable,
    fr.photos,
    fr.extra_photos_stored,
    fr.vibe_vector,
    fr.dietary_requirement_vector,
    fr.distance_km,
    fr.vibe_score,
    fr.dietary_score,
    fr.quality_score,
    fr.final_score,
    ROW_NUMBER() OVER (ORDER BY fr.final_score DESC, fr.distance_km ASC)::INT AS rank,
    fr.social_count AS social_count,
    fr.social_place_story,
    fr.social_top_dishes
  FROM final_ranked fr;
END;
$function$
;
