-- Returns public collections created by friends of p_user_id (accepted status),
-- where p_user_id can appear as either the follower or the followee.

CREATE OR REPLACE FUNCTION public.get_other_collections(p_user_id uuid)
RETURNS TABLE (
    collection_id    uuid,
    name             text,
    emoji            text,
    cover_color      text,
    photo            text,
    place_count      bigint,
    owner_name       text,
    owner_avatar_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        COUNT(cl.id)::bigint AS place_count,
        u.name               AS owner_name,
        u.profile_image_url  AS owner_avatar_url
    FROM (
        -- p_user_id is the follower, friend is the followee
        SELECT followee_id AS friend_id
        FROM user_friends
        WHERE follower_id = p_user_id
          AND status      = 'accepted'

        UNION

        -- p_user_id is the followee, friend is the follower
        SELECT follower_id AS friend_id
        FROM user_friends
        WHERE followee_id = p_user_id
          AND status      = 'accepted'
    ) friends
    JOIN collections c
        ON c.created_by = friends.friend_id
        AND c.is_public  = TRUE
    LEFT JOIN collection_locations cl
        ON cl.collection_id = c.collection_id
    JOIN users u
        ON u.supabase_id = friends.friend_id
    GROUP BY
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        u.name,
        u.profile_image_url
    ORDER BY c.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_other_collections(uuid)
    TO anon, authenticated, service_role;
