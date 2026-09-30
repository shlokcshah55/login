CREATE OR REPLACE FUNCTION bubble_compatibility_score(p_bubble_id uuid)
RETURNS integer
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
  WITH members AS (
    SELECT u.supabase_id, u.vibe_tag_affinity AS vibe
    FROM bubble_members bm
    JOIN users u ON u.supabase_id = bm.user_id
    WHERE bm.bubble_id = p_bubble_id
      AND u.vibe_tag_affinity IS NOT NULL
      AND array_length(u.vibe_tag_affinity, 1) > 0
  ),
  pairs AS (
    -- self-join to get every unique (i, j) pair
    SELECT a.vibe AS va, b.vibe AS vb
    FROM members a
    JOIN members b ON a.supabase_id < b.supabase_id
  ),
  scored AS (
    SELECT
      (SELECT sum(av * bv)
         FROM unnest(va, vb) AS t(av, bv)
        WHERE av IS NOT NULL AND bv IS NOT NULL
      )::float
      / NULLIF(
          sqrt((SELECT sum(av * av) FROM unnest(va) AS t(av))) *
          sqrt((SELECT sum(bv * bv) FROM unnest(vb) AS t(bv))),
          0
        ) AS cosine
    FROM pairs
  )
  SELECT CASE
    WHEN (SELECT count(*) FROM members) = 0 THEN NULL
    WHEN (SELECT count(*) FROM members) = 1 THEN 100
    ELSE round(avg(cosine) * 100)::integer
  END
  FROM scored
  WHERE cosine IS NOT NULL
$$;
