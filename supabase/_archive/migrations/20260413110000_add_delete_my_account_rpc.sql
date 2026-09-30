-- ─────────────────────────────────────────────────────────────
-- delete_my_account RPC
--
-- Permanently deletes the authenticated user's account and the
-- user-owned / user-authored records that block a true cascade.
--
-- Why this exists:
-- - several tables reference public.users without ON DELETE CASCADE
-- - messages has a self-referential replied_to_message_id FK
-- - storage objects are not removed automatically
-- - location_popularity_app is denormalized and must be corrected
--   before the user's actions disappear
-- ─────────────────────────────────────────────────────────────
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

    -- Remove notifications tied to bubbles that will disappear with the user.
    DELETE FROM public.notifications n
    WHERE EXISTS (
        SELECT 1
        FROM public.bubbles b
        WHERE b.created_by = v_user_id
          AND (n.metadata ->> 'bubbleId') = b.bubble_id::text
    );

    -- Remove notifications that reference this user as the actor.
    DELETE FROM public.notifications
    WHERE (metadata ->> 'userId') = v_user_id::text
       OR (metadata ->> 'inviterId') = v_user_id::text
       OR (metadata ->> 'senderId') = v_user_id::text;

    -- Remove owned collection cover assets before the rows disappear.
    DELETE FROM storage.objects AS so
    WHERE so.bucket_id = 'collection_covers'
      AND EXISTS (
          SELECT 1
          FROM public.collections c
          WHERE c.created_by = v_user_id
            AND split_part(so.name, '/', 1) = c.collection_id::text
      );

    -- Remove profile photo assets regardless of extension.
    DELETE FROM storage.objects AS so
    WHERE so.bucket_id = 'profile_photos'
      AND (
          so.name = v_user_id::text
          OR so.name LIKE v_user_id::text || '.%'
          OR split_part(so.name, '/', 1) = v_user_id::text
      );

    -- Keep denormalized popularity counters consistent before actions vanish.
    UPDATE public.location_popularity_app lpa
    SET saves_count = GREATEST(lpa.saves_count - agg.save_count, 0),
        dislikes_count = GREATEST(lpa.dislikes_count - agg.dislike_count, 0),
        updated_at = NOW()
    FROM (
        SELECT
            ula.location_id,
            COUNT(*) FILTER (WHERE ula.action = 'save')::integer AS save_count,
            COUNT(*) FILTER (WHERE ula.action = 'dislike')::integer AS dislike_count
        FROM public.user_location_actions ula
        WHERE ula.user_id = v_user_id
        GROUP BY ula.location_id
    ) agg
    WHERE lpa.location_id = agg.location_id;

    -- Delete owned top-level resources first so their dependent rows cascade.
    DELETE FROM public.collections
    WHERE created_by = v_user_id;

    DELETE FROM public.bubbles
    WHERE created_by = v_user_id;

    -- Other users may have replied to this user's messages in surviving bubbles.
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

    DELETE FROM public.location_reviews
    WHERE user_id = v_user_id;

    DELETE FROM public.recommendation_runs
    WHERE user_id = v_user_id;

    DELETE FROM public.user_recommendations
    WHERE user_id = v_user_id;

    DELETE FROM public.user_friends
    WHERE follower_id = v_user_id
       OR followee_id = v_user_id;

    -- user_tag_affinities exists in the app schema, but guard it so the
    -- function can still be created against environments where that table
    -- has not been migrated yet.
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
