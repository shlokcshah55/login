CREATE OR REPLACE FUNCTION get_curated_collections(p_user_id uuid DEFAULT NULL)
RETURNS TABLE (
  collection_id   uuid,
  name            text,
  description     text,
  emoji           text,
  cover_color     text,
  photo           text,
  curated_city    text,
  place_count     bigint,
  owner_name      text,
  owner_avatar_url text,
  is_public       boolean,
  can_edit        boolean,
  is_saved        boolean,
  save_count      bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    c.collection_id,
    c.name,
    c.description,
    c.emoji,
    c.cover_color,
    c.photo,
    c.curated_city,
    COUNT(DISTINCT cl.location_id)                         AS place_count,
    NULL::text                                             AS owner_name,
    NULL::text                                             AS owner_avatar_url,
    c.is_public,
    false                                                  AS can_edit,
    CASE WHEN p_user_id IS NOT NULL
         THEN EXISTS (
           SELECT 1 FROM collection_saves cs
           WHERE cs.collection_id = c.collection_id
             AND cs.user_id = p_user_id
         )
         ELSE false
    END                                                    AS is_saved,
    (SELECT COUNT(*) FROM collection_saves cs2
     WHERE cs2.collection_id = c.collection_id)           AS save_count
  FROM collections c
  LEFT JOIN collection_locations cl ON cl.collection_id = c.collection_id
  WHERE c.is_curated = true
  GROUP BY c.collection_id
  ORDER BY c.curated_city NULLS LAST, c.name;
$$;
