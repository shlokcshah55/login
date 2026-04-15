-- ============================================================================
-- Fix: get_locations_with_quality vibe_vector element type
-- ============================================================================
-- Previous fix migration declared vibe_vector as integer[] in the RETURNS
-- TABLE signature, but the actual column is real[] (confirmed in
-- 20260327163023_remote_schema.sql line 1011 and in the Dart model
-- locations.dart:72 which has `List<double>? vibeVector` + docstring
-- "vibe_vector real[]"). Runtime error:
--   Returned type real[] does not match expected type integer[] in column 20.
--
-- dietary_requirement_vector really is integer[] in the dump, so no change.
--
-- RETURNS TABLE signature is changing, so DROP FUNCTION is required.
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_locations_with_quality(double precision, double precision, double precision, integer);

CREATE OR REPLACE FUNCTION public.get_locations_with_quality(
  center_lat double precision,
  center_lng double precision,
  radius_meters double precision,
  result_limit integer DEFAULT 6000
)
 RETURNS TABLE(
  location_id bigint,
  google_place_id text,
  name text,
  vicinity text,
  cuisine_primary text,
  rating real,
  user_ratings_total numeric,
  price_level numeric,
  business_status text,
  editorial_summary text,
  website text,
  international_phone_number text,
  types text,
  opening_hours_text text[],
  opening_hours_periods jsonb,
  open_now boolean,
  lat numeric,
  lng numeric,
  geog geography,
  vibe_vector real[],
  dietary_requirement_vector integer[],
  saved_count smallint,
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
  photo_reference_score text,
  image_stored boolean,
  image_unavailable boolean,
  photos jsonb,
  extra_photos_stored smallint,
  created_at timestamp without time zone,
  updated_at timestamp with time zone,
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
    l.rating,
    l.user_ratings_total,
    l.price_level,
    l.business_status,
    l.editorial_summary,
    l.website,
    l.international_phone_number,
    l.types,
    l.opening_hours_text,
    l.opening_hours_periods,
    l.open_now,
    l.lat,
    l.lng,
    l.geog,
    l.vibe_vector,
    l.dietary_requirement_vector,
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
    l.good_for_watching_sports,
    l.emoji,
    l.photo_reference,
    l.photo_reference_score,
    l.image_stored,
    l.image_unavailable,
    l.photos,
    l.extra_photos_stored,
    l.created_at,
    l.updated_at,
    ST_Distance(
      l.geog,
      ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography
    ) / 1000.0 AS distance_km,
    compute_quality_score(
      l.rating::double precision,
      l.user_ratings_total::integer,
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
