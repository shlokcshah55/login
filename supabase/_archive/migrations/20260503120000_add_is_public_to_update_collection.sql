-- Update get_user_collections to return is_public
DROP FUNCTION IF EXISTS public.get_user_collections(uuid);

CREATE OR REPLACE FUNCTION public.get_user_collections(p_user_id uuid)
RETURNS TABLE (
    collection_id uuid,
    name         text,
    emoji        text,
    cover_color  text,
    photo        text,
    place_count  bigint,
    is_public    boolean
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
        c.is_public
    FROM collections c
    LEFT JOIN collection_locations cl ON cl.collection_id = c.collection_id
    WHERE c.created_by = p_user_id
    GROUP BY c.collection_id, c.name, c.emoji, c.cover_color, c.photo, c.is_public
    ORDER BY c.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_collections(uuid)
    TO anon, authenticated, service_role;

-- Update update_collection to accept is_public
CREATE OR REPLACE FUNCTION update_collection(
  p_collection_id uuid,
  p_name text,
  p_cover_color text,
  p_is_public boolean DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE collections
  SET
    name        = COALESCE(p_name, name),
    cover_color = p_cover_color,
    is_public   = COALESCE(p_is_public, is_public)
  WHERE collection_id = p_collection_id
    AND created_by = auth.uid();
END;
$$;
