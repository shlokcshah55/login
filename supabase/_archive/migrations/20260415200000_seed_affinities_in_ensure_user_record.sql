-- ============================================================================
-- Bake vibe + dietary affinity seeding into ensure_user_record_exists so a
-- new user row is fully initialized in a single INSERT. Replaces the previous
-- two-step flow where initialize_vibe_tags_for_user was called separately
-- from the Dart auth listener and silently failed (see the WHERE id bug
-- fixed in 20260415190000, and the general failure mode where swallowed
-- errors left vibe_tag_affinity NULL).
--
-- Defaults:
--   vibe_tag_affinity             25 elements, all 50 except index 21
--                                 (grocery_store) = 0. Matches the seed that
--                                 initialize_vibe_tags_for_user always wrote
--                                 and what tags.dart:updateUserTagsPhotos
--                                 builds on top of.
--   dietary_requirement_tag_affinity 6 elements, all 0
--                                 (halal, vegan, gluten-free, vegetarian,
--                                  dairy-free, nut-free). No preference is
--                                 the right default — these are allergy /
--                                 restriction flags, not affinities.
--
-- ON CONFLICT DO NOTHING preserves existing rows untouched, so this is safe
-- to re-run and won't clobber users who already have data.
--
-- Also drops the dead 3-arg overload of ensure_user_record_exists (no caller
-- in the codebase) so future edits don't have to worry about which one
-- Postgres will pick.
-- ============================================================================

DROP FUNCTION IF EXISTS public.ensure_user_record_exists(uuid, text, text);

CREATE OR REPLACE FUNCTION public.ensure_user_record_exists(
    p_supabase_id uuid,
    p_email       text,
    p_name        text,
    p_username    text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    INSERT INTO public.users (
        supabase_id,
        email,
        name,
        username,
        created_at,
        wizard_completed,
        vibe_tag_affinity,
        dietary_requirement_tag_affinity
    )
    VALUES (
        p_supabase_id,
        p_email,
        p_name,
        p_username,
        NOW(),
        false,
        ARRAY[50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 0, 50, 50, 50, 50],
        ARRAY[0, 0, 0, 0, 0, 0]
    )
    ON CONFLICT (supabase_id) DO NOTHING;

    RETURN p_supabase_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.ensure_user_record_exists(uuid, text, text, text)
    TO anon, authenticated, service_role;


-- ── Backfill existing users whose affinity vectors are still NULL ────────────
-- Same defaults as the INSERT above. Targets only NULL rows so it won't
-- touch users who already have data.
UPDATE public.users
SET vibe_tag_affinity = ARRAY[50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 0, 50, 50, 50, 50]
WHERE vibe_tag_affinity IS NULL;

UPDATE public.users
SET dietary_requirement_tag_affinity = ARRAY[0, 0, 0, 0, 0, 0]
WHERE dietary_requirement_tag_affinity IS NULL;
