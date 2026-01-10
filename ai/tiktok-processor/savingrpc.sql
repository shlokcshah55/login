DECLARE
    v_location_id INTEGER;
    v_action_exists BOOLEAN := FALSE;
    v_location_tags RECORD;
    v_user_tag_scores JSONB;
    v_interaction_weight NUMERIC;
    v_tag_updates JSONB := '[]'::JSONB;
    v_save_updates JSONB := '[]'::JSONB;
    v_share_updates JSONB := '[]'::JSONB;
    v_current_affinity NUMERIC;
    v_delta NUMERIC;
    v_new_affinity NUMERIC;
    v_evidence JSONB;
    v_timestamp TIMESTAMPTZ := NOW();
    v_save_value INTEGER := 5;
    v_share_value INTEGER := 10;
    v_tag_count INTEGER := 0;
BEGIN
    -- ========================================================================
    -- Step 1: Verify Location Exists
    -- ========================================================================

    SELECT location_id INTO v_location_id
    FROM locations
    WHERE location_id = p_location_id;

    IF v_location_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Location ID ' || p_location_id || ' not found'
        );
    END IF;

    -- ========================================================================
    -- Step 2: Check for Duplicate Save (Idempotent)
    -- ========================================================================

    SELECT EXISTS (
        SELECT 1
        FROM user_location_actions
        WHERE user_id = p_user_id
          AND location_id = v_location_id
          AND action = 'save'
    ) INTO v_action_exists;

    IF v_action_exists THEN
        RETURN jsonb_build_object(
            'success', TRUE,
            'location_id', v_location_id,
            'action_created', FALSE,
            'popularity_updated', FALSE,
            'tags_updated', FALSE,
            'tag_count', 0,
            'message', 'Location already saved'
        );
    END IF;

    -- ========================================================================
    -- Step 3: Create User Location Action
    -- ========================================================================

    INSERT INTO user_location_actions (
        user_id,
        location_id,
        action,
        saved_method,
        source_video_url,
        acked,
        created_at
    ) VALUES (
        p_user_id,
        v_location_id,
        'save',
        p_saved_method::saved_method,  -- Cast text to enum type
        p_source_video_url,
        p_acked,
        v_timestamp
    );

    -- ========================================================================
    -- Step 4: Update Location Popularity
    -- ========================================================================

    PERFORM increment_saves_count(v_location_id);

    -- ========================================================================
    -- Step 5: Get User Tag Scores
    -- ========================================================================

    SELECT get_user_tag_scores(p_user_id) INTO v_user_tag_scores;

    -- ========================================================================
    -- Step 6: Calculate Interaction Weight
    -- ========================================================================

    SELECT calculate_interaction_weight(p_user_id) INTO v_interaction_weight;

    -- ========================================================================
    -- Step 7: Process Tag Updates
    -- ========================================================================

    -- Special handling for TikTok: apply BOTH save and share weights
    IF p_saved_method = 'tiktok' THEN
        -- Process SAVE weight (value = 5)
        FOR v_location_tags IN
            SELECT lt.tag_id, lt.score
            FROM location_tags lt
            JOIN tags t ON lt.tag_id = t.tag_id
            WHERE lt.location_id = v_location_id
              AND t.tag_type = 'vibe'
        LOOP
            -- Get current affinity from user_tag_scores
            SELECT (elem->>'affinity')::NUMERIC INTO v_current_affinity
            FROM jsonb_array_elements(v_user_tag_scores) AS elem
            WHERE (elem->>'tag_id')::uuid = v_location_tags.tag_id;

            -- If user doesn't have this tag yet, default to 50.0
            v_current_affinity := COALESCE(v_current_affinity, 50.0);

            -- Calculate delta for SAVE
            v_delta := calculate_tag_affinity_delta(
                v_current_affinity,
                v_location_tags.score,
                v_save_value,
                v_interaction_weight
            );

            v_new_affinity := v_current_affinity + v_delta;

            -- Build evidence object for SAVE
            v_evidence := jsonb_build_object(
                'action', 'saved',
                'location_id', v_location_id,
                'timestamp', v_timestamp,
                'value', v_save_value,
                'delta', v_delta,
                'weight', v_interaction_weight
            );

            -- Add to save updates
            v_save_updates := v_save_updates || jsonb_build_array(jsonb_build_object(
                'tag_id', v_location_tags.tag_id,
                'affinity', v_new_affinity,
                'evidence', v_evidence
            ));

            v_tag_count := v_tag_count + 1;
        END LOOP;

        -- Process SHARE weight (value = 10)
        FOR v_location_tags IN
            SELECT lt.tag_id, lt.score
            FROM location_tags lt
            JOIN tags t ON lt.tag_id = t.tag_id
            WHERE lt.location_id = v_location_id
              AND t.tag_type = 'vibe'
        LOOP
            -- Get updated affinity after save (from save_updates)
            SELECT (elem->>'affinity')::NUMERIC INTO v_current_affinity
            FROM jsonb_array_elements(v_save_updates) AS elem
            WHERE (elem->>'tag_id')::uuid = v_location_tags.tag_id;

            -- Calculate delta for SHARE
            v_delta := calculate_tag_affinity_delta(
                v_current_affinity,
                v_location_tags.score,
                v_share_value,
                v_interaction_weight
            );

            v_new_affinity := v_current_affinity + v_delta;

            -- Build evidence object for SHARE
            v_evidence := jsonb_build_object(
                'action', 'shared',
                'location_id', v_location_id,
                'timestamp', v_timestamp,
                'value', v_share_value,
                'delta', v_delta,
                'weight', v_interaction_weight
            );

            -- Add to share updates
            v_share_updates := v_share_updates || jsonb_build_array(jsonb_build_object(
                'tag_id', v_location_tags.tag_id,
                'affinity', v_new_affinity,
                'evidence', v_evidence
            ));

            v_tag_count := v_tag_count + 1;
        END LOOP;

        -- Combine save and share updates
        v_tag_updates := v_save_updates || v_share_updates;

    ELSE
        -- Regular save (in-app): only apply save weight
        FOR v_location_tags IN
            SELECT lt.tag_id, lt.score
            FROM location_tags lt
            JOIN tags t ON lt.tag_id = t.tag_id
            WHERE lt.location_id = v_location_id
              AND t.tag_type = 'vibe'
        LOOP
            -- Get current affinity
            SELECT (elem->>'affinity')::NUMERIC INTO v_current_affinity
            FROM jsonb_array_elements(v_user_tag_scores) AS elem
            WHERE (elem->>'tag_id')::uuid = v_location_tags.tag_id;

            v_current_affinity := COALESCE(v_current_affinity, 50.0);

            -- Calculate delta
            v_delta := calculate_tag_affinity_delta(
                v_current_affinity,
                v_location_tags.score,
                v_save_value,
                v_interaction_weight
            );

            v_new_affinity := v_current_affinity + v_delta;

            -- Build evidence
            v_evidence := jsonb_build_object(
                'action', 'saved',
                'location_id', v_location_id,
                'timestamp', v_timestamp,
                'value', v_save_value,
                'delta', v_delta,
                'weight', v_interaction_weight
            );

            -- Add to updates
            v_tag_updates := v_tag_updates || jsonb_build_array(jsonb_build_object(
                'tag_id', v_location_tags.tag_id,
                'affinity', v_new_affinity,
                'evidence', v_evidence
            ));

            v_tag_count := v_tag_count + 1;
        END LOOP;
    END IF;

    -- ========================================================================
    -- Step 8: Apply Tag Affinity Updates
    -- ========================================================================

    IF jsonb_array_length(v_tag_updates) > 0 THEN
        PERFORM update_user_tag_affinity(p_user_id, v_tag_updates);
    END IF;

    -- ========================================================================
    -- Step 9: Return Success Response
    -- ========================================================================

    RETURN jsonb_build_object(
        'success', TRUE,
        'location_id', v_location_id,
        'action_created', TRUE,
        'popularity_updated', TRUE,
        'tags_updated', TRUE,
        'tag_count', v_tag_count
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Invalid reference: ' || SQLERRM
        );
    WHEN unique_violation THEN
        -- Race condition: action was created between our check and insert
        RETURN jsonb_build_object(
            'success', TRUE,
            'location_id', v_location_id,
            'action_created', FALSE,
            'message', 'Location already saved (race condition)'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', SQLERRM
        );
END;