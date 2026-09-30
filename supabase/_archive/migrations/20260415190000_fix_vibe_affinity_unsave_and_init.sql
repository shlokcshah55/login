-- ============================================================================
-- Fix two bugs that can leave users.vibe_tag_affinity NULL / zeroed:
--
--   1. unsave_location was missing the array_length >= 25 guard that
--      save_location_with_tags and dislike_location_with_tags already have.
--      When a user's vibe_tag_affinity was NULL, empty, or a different
--      length, the generate_series(1, 25) loop dereferenced out-of-range
--      indices (producing NULLs) and/or truncated longer arrays to 25
--      elements. Any of those paths ended with the UPDATE writing a
--      NULL-spotted or truncated array, observed as "all zeros" client-side.
--
--   2. initialize_vibe_tags_for_user used `WHERE id = p_user_id`, but the
--      users table has no `id` column — the primary key is `supabase_id`.
--      The UPDATE matched zero rows (or errored, depending on how the
--      plpgsql parser resolved it), so new users never got the default
--      [50,50,...,0,50,50,50,50] vector from this RPC. The Dart signup
--      wizard's direct write in tags.dart:updateUserTagsPhotos was the
--      only path that actually seeded the column — and it early-returns
--      when no selected tag names match _vibeTagOrder, leaving the user
--      with NULL vibe_tag_affinity. That NULL then flowed into unsave's
--      unguarded writer, producing the zero output.
-- ============================================================================

-- ── 1. unsave_location: add length guard (matches save/dislike) ───────────────
CREATE OR REPLACE FUNCTION public.unsave_location(
    p_user_id     uuid,
    p_location_id integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_saved_method        saved_method;
    v_location_vibes      REAL[];
    v_user_vibes          REAL[];
    v_multiplier          NUMERIC;
    v_interaction_weight  NUMERIC;
BEGIN
    SELECT saved_method
      INTO v_saved_method
    FROM user_location_actions
    WHERE user_id = p_user_id
      AND location_id = p_location_id
      AND action = 'save'
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT calculate_interaction_weight(p_user_id) INTO v_interaction_weight;

    SELECT vibe_vector
      INTO v_location_vibes
    FROM locations
    WHERE location_id = p_location_id;

    SELECT vibe_tag_affinity
      INTO v_user_vibes
    FROM users
    WHERE supabase_id = p_user_id;

    IF v_saved_method IN ('tiktok', 'instagram') THEN
        v_multiplier := 5.0;
    ELSE
        v_multiplier := 3.0;
    END IF;

    -- Guarded update — NULL, empty, or short vectors would dereference
    -- out-of-range indices in generate_series(1, 25), wiping slots to NULL.
    IF v_user_vibes IS NOT NULL
       AND v_location_vibes IS NOT NULL
       AND array_length(v_user_vibes, 1) >= 25
       AND array_length(v_location_vibes, 1) >= 25 THEN
        UPDATE users
        SET vibe_tag_affinity = (
            SELECT array_agg(
                LEAST(100.0, GREATEST(0.0,
                    v_user_vibes[i] - ((v_location_vibes[i] - v_user_vibes[i]) / 100.0) * v_multiplier * v_interaction_weight
                ))
                ORDER BY i
            )
            FROM generate_series(1, 25) AS i
        )
        WHERE supabase_id = p_user_id;
    END IF;

    DELETE FROM user_location_actions
    WHERE user_id = p_user_id
      AND location_id = p_location_id
      AND action = 'save';

    PERFORM decrement_saves_count(p_location_id);
END;
$function$;


-- ── 2. initialize_vibe_tags_for_user: WHERE id → WHERE supabase_id ────────────
CREATE OR REPLACE FUNCTION public.initialize_vibe_tags_for_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE users
    SET vibe_tag_affinity = ARRAY[50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 0, 50, 50, 50, 50]
    WHERE supabase_id = p_user_id;
END;
$function$;
