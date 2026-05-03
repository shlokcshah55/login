-- Explicitly set is_curated = false when a user manually creates a collection.
-- Previously the column default handled this silently; making it explicit
-- ensures the intent is clear and guards against any future default change.
CREATE OR REPLACE FUNCTION public.create_collection(
    p_name text,
    p_description text DEFAULT NULL,
    p_emoji text DEFAULT NULL,
    p_cover_color text DEFAULT NULL,
    p_is_public boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID;
    v_collection_id UUID;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    IF p_name IS NULL OR trim(p_name) = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Collection name is required');
    END IF;

    INSERT INTO collections (name, description, emoji, cover_color, created_by, is_public, is_curated)
    VALUES (trim(p_name), p_description, p_emoji, p_cover_color, v_user_id, p_is_public, false)
    RETURNING collection_id INTO v_collection_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'collection_id', v_collection_id
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$function$;
