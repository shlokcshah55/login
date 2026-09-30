-- Fetch specific collections by ID array, with save state for the requesting user.
-- Used by onboarding to show a curated set of collections without a social-graph query.

CREATE OR REPLACE FUNCTION public.get_collections_by_ids(
    p_collection_ids uuid[],
    p_user_id        uuid DEFAULT NULL
)
RETURNS TABLE (
    collection_id    uuid,
    name             text,
    emoji            text,
    cover_color      text,
    photo            text,
    place_count      bigint,
    owner_name       text,
    owner_avatar_url text,
    is_public        boolean,
    can_edit         boolean,
    is_saved         boolean,
    save_count       bigint
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
    WITH save_counts AS (
        SELECT collection_id, COUNT(*)::bigint AS save_count
        FROM public.collection_saves
        GROUP BY collection_id
    )
    SELECT
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        COUNT(cl.id)::bigint AS place_count,
        u.name               AS owner_name,
        u.profile_image_url  AS owner_avatar_url,
        c.is_public,
        FALSE                AS can_edit,
        (ucs.user_id IS NOT NULL) AS is_saved,
        COALESCE(sc.save_count, 0)::bigint AS save_count
    FROM public.collections c
    LEFT JOIN public.collection_locations cl
        ON cl.collection_id = c.collection_id
    LEFT JOIN public.users u
        ON u.supabase_id = c.created_by
    LEFT JOIN public.collection_saves ucs
        ON ucs.collection_id = c.collection_id
       AND ucs.user_id = p_user_id
    LEFT JOIN save_counts sc
        ON sc.collection_id = c.collection_id
    WHERE c.collection_id = ANY(p_collection_ids)
      AND c.is_public = TRUE
    GROUP BY
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        u.name,
        u.profile_image_url,
        c.is_public,
        ucs.user_id,
        sc.save_count
    ORDER BY array_position(p_collection_ids, c.collection_id);
$$;

GRANT EXECUTE ON FUNCTION public.get_collections_by_ids(uuid[], uuid)
    TO anon, authenticated, service_role;
