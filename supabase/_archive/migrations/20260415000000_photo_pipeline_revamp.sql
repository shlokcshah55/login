-- ============================================================================
-- Photo pipeline revamp
-- ============================================================================
-- Goals:
--   1. Eliminate the Google Places API call storm caused by list-view queries
--      dropping image_stored/image_unavailable/photos from their RETURNS TABLE.
--   2. Support lazy-loading of multiple photos per location for the expanded
--      card, with each photo paid for exactly once then served from Supabase
--      Storage forever.
--
-- Storage convention:
--   {location_id}.jpg        -> primary photo (gated by image_stored)
--   {location_id}_1.jpg ..   -> extra photos  (gated by extra_photos_stored)
--
-- extra_photos_stored is the count of suffix-indexed extras currently in
-- storage. 0 means only the primary exists (or nothing, if image_stored is
-- false as well).
-- ============================================================================

ALTER TABLE public.locations
  ADD COLUMN IF NOT EXISTS extra_photos_stored smallint NOT NULL DEFAULT 0;


-- ---------------------------------------------------------------------------
-- Consolidated write RPC used after a successful primary-photo upload.
-- Replaces the old three-call sequence
-- (update_location_photo_reference + update_location_photos + update_location_image_url).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_location_image_uploaded(
  p_location_id bigint,
  p_photos jsonb,
  p_photo_reference text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.locations
  SET
    image_stored       = true,
    image_unavailable  = false,
    photos             = COALESCE(p_photos, photos),
    photo_reference    = COALESCE(p_photo_reference, photo_reference)
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_location_image_uploaded(bigint, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_location_image_uploaded(bigint, jsonb, text) TO service_role;


-- ---------------------------------------------------------------------------
-- Called after successfully uploading N extra photos for the expanded card.
-- Monotonic: never decreases the stored count.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_location_extra_photos_stored(
  p_location_id bigint,
  p_count smallint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.locations
  SET extra_photos_stored = GREATEST(extra_photos_stored, p_count)
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_location_extra_photos_stored(bigint, smallint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_location_extra_photos_stored(bigint, smallint) TO service_role;


-- ---------------------------------------------------------------------------
-- ROOT CAUSE FIX: get_locations_with_quality previously declared an explicit
-- RETURNS TABLE(...) signature that omitted image_stored, image_unavailable,
-- photos, and extra_photos_stored. Even though the body did SELECT l.*, those
-- columns were silently filtered out, so the Dart client always saw
-- imageStored == null and re-triggered a background Google Places API fetch
-- on every map refresh (~$1.44 / 60 locations, every session).
--
-- This redefinition adds the missing columns to the output so the cache-hit
-- short-circuit in _getLocationImageUrl actually fires.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_locations_with_quality(double precision, double precision, double precision, integer);

CREATE OR REPLACE FUNCTION public.get_locations_with_quality(
  center_lat double precision,
  center_lng double precision,
  radius_meters double precision,
  result_limit integer DEFAULT 6000
)
 RETURNS TABLE(
  location_id integer,
  google_place_id text,
  name text,
  vicinity text,
  cuisine_primary text,
  rating double precision,
  user_ratings_total integer,
  price_level double precision,
  business_status text,
  editorial_summary text,
  website text,
  international_phone_number text,
  types text,
  opening_hours_text text[],
  opening_hours_periods text,
  open_now boolean,
  lat double precision,
  lng double precision,
  geog geography,
  vibe_vector integer[],
  dietary_requirement_vector integer[],
  saved_count integer,
  outdoor_seating boolean,
  live_music boolean,
  serves_cocktails boolean,
  serves_brunch boolean,
  serves_wine boolean,
  serves_beer boolean,
  good_for_groups boolean,
  good_for_children boolean,
  serves_vegetarian_food boolean,
  serves_breakfast boolean,
  serves_lunch boolean,
  serves_dinner boolean,
  serves_coffee boolean,
  serves_dessert boolean,
  good_for_watching_sports boolean,
  emoji text,
  photo_reference text,
  photo_reference_score integer,
  image_stored boolean,
  image_unavailable boolean,
  photos jsonb,
  extra_photos_stored smallint,
  created_at timestamp without time zone,
  updated_at timestamp without time zone,
  distance_km double precision,
  quality_score double precision
)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    l.location_id,
    l.google_place_id,
    l.name,
    l.vicinity,
    l.cuisine_primary,
    l.rating::double precision,
    l.user_ratings_total::integer,
    l.price_level::double precision,
    l.business_status,
    l.editorial_summary,
    l.website,
    l.international_phone_number,
    l.types,
    l.opening_hours_text,
    l.opening_hours_periods::text,
    l.open_now,
    l.lat::double precision,
    l.lng::double precision,
    l.geog,
    l.vibe_vector,
    l.dietary_requirement_vector,
    l.saved_count::integer,
    l.outdoor_seating,
    l.live_music,
    l.serves_cocktails,
    l.serves_brunch,
    l.serves_wine,
    l.serves_beer,
    l.good_for_groups,
    l.good_for_children,
    l.serves_vegetarian_food,
    l.serves_breakfast,
    l.serves_lunch,
    l.serves_dinner,
    l.serves_coffee,
    l.serves_dessert,
    l.good_for_watching_sports,
    l.emoji,
    l.photo_reference,
    l.photo_reference_score::integer,
    l.image_stored,
    l.image_unavailable,
    l.photos,
    l.extra_photos_stored,
    l.created_at,
    l.updated_at::timestamp without time zone,
    ST_Distance(
      l.geog,
      ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography
    ) / 1000.0 AS distance_km,
    compute_quality_score(
      l.rating,
      l.user_ratings_total,
      l.saved_count,
      l.outdoor_seating,
      l.live_music,
      l.serves_cocktails,
      l.serves_brunch,
      l.serves_wine,
      l.serves_beer,
      l.good_for_groups,
      l.good_for_children,
      l.serves_vegetarian_food,
      l.serves_breakfast,
      l.serves_lunch,
      l.serves_dinner,
      l.serves_coffee,
      l.serves_dessert,
      l.good_for_watching_sports
    ) AS quality_score
  FROM public.locations l
  WHERE ST_DWithin(
    l.geog,
    ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography,
    radius_meters
  )
  ORDER BY distance_km ASC
  LIMIT result_limit;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_locations_with_quality(double precision, double precision, double precision, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_locations_with_quality(double precision, double precision, double precision, integer) TO service_role;
-- ---------------------------------------------------------------------------
-- Same root-cause fix applied to get_ranked_proximal_recommendations (both
-- overloads). Drops required because RETURNS TABLE column list is changing.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_ranked_proximal_recommendations(text, double precision, double precision, double precision, double precision, double precision, double precision, integer);
DROP FUNCTION IF EXISTS public.get_ranked_proximal_recommendations(uuid, double precision, double precision, double precision, double precision, double precision, double precision, integer);

CREATE OR REPLACE FUNCTION public.get_ranked_proximal_recommendations(p_user_id text, center_lat double precision, center_lng double precision, radius_meters double precision, quality_weight double precision DEFAULT 0.33, vibe_weight double precision DEFAULT 0.34, dietary_weight double precision DEFAULT 0.33, result_limit integer DEFAULT 1000)
 RETURNS TABLE(location_id bigint, name text, vicinity text, lat numeric, lng numeric, created_at timestamp without time zone, cuisine text, rating real, user_ratings_total numeric, price_level numeric, photo_reference text, saved_count smallint, google_place_id text, business_status text, editorial_summary text, website text, international_phone_number text, types text, opening_hours_text text[], opening_hours_periods jsonb, open_now boolean, cuisine_detected text, cuisine_source text, cuisine_primary text, top_review_language text, top_language_share numeric, review_language_counts_json jsonb, is_open_late boolean, is_open_early boolean, is_sunday_open boolean, price_bucket text, log_reviews numeric, derived_attributes jsonb, data_version text, ingested_at timestamp without time zone, emoji text, image_stored boolean, image_unavailable boolean, photos jsonb, extra_photos_stored smallint, vibe_vector integer[], dietary_requirement_vector integer[], distance_km double precision, vibe_score double precision, dietary_score double precision, quality_score double precision, final_score double precision, rank integer)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
  WITH user_data AS (
    -- Get user's vector affinities
    SELECT
      vibe_affinity_vector,
      dietary_requirement_affinity_vector
    FROM users
    WHERE user_id = p_user_id
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
    -- Compute all component scores
    SELECT
      nl.*,
      -- Vibe score using centered cosine similarity
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
    fr.top_review_language,
    fr.top_language_share,
    fr.review_language_counts_json,
    fr.is_open_late,
    fr.is_open_early,
    fr.is_sunday_open,
    fr.price_bucket,
    fr.log_reviews,
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
    ROW_NUMBER() OVER (ORDER BY fr.final_score DESC, fr.distance_km ASC)::INT AS rank
  FROM final_ranked fr;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_ranked_proximal_recommendations(p_supabase_id uuid, center_lat double precision, center_lng double precision, radius_meters double precision, quality_weight double precision DEFAULT 0.33, vibe_weight double precision DEFAULT 0.34, dietary_weight double precision DEFAULT 0.33, result_limit integer DEFAULT 1000)
 RETURNS TABLE(location_id bigint, name text, vicinity text, lat numeric, lng numeric, created_at timestamp without time zone, cuisine text, rating real, user_ratings_total numeric, price_level numeric, photo_reference text, saved_count smallint, google_place_id text, business_status text, editorial_summary text, website text, international_phone_number text, types text, opening_hours_text text[], opening_hours_periods jsonb, open_now boolean, cuisine_detected text, cuisine_source text, cuisine_primary text, review_language_counts_json jsonb, is_open_late boolean, is_open_early boolean, is_sunday_open boolean, price_bucket text, derived_attributes jsonb, data_version text, ingested_at timestamp without time zone, emoji text, image_stored boolean, image_unavailable boolean, photos jsonb, extra_photos_stored smallint, vibe_vector integer[], dietary_requirement_vector integer[], distance_km double precision, vibe_score double precision, dietary_score double precision, quality_score double precision, final_score double precision, rank integer)
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
    -- Compute all component scores
    SELECT
      nl.*,
      -- Vibe score using centered cosine similarity
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
    ROW_NUMBER() OVER (ORDER BY fr.final_score DESC, fr.distance_km ASC)::INT AS rank
  FROM final_ranked fr;
END;
$function$
;
