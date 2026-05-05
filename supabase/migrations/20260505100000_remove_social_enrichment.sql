-- Remove social enrichment plumbing (social_vibe_vector / social_extraction)
-- and simplify save_location_with_tags back to the 5-arg signature used by
-- the app clients.

-- 1) Drop any social enrichment columns (safe if they were never added).
ALTER TABLE public.user_location_actions
  DROP COLUMN IF EXISTS social_vibe_vector,
  DROP COLUMN IF EXISTS social_extraction,
  DROP COLUMN IF EXISTS social_extraction_version;

-- 2) Drop helper functions that only existed to blend in social vectors.
DROP FUNCTION IF EXISTS public.blend_vibe_vectors(integer[], real[], real);

-- 3) Replace save_location_with_tags with the simple 5-arg version.
--    (Also resolves any PostgREST overload ambiguity by leaving only one
--    matching signature for typical callers.)
DROP FUNCTION IF EXISTS public.save_location_with_tags(
  uuid, integer, text, boolean, text, real[], jsonb, smallint
);

CREATE OR REPLACE FUNCTION public.save_location_with_tags(
    p_user_id uuid,
    p_location_id integer,
    p_saved_method text,
    p_acked boolean,
    p_source_video_url text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_location_id INTEGER;
    v_action_exists BOOLEAN := FALSE;
    v_timestamp TIMESTAMPTZ := NOW();
    v_location_vibes REAL[];
    v_user_vibes REAL[];
    v_multiplier NUMERIC;
    v_interaction_weight NUMERIC;
    v_top_k INTEGER := 2;
    v_top_k_indices INTEGER[];
    v_shared_collection_id UUID;
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
            'action_created', FALSE,
            'message', 'Location already saved'
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

    -- Step 5: Update User Vibe Vector (top-K only). Guarded against NULL / short vectors.
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
                            v_user_vibes[i] + ((v_location_vibes[i] - v_user_vibes[i]) / 100.0) * v_multiplier * v_interaction_weight
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
END;
$function$;

GRANT EXECUTE ON FUNCTION public.save_location_with_tags(uuid, integer, text, boolean, text)
  TO anon, authenticated, service_role;

