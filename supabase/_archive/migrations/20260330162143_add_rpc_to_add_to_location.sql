CREATE OR REPLACE FUNCTION public.add_location_to_collection(
    p_collection_id uuid,
    p_location_id   bigint,
    p_note          text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id   uuid;
    v_collection collections%ROWTYPE;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_collection
    FROM collections
    WHERE collection_id = p_collection_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Collection not found');
    END IF;

    IF NOT v_collection.is_public AND v_collection.created_by != v_user_id THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Permission denied: collection is private');
    END IF;

    INSERT INTO collection_locations (collection_id, location_id, added_by, note)
    VALUES (p_collection_id, p_location_id, v_user_id, p_note);

    RETURN jsonb_build_object('success', TRUE);

EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object('success', TRUE, 'message', 'Location already in collection');
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid collection or location reference');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

GRANT ALL ON FUNCTION public.add_location_to_collection(uuid, bigint, text) TO anon;
GRANT ALL ON FUNCTION public.add_location_to_collection(uuid, bigint, text) TO authenticated;
GRANT ALL ON FUNCTION public.add_location_to_collection(uuid, bigint, text) TO service_role;
