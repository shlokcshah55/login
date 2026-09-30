-- Trigram-based fuzzy search for locations.
-- Replaces the client-side `.or(name.ilike, vicinity.ilike, cuisine.ilike)`
-- pattern, which is unindexed, does full-table scans, returns no ranking,
-- and has zero typo tolerance.
--
-- This migration:
--   1. Enables pg_trgm
--   2. Adds GIN trigram indexes on locations.name / vicinity / cuisine
--   3. Adds `search_locations(p_query, p_limit, p_lat, p_lng)` RPC that
--      ranks by similarity (weighted: name > cuisine > vicinity) with a
--      small proximity tiebreaker when coordinates are supplied.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_locations_name_trgm
  ON public.locations
  USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_locations_vicinity_trgm
  ON public.locations
  USING gin (vicinity gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_locations_cuisine_trgm
  ON public.locations
  USING gin (cuisine gin_trgm_ops);

DROP FUNCTION IF EXISTS public.search_locations(text, integer, double precision, double precision);

CREATE OR REPLACE FUNCTION public.search_locations(
  p_query text,
  p_limit integer DEFAULT 10,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL
)
RETURNS TABLE("like" locations)
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
      l.location_id,
      -- Weighted similarity: name matches matter most, then cuisine, then vicinity.
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
  SELECT l.*
  FROM ranked r
  JOIN public.locations l ON l.location_id = r.location_id
  WHERE r.score > 0.15
  ORDER BY
    r.score DESC,
    -- Proximity as a gentle tiebreaker: ~1km ≈ 0.001 score.
    COALESCE(r.distance_m, 0) / 1000000.0 ASC,
    l.name ASC
  LIMIT GREATEST(p_limit, 1);
END;
$function$;
