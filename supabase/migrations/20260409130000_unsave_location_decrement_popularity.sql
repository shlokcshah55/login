-- Bake popularity decrement into unsave_location so the RPC is the
-- single source of truth for unsave side-effects, mirroring how
-- save_location_with_tags already calls increment_saves_count
-- internally. Removes the need for callers to make a second round-trip
-- to update_location_popularity after unsaving.

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

    PERFORM decrement_saves_count(p_location_id);
END;
$function$;
