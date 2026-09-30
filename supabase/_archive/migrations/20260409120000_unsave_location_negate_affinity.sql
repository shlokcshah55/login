-- Apply a stock negated vibe-affinity nudge when a user unsaves a
-- location. This is the inverse of the formula in
-- save_location_with_tags: it is not an exact rollback, it is a stock
-- counter-effect that prevents repeated save/unsave cycles from
-- compounding the affinity nudge in one direction.
--
-- Trade-off: a user who genuinely changes their mind will see their
-- affinity nudged back roughly to where they started. We accept that
-- because the alternative (a one-time grant ledger) is overkill for
-- the scale of abuse this realistically protects against. We can
-- revisit if we ever observe affinity drift in practice.

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
    -- Look up the original save row so we know which multiplier was
    -- applied when the user first saved this location. If there is no
    -- save row there is nothing to undo.
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

    -- Apply the inverse of save_location_with_tags' nudge.
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

    IF v_user_vibes IS NOT NULL AND v_location_vibes IS NOT NULL THEN
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
END;
$function$;
