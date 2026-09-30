-- ─────────────────────────────────────────────────────────────
-- delete_collection RPC
--
-- Lets a user delete a collection they own. Refuses to delete the
-- two auto-generated system collections ("Been To", "Shared Finds")
-- so users can't nuke their own auto-managed buckets from the UI.
--
-- Cascading deletion of collection_locations rows is handled by the
-- existing collection_locations_collection_id_fkey FK
-- (ON DELETE CASCADE) defined in 20260327163023_remote_schema.sql.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.delete_collection(
    p_collection_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_user_id    uuid;
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

    IF v_collection.created_by <> v_user_id THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Permission denied');
    END IF;

    IF v_collection.name IN ('Been To', 'Shared Finds') THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Auto-generated collections cannot be deleted'
        );
    END IF;

    DELETE FROM collections WHERE collection_id = p_collection_id;

    RETURN jsonb_build_object('success', TRUE);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.delete_collection(uuid)
    TO anon, authenticated, service_role;
