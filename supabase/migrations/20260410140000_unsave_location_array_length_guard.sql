-- Harden unsave_location against short vibe vectors.
--
-- The previous migration (20260409120000) guarded the vibe-affinity UPDATE
-- with `IF v_user_vibes IS NOT NULL AND v_location_vibes IS NOT NULL`,
-- which catches the new-account case but NOT the case where one of the
-- vectors exists but has fewer than 25 elements (legacy rows, partial
-- migrations, mid-rollout schema). In that case the inner array_agg over
-- generate_series(1, 25) dereferences past the end of the array and
-- throws.
--
-- unsave_location has no WHEN OTHERS rescue so this would surface as a
-- 5xx rather than a silent rollback, but it still leaves the function
-- unable to complete and the DELETE never runs. Mirror the array_length
-- check from the save/dislike fixes for consistency.

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
    -- Step 1: Look up the original save row so we know which multiplier
    -- was applied when the user first saved this location. If there is
    -- no save row there is nothing to undo.
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

    -- Step 2: Apply a stock negated vibe-affinity nudge — the inverse of
    -- save_location_with_tags' formula. Stock counter-effect, not an
    -- exact rollback.
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

    -- Step 3: Delete the save row.
    DELETE FROM user_location_actions
    WHERE user_id = p_user_id
      AND location_id = p_location_id
      AND action = 'save';

    -- Step 4: Mirror save_location_with_tags by handling popularity
    -- bookkeeping inside the RPC. decrement_saves_count clamps at 0.
    PERFORM decrement_saves_count(p_location_id);
END;
$function$;
