-- Install the dislike_location_with_tags RPC. The definition has lived in
-- supabase/rpcs/dislike_location_with_tags.sql as a reference, but it was
-- never packaged into a migration, so remote deployments don't have it and
-- lib/supabase/helpers/location.dart's dislikeLocation call fails with
-- PGRST202 (function not found in schema cache).
--
-- Behaviour mirrors the reference file verbatim: records the dislike action,
-- bumps the location's dislike count, and nudges the user's vibe affinity
-- away from the location's vibe vector.

CREATE OR REPLACE FUNCTION public.dislike_location_with_tags(
    p_user_id     uuid,
    p_location_id integer
)
RETURNS jsonb
LANGUAGE plpgsql
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

    -- Step 5: Update User Vibe Vector (push away from location vibes)
    SELECT calculate_interaction_weight(p_user_id) INTO v_interaction_weight;

    SELECT vibe_vector INTO v_location_vibes FROM locations WHERE location_id = v_location_id;
    SELECT vibe_tag_affinity INTO v_user_vibes FROM users WHERE supabase_id = p_user_id;

    UPDATE users
    SET vibe_tag_affinity = (
        SELECT array_agg(
            LEAST(100.0, GREATEST(0.0,
                v_user_vibes[i] + ((v_user_vibes[i] - v_location_vibes[i]) / 100.0) * 2.0 * v_interaction_weight
            ))
            ORDER BY i
        )
        FROM generate_series(1, 25) AS i
    )
    WHERE supabase_id = p_user_id;

    -- Step 6: Return Success
    RETURN jsonb_build_object(
        'success', TRUE, 'location_id', v_location_id,
        'action_created', TRUE, 'popularity_updated', TRUE, 'vibes_updated', TRUE
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
