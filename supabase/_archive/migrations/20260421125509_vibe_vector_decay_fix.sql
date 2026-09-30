-- Fixes for vibe vector calculation updates to prevent compounding vector collapse
-- Drops decay coefficient in calculate_interaction_weight from 0.0135 to 0.002
-- Updates divisors to 10.0 for save/unsave and 25.0 for dislikes for more meaningful vibe changes

CREATE OR REPLACE FUNCTION public.calculate_interaction_weight(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_interaction_count INTEGER;
    v_weight NUMERIC;
    v_decay_coefficient NUMERIC := 0.002;
BEGIN
    -- Count total location actions for this user
    SELECT COUNT(*) INTO v_interaction_count
    FROM user_location_actions
    WHERE user_id = p_user_id;

    -- Calculate inverse-log decay weight
    -- With 0.002, 50 interactions = 0.99, 100 interactions = ~0.99, preventing premature decay
    v_weight := 1.0 / (1.0 + v_decay_coefficient * LN(1 + v_interaction_count));

    -- Clamp to valid range [0.0, 1.0]
    v_weight := LEAST(GREATEST(v_weight, 0.0), 1.0);

    RETURN v_weight;
END;
$function$;

CREATE OR REPLACE FUNCTION public.save_location_with_tags(
    p_user_id          uuid,
    p_location_id      integer,
    p_saved_method     text,
    p_acked            boolean,
    p_source_video_url text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_location_id        INTEGER;
    v_action_exists      BOOLEAN := FALSE;
    v_timestamp          TIMESTAMPTZ := NOW();
    v_location_vibes     REAL[];
    v_user_vibes         REAL[];
    v_multiplier         NUMERIC;
    v_interaction_weight NUMERIC;
BEGIN
    -- Step 1: Verify Location Exists
    SELECT location_id INTO v_location_id
    FROM locations WHERE location_id = p_location_id;

    IF v_location_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Location ID ' || p_location_id || ' not found');
    END IF;

    -- Step 2: Check for Duplicate Save (Idempotent)
    SELECT EXISTS (
        SELECT 1 FROM user_location_actions
        WHERE user_id = p_user_id AND location_id = v_location_id AND action = 'save'
    ) INTO v_action_exists;

    IF v_action_exists THEN
        RETURN jsonb_build_object(
            'success', TRUE, 'location_id', v_location_id,
            'action_created', FALSE, 'message', 'Location already saved'
        );
    END IF;

    -- Step 3: Create User Location Action
    INSERT INTO user_location_actions (
        user_id, location_id, action, saved_method, source_video_url, acked, created_at
    ) VALUES (
        p_user_id, v_location_id, 'save', p_saved_method::saved_method,
        p_source_video_url, p_acked, v_timestamp
    );

    -- Step 4: Update Location Popularity
    PERFORM increment_saves_count(v_location_id);

    -- Step 5: Update User Vibe Vector. Guarded against NULL / short
    -- vectors so a missing vector can never roll back the INSERT above.
    SELECT calculate_interaction_weight(p_user_id) INTO v_interaction_weight;

    SELECT vibe_vector INTO v_location_vibes FROM locations WHERE location_id = v_location_id;
    SELECT vibe_tag_affinity INTO v_user_vibes FROM users WHERE supabase_id = p_user_id;

    IF p_saved_method IN ('tiktok', 'instagram') THEN
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
                    v_user_vibes[i] + ((v_location_vibes[i] - v_user_vibes[i]) / 10.0) * v_multiplier * v_interaction_weight
                ))
                ORDER BY i
            )
            FROM generate_series(1, 25) AS i
        )
        WHERE supabase_id = p_user_id;
    END IF;

    -- Step 6: Return Success
    RETURN jsonb_build_object(
        'success', TRUE, 'location_id', v_location_id,
        'action_created', TRUE, 'popularity_updated', TRUE,
        'vibes_updated', (v_user_vibes IS NOT NULL AND v_location_vibes IS NOT NULL)
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid reference: ' || SQLERRM);
    WHEN unique_violation THEN
        RETURN jsonb_build_object('success', TRUE, 'location_id', v_location_id,
            'action_created', FALSE, 'message', 'Location already saved (race condition)');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$function$;

CREATE OR REPLACE FUNCTION public.dislike_location_with_tags(
    p_user_id     uuid,
    p_location_id integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_location_id        INTEGER;
    v_action_exists      BOOLEAN := FALSE;
    v_location_vibes     REAL[];
    v_user_vibes         REAL[];
    v_interaction_weight NUMERIC;
BEGIN
    -- Step 1: Verify Location Exists
    SELECT location_id INTO v_location_id
    FROM locations WHERE location_id = p_location_id;

    IF v_location_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Location ID ' || p_location_id || ' not found');
    END IF;

    -- Step 2: Check for Duplicate Dislike (Idempotent)
    SELECT EXISTS (
        SELECT 1 FROM user_location_actions
        WHERE user_id = p_user_id AND location_id = v_location_id AND action = 'dislike'
    ) INTO v_action_exists;

    IF v_action_exists THEN
        RETURN jsonb_build_object(
            'success', TRUE, 'location_id', v_location_id,
            'action_created', FALSE, 'message', 'Location already disliked'
        );
    END IF;

    -- Step 3: Create User Location Action
    INSERT INTO user_location_actions (
        user_id, location_id, action, acked, created_at
    ) VALUES (
        p_user_id, v_location_id, 'dislike', TRUE, NOW()
    );

    -- Step 4: Update Location Popularity
    PERFORM increment_dislikes_count(v_location_id);

    -- Step 5: Update User Vibe Vector (push away from location vibes).
    -- Guarded against NULLs so a missing vector can never roll back the
    -- INSERT above.
    SELECT calculate_interaction_weight(p_user_id) INTO v_interaction_weight;

    SELECT vibe_vector INTO v_location_vibes FROM locations WHERE location_id = v_location_id;
    SELECT vibe_tag_affinity INTO v_user_vibes FROM users WHERE supabase_id = p_user_id;

    IF v_user_vibes IS NOT NULL
       AND v_location_vibes IS NOT NULL
       AND array_length(v_user_vibes, 1) >= 25
       AND array_length(v_location_vibes, 1) >= 25 THEN
        UPDATE users
        SET vibe_tag_affinity = (
            SELECT array_agg(
                LEAST(100.0, GREATEST(0.0,
                    v_user_vibes[i] + ((v_user_vibes[i] - v_location_vibes[i]) / 25.0) * 2.0 * v_interaction_weight
                ))
                ORDER BY i
            )
            FROM generate_series(1, 25) AS i
        )
        WHERE supabase_id = p_user_id;
    END IF;

    -- Step 6: Return Success
    RETURN jsonb_build_object(
        'success', TRUE, 'location_id', v_location_id,
        'action_created', TRUE, 'popularity_updated', TRUE,
        'vibes_updated', (v_user_vibes IS NOT NULL AND v_location_vibes IS NOT NULL)
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid reference: ' || SQLERRM);
    WHEN unique_violation THEN
        RETURN jsonb_build_object('success', TRUE, 'location_id', v_location_id,
            'action_created', FALSE, 'message', 'Location already disliked (race condition)');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$function$;

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
    -- save_location_with_tags' formula. 
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
                    v_user_vibes[i] - ((v_location_vibes[i] - v_user_vibes[i]) / 10.0) * v_multiplier * v_interaction_weight
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
