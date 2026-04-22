-- Fix get_suggested_users RPC: users.dietary_requirement_tag_affinity is real[]
-- in the current schema, but the RPC signature expects integer[].
-- Cast element-wise to integer[] to satisfy the function result type.

DROP FUNCTION IF EXISTS public.get_suggested_users(uuid, integer);

CREATE OR REPLACE FUNCTION public.get_suggested_users(
  p_supabase_id uuid,
  p_limit integer DEFAULT 10
)
RETURNS TABLE(
  supabase_id uuid,
  name text,
  email text,
  profile_image_url text,
  created_at timestamp without time zone,
  bio text,
  spice_tolerance integer,
  wizard_completed boolean,
  username text,
  vibe_tag_affinity real[],
  dietary_requirement_tag_affinity integer[],
  generated_collections boolean,
  followers_count bigint,
  following_count bigint
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  current_vibe real[];
BEGIN
  SELECT u.vibe_tag_affinity INTO current_vibe
  FROM users u
  WHERE u.supabase_id = p_supabase_id;

  RETURN QUERY
  WITH candidates AS (
    -- All users the current user has no relationship with yet
    SELECT u.*
    FROM users u
    WHERE u.supabase_id <> p_supabase_id
      AND NOT EXISTS (
        SELECT 1 FROM user_friends uf
        WHERE (uf.follower_id = p_supabase_id AND uf.followee_id = u.supabase_id)
           OR (uf.follower_id = u.supabase_id AND uf.followee_id = p_supabase_id)
      )
  ),
  scored AS (
    SELECT
      c.*,
      CASE
        WHEN current_vibe IS NULL
          OR c.vibe_tag_affinity IS NULL
          OR array_length(current_vibe, 1) IS NULL
          OR array_length(c.vibe_tag_affinity, 1) IS NULL
        THEN -1.0::double precision
        ELSE (
          SELECT
            CASE
              WHEN norm1 = 0 OR norm2 = 0 THEN 0.0
              ELSE GREATEST(0.0, LEAST(1.0,
                (dot / (SQRT(norm1) * SQRT(norm2)) + 1.0) / 2.0
              ))
            END
          FROM (
            SELECT
              SUM((a_v - a_mean) * (b_v - b_mean)) AS dot,
              SUM(POWER(a_v - a_mean, 2))           AS norm1,
              SUM(POWER(b_v - b_mean, 2))           AS norm2
            FROM (
              SELECT
                COALESCE(current_vibe[gs], 0)::float         AS a_v,
                COALESCE(c.vibe_tag_affinity[gs], 0)::float  AS b_v,
                (SELECT AVG(x::float) FROM unnest(current_vibe) x)            AS a_mean,
                (SELECT AVG(x::float) FROM unnest(c.vibe_tag_affinity) x)     AS b_mean
              FROM generate_series(
                1,
                GREATEST(
                  COALESCE(array_length(current_vibe, 1), 0),
                  COALESCE(array_length(c.vibe_tag_affinity, 1), 0)
                )
              ) gs
            ) elems
          ) agg
        )
      END AS vibe_similarity
    FROM candidates c
  )
  SELECT
    s.supabase_id,
    s.name,
    s.email,
    s.profile_image_url,
    s.created_at,
    s.bio,
    s.spice_tolerance::integer,
    s.wizard_completed,
    s.username,
    s.vibe_tag_affinity,
    CASE
      WHEN s.dietary_requirement_tag_affinity IS NULL THEN NULL::integer[]
      ELSE ARRAY(
        SELECT (x::integer)
        FROM unnest(s.dietary_requirement_tag_affinity) AS x
      )
    END AS dietary_requirement_tag_affinity,
    s.generated_collections IS NOT NULL AS generated_collections,
    (SELECT COUNT(*) FROM user_friends uf
     WHERE uf.followee_id = s.supabase_id
       AND uf.status = 'accepted')::bigint AS followers_count,
    (SELECT COUNT(*) FROM user_friends uf
     WHERE uf.follower_id = s.supabase_id
       AND uf.status = 'accepted')::bigint AS following_count
  FROM scored s
  ORDER BY s.vibe_similarity DESC
  LIMIT p_limit;
END;
$$;

