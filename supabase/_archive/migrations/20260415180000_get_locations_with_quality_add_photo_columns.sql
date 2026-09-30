-- ============================================================================
-- Revert get_locations_with_quality to its original definition, with the 4
-- photo pipeline columns added to the RETURNS TABLE so the Dart client can
-- read image_stored / image_unavailable / photos / extra_photos_stored and
-- skip the Google Places API calls.
--
-- This is the authoritative original from 20260327163023_remote_schema.sql
-- (and commit a258a49 in git). The only change is the addition of 4 columns
-- to RETURNS TABLE. Body (`SELECT l.*`), compute_quality_score call, and
-- every declared type are untouched.
--
-- RETURNS TABLE is changing, so DROP FUNCTION is required.
-- ============================================================================

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
    -- All columns from locations table
    l.*,
    -- Calculate distance in kilometers
    ST_Distance(
      l.geog,
      ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography
    ) / 1000.0 AS distance_km,
    -- Pre-compute quality score using existing sophisticated function
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
  FROM locations l
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
