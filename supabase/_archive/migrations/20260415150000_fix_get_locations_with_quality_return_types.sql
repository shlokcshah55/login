-- ============================================================================
-- Fix: get_locations_with_quality RETURNS TABLE vs actual locations columns
-- ============================================================================
-- The photo_pipeline_revamp migration replaced the previous `SELECT l.*`
-- body with an explicit column list AND an explicit RETURNS TABLE signature.
-- Several of the declared types didn't match the actual `public.locations`
-- column types, which Postgres doesn't validate at CREATE time — it only
-- errors at runtime with:
--   structure of query does not match function result type
--   Returned type bigint does not match expected type integer in column 1.
--
-- Column-by-column audit against database_schema.sql:
--
--   column                   | declared (old)  | actual         | action
--   -------------------------+-----------------+----------------+--------
--   location_id              | integer         | bigint         | bigint
--   rating                   | double precision| real           | real
--   user_ratings_total       | integer         | numeric        | numeric
--   price_level              | double precision| numeric        | numeric
--   saved_count              | integer         | smallint       | smallint
--   lat                      | double precision| numeric        | numeric
--   lng                      | double precision| numeric        | numeric
--   opening_hours_periods    | text            | jsonb          | jsonb
--   photo_reference_score    | integer         | text           | text
--   updated_at               | timestamp w/o tz| timestamp w/ tz| w/ tz
--
-- All other declared columns already matched. The Dart client is defensive
-- (`as num?.toDouble()`, `.toString()`, `_safeBool`, `is List`) so any of
-- these integer/double/numeric/bigint variations decode cleanly.
--
-- compute_quality_score still requires casts at the call site because its
-- 18-arg overload is (double precision, integer, integer, bool x15) and
-- numeric -> integer is not an implicit function-arg cast.
--
-- RETURNS TABLE signature is changing, so DROP FUNCTION is required before
-- CREATE.
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
  vibe_vector integer[],
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
