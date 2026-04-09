-- Fix save_location_with_tags rolling back its own INSERT.
--
-- Same shape as 20260410120000_dislike_location_guard_vibe_update: the
-- function body has a top-level `WHEN OTHERS` rescue, and Step 5's
-- vibe-vector UPDATE dereferences v_user_vibes[i] without first checking
-- whether the array is NULL or short. New accounts (NULL
-- vibe_tag_affinity) and locations with a missing vibe_vector blow up
-- there, the rescue catches it, the whole sub-transaction rolls back —
-- including the Step 3 INSERT into user_location_actions — and PostgREST
-- happily returns 200 with {success: false}. Flutter saw "RPC succeeded"
-- but no row landed.
--
-- Fix: guard the UPDATE the same way unsave_location already does, and
-- additionally check array_length so a short vector can't crash array_agg
-- either. Also add SECURITY DEFINER + search_path so this function has
-- the same execution context as its siblings.

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
                    v_user_vibes[i] + ((v_location_vibes[i] - v_user_vibes[i]) / 100.0) * v_multiplier * v_interaction_weight
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
