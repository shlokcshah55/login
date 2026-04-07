-- Replace get_locations_in_collection to return full location rows instead of
-- just location_id/note/added_at, so callers don't need a second query.
DROP FUNCTION IF EXISTS public.get_locations_in_collection(uuid);

CREATE OR REPLACE FUNCTION public.get_locations_in_collection(p_collection_id uuid)
RETURNS SETOF public.locations
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT l.*
    FROM collection_locations cl
    JOIN locations l ON l.location_id = cl.location_id
    WHERE cl.collection_id = p_collection_id
    ORDER BY cl.added_at ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_locations_in_collection(uuid)
    TO anon, authenticated, service_role;
