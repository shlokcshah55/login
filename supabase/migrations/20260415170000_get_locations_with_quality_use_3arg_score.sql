-- ============================================================================
-- Perf: get_locations_with_quality → call 3-arg compute_quality_score
-- ============================================================================
-- After fixing the RETURNS TABLE type mismatches, the RPC finally runs but
-- times out:
--   canceling statement due to statement timeout (57014)
--
-- Root cause: the 18-arg compute_quality_score is plpgsql, so Postgres
-- cannot inline it. Being interpreted once per row across up to 6000 rows,
-- per every map refresh, is enough to blow the statement timeout.
--
-- The 3-arg overload
--   compute_quality_score(rating double precision, user_ratings_total
--                         numeric, saved_count smallint)
-- still exists and was the original design for bulk spatial queries. It
-- takes the column types natively (no call-site casts) and the simpler
-- body runs fast enough at 6000 rows. The 15-boolean "feature richness"
-- scoring is retained for the expanded-card / detail-view code paths that
-- call it individually.
--
-- Signature and RETURNS TABLE are unchanged from the 20260415160000
-- migration, so CREATE OR REPLACE is sufficient — no DROP needed.
-- ============================================================================

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
      l.user_ratings_total,
      l.saved_count
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
