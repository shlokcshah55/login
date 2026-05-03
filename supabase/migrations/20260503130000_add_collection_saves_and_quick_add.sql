-- Saved/quick-added collections (user ↔ collection)
-- Enables users to add other users' public collections into their library (read-only),
-- and exposes save state + save counts for explore UI.

CREATE TABLE IF NOT EXISTS public.collection_saves (
    user_id uuid NOT NULL REFERENCES public.users(supabase_id) ON DELETE CASCADE,
    collection_id uuid NOT NULL REFERENCES public.collections(collection_id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT collection_saves_pkey PRIMARY KEY (user_id, collection_id)
);

CREATE INDEX IF NOT EXISTS collection_saves_collection_id_idx
    ON public.collection_saves(collection_id);

ALTER TABLE public.collection_saves ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own saved collections" ON public.collection_saves;
CREATE POLICY "Users can view own saved collections"
    ON public.collection_saves
    FOR SELECT
    TO authenticated
    USING (auth.uid() IS NOT NULL AND auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can save collections" ON public.collection_saves;
CREATE POLICY "Users can save collections"
    ON public.collection_saves
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unsave collections" ON public.collection_saves;
CREATE POLICY "Users can unsave collections"
    ON public.collection_saves
    FOR DELETE
    TO authenticated
    USING (auth.uid() IS NOT NULL AND auth.uid() = user_id);

-- Save / unsave RPCs (used by the explore grid + button)
CREATE OR REPLACE FUNCTION public.save_collection(p_collection_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid;
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

    IF v_collection.created_by = v_user_id THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Cannot save your own collection');
    END IF;

    IF v_collection.is_public IS NOT TRUE THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Collection is private');
    END IF;

    INSERT INTO public.collection_saves (user_id, collection_id)
    VALUES (v_user_id, p_collection_id);

    RETURN jsonb_build_object('success', TRUE);
EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object('success', TRUE, 'message', 'Already saved');
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid collection reference');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.save_collection(uuid)
    TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.unsave_collection(p_collection_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    DELETE FROM public.collection_saves
    WHERE user_id = v_user_id
      AND collection_id = p_collection_id;

    RETURN jsonb_build_object('success', TRUE);
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.unsave_collection(uuid)
    TO anon, authenticated, service_role;

-- Collections library RPC (owned + saved), used by the profile collections grid.
DROP FUNCTION IF EXISTS public.get_user_collection_library(uuid);

CREATE OR REPLACE FUNCTION public.get_user_collection_library(p_user_id uuid)
RETURNS TABLE (
    collection_id    uuid,
    name             text,
    emoji            text,
    cover_color      text,
    photo            text,
    place_count      bigint,
    is_public        boolean,
    owner_name       text,
    owner_avatar_url text,
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
        c.is_public,
        NULL::text AS owner_name,
        NULL::text AS owner_avatar_url,
        TRUE AS can_edit,
        FALSE AS is_saved,
        COALESCE(sc.save_count, 0)::bigint AS save_count
    FROM public.collections c
    LEFT JOIN public.collection_locations cl ON cl.collection_id = c.collection_id
    LEFT JOIN save_counts sc ON sc.collection_id = c.collection_id
    WHERE c.created_by = p_user_id
    GROUP BY c.collection_id, c.name, c.emoji, c.cover_color, c.photo, c.is_public, sc.save_count

    UNION ALL

    SELECT
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        COUNT(cl.id)::bigint AS place_count,
        c.is_public,
        u.name AS owner_name,
        u.profile_image_url AS owner_avatar_url,
        FALSE AS can_edit,
        TRUE AS is_saved,
        COALESCE(sc.save_count, 0)::bigint AS save_count
    FROM public.collection_saves cs
    JOIN public.collections c
        ON c.collection_id = cs.collection_id
       AND c.is_public = TRUE
    LEFT JOIN public.collection_locations cl ON cl.collection_id = c.collection_id
    JOIN public.users u ON u.supabase_id = c.created_by
    LEFT JOIN save_counts sc ON sc.collection_id = c.collection_id
    WHERE cs.user_id = p_user_id
      AND c.created_by IS DISTINCT FROM p_user_id
    GROUP BY c.collection_id, c.name, c.emoji, c.cover_color, c.photo, c.is_public, u.name, u.profile_image_url, sc.save_count;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_collection_library(uuid)
    TO anon, authenticated, service_role;

-- Update friend explore RPC to include save count + save state for p_user_id.
DROP FUNCTION IF EXISTS public.get_other_collections(uuid);

CREATE OR REPLACE FUNCTION public.get_other_collections(p_user_id uuid)
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
    WITH friends AS (
        -- p_user_id is the follower, friend is the followee
        SELECT followee_id AS friend_id
        FROM public.user_friends
        WHERE follower_id = p_user_id
          AND status      = 'accepted'

        UNION

        -- p_user_id is the followee, friend is the follower
        SELECT follower_id AS friend_id
        FROM public.user_friends
        WHERE followee_id = p_user_id
          AND status      = 'accepted'
    ),
    save_counts AS (
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
        u.name AS owner_name,
        u.profile_image_url AS owner_avatar_url,
        c.is_public,
        FALSE AS can_edit,
        (ucs.user_id IS NOT NULL) AS is_saved,
        COALESCE(sc.save_count, 0)::bigint AS save_count
    FROM friends f
    JOIN public.collections c
        ON c.created_by = f.friend_id
       AND c.is_public = TRUE
    LEFT JOIN public.collection_locations cl
        ON cl.collection_id = c.collection_id
    JOIN public.users u
        ON u.supabase_id = f.friend_id
    LEFT JOIN public.collection_saves ucs
        ON ucs.collection_id = c.collection_id
       AND ucs.user_id = p_user_id
    LEFT JOIN save_counts sc
        ON sc.collection_id = c.collection_id
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
    ORDER BY c.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_other_collections(uuid)
    TO anon, authenticated, service_role;

