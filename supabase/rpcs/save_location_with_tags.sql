CREATE OR REPLACE FUNCTION public.save_location_with_tags(
    p_user_id uuid,
    p_location_id integer,
    p_saved_method text,
    p_acked boolean,
    p_source_video_url text,
    p_social_vibe_vector real[] DEFAULT NULL,
    p_social_extraction jsonb DEFAULT NULL,
    p_social_extraction_version smallint DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$DECLARE
    v_location_id INTEGER;
    v_action_exists BOOLEAN := FALSE;
    v_timestamp TIMESTAMPTZ := NOW();
    v_location_vibes REAL[];
    v_user_vibes REAL[];
    v_multiplier NUMERIC;
    v_interaction_weight NUMERIC;
    v_shared_collection_id UUID;
    v_has_social_enrichment BOOLEAN := (p_social_vibe_vector IS NOT NULL OR p_social_extraction IS NOT NULL);
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
        -- Don't silently drop enrichment for re-processed shares. If this
        -- call carries social enrichment, merge it into the existing save row
        -- so a later TikTok for an already-saved place still contributes its
        -- vibe signal, story, and dishes to the aggregate.
        IF v_has_social_enrichment THEN
            UPDATE user_location_actions
            SET
                social_vibe_vector = COALESCE(p_social_vibe_vector, social_vibe_vector),
                social_extraction = COALESCE(p_social_extraction, social_extraction),
                social_extraction_version = COALESCE(p_social_extraction_version, social_extraction_version),
                source_video_url = COALESCE(p_source_video_url, source_video_url)
            WHERE user_id = p_user_id AND location_id = v_location_id AND action = 'save';
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE, 'location_id', v_location_id,
            'action_created', FALSE,
            'enrichment_updated', v_has_social_enrichment,
            'message', CASE WHEN v_has_social_enrichment
                            THEN 'Location already saved — enrichment merged'
                            ELSE 'Location already saved' END
        );
    END IF;

    -- Step 3: Create User Location Action
    INSERT INTO user_location_actions (
        user_id, location_id, action, saved_method, source_video_url, acked, created_at,
        social_vibe_vector, social_extraction, social_extraction_version
    ) VALUES (
        p_user_id, v_location_id, 'save', p_saved_method::saved_method,
        p_source_video_url, p_acked, v_timestamp,
        p_social_vibe_vector, p_social_extraction, p_social_extraction_version
    );

    -- Step 4: Update Location Popularity
    PERFORM increment_saves_count(v_location_id);

    SELECT calculate_interaction_weight(p_user_id) INTO v_interaction_weight;

    -- Step 5: Update User Vibe Vector — but only if BOTH the user and the
    -- location have populated vibe vectors. When the location has no
    -- vibe_vector (hasn't been classified yet) the arithmetic below would
    -- propagate NULLs and wipe the user's whole affinity array to NULL.
    -- Same guard protects against unseeded users.
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

    -- Step 5b: Auto-add to "Shared Finds" collection for social saves.
    -- Non-fatal: a failure here must never roll back the save itself.
    IF p_saved_method IN ('tiktok', 'instagram') THEN
        BEGIN
            SELECT collection_id INTO v_shared_collection_id
            FROM collections
            WHERE created_by = p_user_id AND name = 'Shared Finds'
            LIMIT 1;

            IF v_shared_collection_id IS NULL THEN
                INSERT INTO collections (name, created_by, is_public)
                VALUES ('Shared Finds', p_user_id, true)
                RETURNING collection_id INTO v_shared_collection_id;
            END IF;

            INSERT INTO collection_locations (collection_id, location_id, added_by)
            VALUES (v_shared_collection_id, v_location_id, p_user_id)
            ON CONFLICT ON CONSTRAINT collection_locations_unique DO NOTHING;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

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
            'action_created', FALSE, 'message', 'Location already saved (race condition)');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;$function$
;
