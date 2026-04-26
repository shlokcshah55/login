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
