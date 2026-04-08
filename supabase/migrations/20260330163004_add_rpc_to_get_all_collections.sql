CREATE OR REPLACE FUNCTION public.get_user_collections(p_user_id uuid)
RETURNS TABLE (
    collection_id uuid,
    name         text,
    emoji        text,
    cover_color  text,
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
        COUNT(cl.id)::bigint AS place_count
    FROM collections c
    LEFT JOIN collection_locations cl ON cl.collection_id = c.collection_id
    WHERE c.created_by = p_user_id
    GROUP BY c.collection_id, c.name, c.emoji, c.cover_color
    ORDER BY c.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_collections(uuid)
    TO anon, authenticated, service_role;
