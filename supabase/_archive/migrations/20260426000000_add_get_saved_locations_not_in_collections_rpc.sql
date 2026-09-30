-- Returns all locations the user has saved that are NOT already present in any
-- of the given collection UUIDs. Used by the AI auto-update pipeline to find
-- locations that haven't been categorised into an AI collection yet.

DROP FUNCTION IF EXISTS public.get_saved_locations_not_in_collections(uuid, uuid[]);

CREATE OR REPLACE FUNCTION public.get_saved_locations_not_in_collections(
    p_user_id       uuid,
    p_collection_ids uuid[]
)
RETURNS SETOF public.locations
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT l.*
    FROM public.user_location_actions ula
    JOIN public.locations l ON l.location_id = ula.location_id
    WHERE ula.user_id = p_user_id
      AND ula.action IN ('save', 'bubble_save')
      AND NOT EXISTS (
          SELECT 1
          FROM public.collection_locations cl
          WHERE cl.location_id = ula.location_id
            AND cl.collection_id = ANY(p_collection_ids)
      )
    -- one row per location even if the user has saved it multiple times
    GROUP BY l.location_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_saved_locations_not_in_collections(uuid, uuid[])
    TO anon, authenticated, service_role;
