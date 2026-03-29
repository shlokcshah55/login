CREATE OR REPLACE FUNCTION public.locations_within_radius(center_lat double precision, center_lng double precision, radius_meters double precision, max_results integer DEFAULT 10000)
 RETURNS TABLE(location_id bigint, name text, vicinity text, lat numeric, lng numeric, cuisine_primary text, rating real, user_ratings_total numeric, price_level numeric, google_place_id text, distance_km double precision)
 LANGUAGE plpgsql
 STABLE
AS $function$
  BEGIN
      RETURN QUERY
      SELECT
          l.location_id,
          l.name,
          l.vicinity,
          l.lat,
          l.lng,
          l.cuisine_primary,
          l.rating,
          l.user_ratings_total,
          l.price_level,
          l.google_place_id,
          ST_Distance(l.geog, ST_MakePoint(center_lng, center_lat)::geography) / 1000.0 AS distance_km
      FROM locations l
      WHERE ST_DWithin(
          l.geog,
          ST_MakePoint(center_lng, center_lat)::geography,
          radius_meters
      )
      ORDER BY l.geog <-> ST_MakePoint(center_lng, center_lat)::geography  -- Use index for ordering
      LIMIT max_results;
  END;
  $function$
;
