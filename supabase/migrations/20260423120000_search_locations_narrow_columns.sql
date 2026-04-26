-- Narrow the `search_locations` return type so the UI only pays for the
-- columns it actually renders. The previous version returned full `locations`
-- rows (~40 columns incl. several jsonb blobs and a 70-element real[] vibe
-- vector). For search suggestions we only need enough to render the card
-- and resolve the image. Trimming this roughly 5–10× the payload size and
-- dramatically speeds up JSON parsing on device.
--
-- Columns dropped (heavy / unused by suggestion cards):
--   reviews, review_summary, opening_hours_periods, opening_hours_text,
--   derived_attributes, cuisine_scores_json, review_language_counts_json,
--   vibe_vector, dietary_requirement_vector, recommended_dishes, menu,
--   menu_analysis_confidence, international_phone_number, website,
--   editorial_summary, generated_summary, cuisine_detected, cuisine_source,
--   cuisine_primary, plus the ~24 `good_for_*` / `serves_*` boolean flags
--   and other rarely-rendered fields.
--
-- Columns kept: identifiers, geo, display metadata, rating/price, and the
-- image-pipeline fields (photo_reference / photos / image_stored /
-- image_unavailable) so we can still avoid paying Google for a Details call
-- when the cached photos jsonb is already populated.

DROP FUNCTION IF EXISTS public.search_locations(text, integer, double precision, double precision);

CREATE OR REPLACE FUNCTION public.search_locations(
  p_query text,
  p_limit integer DEFAULT 10,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL
)
RETURNS TABLE(
  location_id bigint,
  name text,
  vicinity text,
  lat numeric,
  lng numeric,
  cuisine text,
  rating real,
  user_ratings_total numeric,
  price_level numeric,
  price_bucket text,
  photo_reference text,
  photos jsonb,
  image_stored boolean,
  image_unavailable boolean,
  saved_count smallint,
  google_place_id text,
  google_maps_uri text,
  business_status text,
  open_now boolean,
  emoji text,
  types text
)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  q text := lower(btrim(coalesce(p_query, '')));
  user_geog geography := CASE
    WHEN p_lat IS NULL OR p_lng IS NULL THEN NULL
    ELSE ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  END;
BEGIN
  IF q = '' THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH ranked AS (
    SELECT
      l.location_id AS lid,
      GREATEST(
        similarity(lower(coalesce(l.name,     '')), q) * 1.0,
        similarity(lower(coalesce(l.cuisine,  '')), q) * 0.7,
        similarity(lower(coalesce(l.vicinity, '')), q) * 0.5
      ) AS score,
      CASE
        WHEN user_geog IS NULL OR l.geog IS NULL THEN NULL
        ELSE ST_Distance(l.geog, user_geog)
      END AS distance_m
    FROM public.locations l
    WHERE
      l.name     % q
      OR l.cuisine  % q
      OR l.vicinity % q
  )
  SELECT
    l.location_id,
    l.name,
    l.vicinity,
    l.lat,
    l.lng,
    l.cuisine,
    l.rating,
    l.user_ratings_total,
    l.price_level,
    l.price_bucket,
    l.photo_reference,
    l.photos,
    l.image_stored,
    l.image_unavailable,
    l.saved_count,
    l.google_place_id,
    l.google_maps_uri,
    l.business_status,
    l.open_now,
    l.emoji,
    l.types
  FROM ranked r
  JOIN public.locations l ON l.location_id = r.lid
  WHERE r.score > 0.15
  ORDER BY
    r.score DESC,
    COALESCE(r.distance_m, 0) / 1000000.0 ASC,
    l.name ASC
  LIMIT GREATEST(p_limit, 1);
END;
$function$;
