CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth, storage
AS $function$
DECLARE
    v_user_id uuid;
    v_deleted_profile_count integer := 0;
    v_deleted_auth_count integer := 0;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    DELETE FROM public.notifications n
    WHERE EXISTS (
        SELECT 1
        FROM public.bubbles b
        WHERE b.created_by = v_user_id
          AND (n.metadata ->> 'bubbleId') = b.bubble_id::text
    );

    DELETE FROM public.notifications
    WHERE (metadata ->> 'userId') = v_user_id::text
       OR (metadata ->> 'inviterId') = v_user_id::text
       OR (metadata ->> 'senderId') = v_user_id::text;

    -- TODO: Delete collection cover and profile photo assets through the
    -- Storage API before removing the user record. Direct deletion from
    -- storage.objects is not allowed in this RPC.

    DELETE FROM public.collections
    WHERE created_by = v_user_id;

    DELETE FROM public.bubbles
    WHERE created_by = v_user_id;

    UPDATE public.messages
    SET replied_to_message_id = NULL
    WHERE replied_to_message_id IN (
        SELECT id
        FROM public.messages
        WHERE sender_id = v_user_id
    );

    DELETE FROM public.messages
    WHERE sender_id = v_user_id;

    DELETE FROM public.bubble_locations
    WHERE added_by = v_user_id;

    DELETE FROM public.collection_locations
    WHERE added_by = v_user_id;

    DELETE FROM public.bubble_members
    WHERE user_id = v_user_id;

    DELETE FROM public.location_reviews
    WHERE user_id = v_user_id;

    DELETE FROM public.user_location_actions
    WHERE user_id = v_user_id;

    DELETE FROM public.user_friends
    WHERE follower_id = v_user_id
       OR followee_id = v_user_id;

    IF to_regclass('public.user_tag_affinities') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.user_tag_affinities WHERE user_id = $1'
        USING v_user_id;
    END IF;

    DELETE FROM public.users
    WHERE supabase_id = v_user_id;
    GET DIAGNOSTICS v_deleted_profile_count = ROW_COUNT;

    DELETE FROM auth.users
    WHERE id = v_user_id;
    GET DIAGNOSTICS v_deleted_auth_count = ROW_COUNT;

    IF v_deleted_auth_count = 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Authenticated user not found in auth.users'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'profile_deleted', v_deleted_profile_count > 0,
        'auth_deleted', TRUE
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.delete_my_account()
    TO authenticated, service_role;
