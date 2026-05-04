CREATE OR REPLACE FUNCTION public.unsave_location(p_user_id uuid, p_location_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_saved_method  saved_method;
    v_location_vibes REAL[];
    v_user_vibes     REAL[];
    v_multiplier     NUMERIC;
    v_interaction_weight NUMERIC;
    v_top_k INTEGER := 2;
    v_top_k_indices INTEGER[];
BEGIN
    -- Step 1: Look up the original save row so we know which multiplier
    --         was applied when the user first saved this location.
    --         If there is no save row there is nothing to undo.
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
    --         the formula in save_location_with_tags. This is not an
    --         exact rollback (the user's affinity has evolved since the
    --         original save), it is a stock counter-effect that stops
    --         repeated save/unsave cycles from compounding.
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
        -- Mirror save_location_with_tags by undoing only the top-K vibe
        -- dimensions (ranked by location.vibe_vector).
        SELECT array_agg(i ORDER BY score DESC NULLS LAST, i)
          INTO v_top_k_indices
        FROM (
            SELECT i, v_location_vibes[i] AS score
            FROM generate_series(1, 25) AS i
            ORDER BY score DESC NULLS LAST, i
            LIMIT v_top_k
        ) ranked;

        UPDATE users
        SET vibe_tag_affinity = (
            SELECT array_agg(
                LEAST(100.0, GREATEST(0.0,
                    CASE
                        WHEN i = ANY(v_top_k_indices) THEN
                            v_user_vibes[i] - ((v_location_vibes[i] - v_user_vibes[i]) / 100.0) * v_multiplier * v_interaction_weight
                        ELSE
                            v_user_vibes[i]
                    END
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
    --         bookkeeping inside the RPC, so callers don't need a
    --         second round-trip. decrement_saves_count clamps at 0.
    PERFORM decrement_saves_count(p_location_id);
END;
$function$
;
