-- ─────────────────────────────────────────────────────────────
-- Fold dietary affinity persistence into complete_signup_wizard
-- and drop the obsolete add_user_tags_batch helper.
--
-- The signup wizard previously called add_user_tags_batch, which
-- wrote into a user_tags / user_tag_affinities table that no
-- longer exists in the schema. Dietary requirements now live as a
-- 6-element real[] column on public.users — exactly like
-- vibe_tag_affinity. complete_signup_wizard accepts the selected
-- dietary tag ids, resolves their names, and writes the resulting
-- 6-element vector in the same transaction as the spice_tolerance
-- / wizard_completed update.
--
-- Vector order (matches the column comment + ensure_user_record_exists default):
--   [halal, vegan, gluten-free, vegetarian, dairy-free, nut-free]
-- Selected entries are set to 100 (the same "fully expressed" magnitude
-- that vibe step uses when bumping from baseline 50 → 80; dietary
-- baseline is 0, so 100 is the analogous "definitely" value).
-- ─────────────────────────────────────────────────────────────

-- 1. Replace complete_signup_wizard with a version that also seeds
--    dietary affinity. Drop the old 2-arg signature first so callers
--    can't fall back to it.
DROP FUNCTION IF EXISTS public.complete_signup_wizard(uuid, integer);

CREATE OR REPLACE FUNCTION public.complete_signup_wizard(
  p_user_id          uuid,
  p_spice_tolerance  integer  DEFAULT NULL,
  p_dietary_tag_ids  uuid[]   DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_dietary_affinity real[] := ARRAY[0, 0, 0, 0, 0, 0]::real[];
  v_tag_names        text[];
BEGIN
  IF p_dietary_tag_ids IS NOT NULL AND array_length(p_dietary_tag_ids, 1) > 0 THEN
    -- Resolve selected tag ids → normalised tag names. Qualify the column
    -- reference so the parser never confuses `text` (column) with `text`
    -- (type). Trim + lowercase + strip spaces so storage variants like
    -- "Gluten Free" / "gluten-free " all match.
    SELECT array_agg(
             replace(lower(btrim(t.text)), ' ', '-')
           )
      INTO v_tag_names
      FROM public.tags t
      WHERE t.tag_id = ANY (p_dietary_tag_ids);

    IF v_tag_names IS NOT NULL THEN
      IF 'halal'       = ANY (v_tag_names) THEN v_dietary_affinity[1] := 100; END IF;
      IF 'vegan'       = ANY (v_tag_names) THEN v_dietary_affinity[2] := 100; END IF;
      IF 'gluten-free' = ANY (v_tag_names) THEN v_dietary_affinity[3] := 100; END IF;
      IF 'vegetarian'  = ANY (v_tag_names) THEN v_dietary_affinity[4] := 100; END IF;
      IF 'dairy-free'  = ANY (v_tag_names) THEN v_dietary_affinity[5] := 100; END IF;
      IF 'nut-free'    = ANY (v_tag_names) THEN v_dietary_affinity[6] := 100; END IF;
    END IF;

    RAISE NOTICE 'complete_signup_wizard: user=% tag_ids=% resolved_names=% affinity=%',
      p_user_id, p_dietary_tag_ids, v_tag_names, v_dietary_affinity;
  END IF;

  UPDATE public.users
  SET
    wizard_completed = true,
    spice_tolerance  = COALESCE(p_spice_tolerance, spice_tolerance),
    dietary_requirement_tag_affinity = CASE
      WHEN p_dietary_tag_ids IS NOT NULL
       AND array_length(p_dietary_tag_ids, 1) > 0
        THEN v_dietary_affinity
      ELSE dietary_requirement_tag_affinity
    END
  WHERE supabase_id = p_user_id;
END;
$$;

ALTER FUNCTION public.complete_signup_wizard(uuid, integer, uuid[])
  OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.complete_signup_wizard(uuid, integer, uuid[])
  TO anon, authenticated, service_role;


-- 2. Drop the now-redundant batch helper (wrote to a table that no
--    longer exists in this schema).
DROP FUNCTION IF EXISTS public.add_user_tags_batch(uuid, uuid[]);
