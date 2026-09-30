-- Remove a single location from a collection (owner-only).

DROP FUNCTION IF EXISTS public.remove_location_from_collection(uuid, bigint);

CREATE OR REPLACE FUNCTION public.remove_location_from_collection(
    p_collection_id uuid,
    p_location_id   bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id    uuid;
    v_collection public.collections%ROWTYPE;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_collection
    FROM public.collections
    WHERE collection_id = p_collection_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Collection not found');
    END IF;

    IF v_collection.created_by IS DISTINCT FROM v_user_id THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Permission denied');
    END IF;

    DELETE FROM public.collection_locations
    WHERE collection_id = p_collection_id
      AND location_id   = p_location_id;

    RETURN jsonb_build_object('success', TRUE);
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.remove_location_from_collection(uuid, bigint)
    TO anon, authenticated, service_role;

