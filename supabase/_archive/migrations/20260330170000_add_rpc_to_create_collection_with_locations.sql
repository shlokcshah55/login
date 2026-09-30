CREATE OR REPLACE FUNCTION public.create_collection_with_locations(
    p_user_id      uuid,
    p_name         text,
    p_location_ids bigint[],
    p_description  text    DEFAULT NULL,
    p_emoji        text    DEFAULT NULL,
    p_cover_color  text    DEFAULT NULL,
    p_is_public    boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_collection_id uuid;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'p_user_id is required');
    END IF;

    IF p_name IS NULL OR trim(p_name) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Collection name is required');
    END IF;

    IF p_location_ids IS NULL OR array_length(p_location_ids, 1) IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'At least one location is required');
    END IF;

    INSERT INTO collections (name, description, emoji, cover_color, created_by, is_public)
    VALUES (trim(p_name), p_description, p_emoji, p_cover_color, p_user_id, p_is_public)
    RETURNING collection_id INTO v_collection_id;

    -- Bulk insert all locations in same transaction via unnest
    INSERT INTO collection_locations (collection_id, location_id, added_by)
    SELECT v_collection_id, unnest(p_location_ids), p_user_id
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object(
        'success',        true,
        'collection_id',  v_collection_id,
        'location_count', array_length(p_location_ids, 1)
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object('success', false, 'error', 'One or more location IDs are invalid');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_collection_with_locations(uuid, text, bigint[], text, text, text, boolean)
    TO anon, authenticated, service_role;
