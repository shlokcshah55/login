-- Returns the public collections created by p_user_id. Used to display
-- another user's collections on their profile page.

CREATE OR REPLACE FUNCTION public.get_user_public_collections(p_user_id uuid)
RETURNS TABLE (
    collection_id uuid,
    name         text,
    emoji        text,
    cover_color  text,
    photo        text,
    place_count  bigint
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
        COUNT(cl.id)::bigint AS place_count
    FROM collections c
    LEFT JOIN collection_locations cl ON cl.collection_id = c.collection_id
    WHERE c.created_by = p_user_id
      AND c.is_public  = TRUE
    GROUP BY c.collection_id, c.name, c.emoji, c.cover_color, c.photo
    ORDER BY c.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_public_collections(uuid)
    TO anon, authenticated, service_role;
