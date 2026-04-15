-- ============================================================================
-- Fix vibe affinity handling:
--   1. Guard save_location_with_tags and dislike_location_with_tags so they
--      skip the affinity update when either the user or the location vibe
--      vector is NULL / short. Previously NULL propagation wiped the whole
--      users.vibe_tag_affinity array to NULLs (observed as "all zeros" on
--      the client) whenever a saved location had no vibe_vector yet.
--
--   2. Drop the stale update_user_tag_affinity RPC. It wrote to a `profiles`
--      table that doesn't exist in this schema, so it was always a silent
--      no-op. The Dart client writes vibe affinities directly now.
--
--   3. Fix user_with_counts composite type: vibe_tag_affinity and
--      dietary_requirement_tag_affinity were declared as integer[] even
--      though the columns on users are real[], causing server-side rounding
--      on every get_followers / get_following / search_users / etc. call.
-- ============================================================================

-- ── 1a. save_location_with_tags with NULL guard ───────────────────────────────
CREATE OR REPLACE FUNCTION public.save_location_with_tags(
    p_user_id uuid,
    p_location_id integer,
    p_saved_method text,
    p_acked boolean,
    p_source_video_url text
) RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
AS $function$
DECLARE
    v_location_id INTEGER;
    v_action_exists BOOLEAN := FALSE;
    v_timestamp TIMESTAMPTZ := NOW();
    v_location_vibes REAL[];
    v_user_vibes REAL[];
    v_multiplier NUMERIC;
    v_interaction_weight NUMERIC;
    v_shared_collection_id UUID;
BEGIN
    SELECT location_id INTO v_location_id
    FROM locations WHERE location_id = p_location_id;

    IF v_location_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Location ID ' || p_location_id || ' not found');
    END IF;

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

    INSERT INTO user_location_actions (
        user_id, location_id, action, saved_method, source_video_url, acked, created_at
    ) VALUES (
        p_user_id, v_location_id, 'save', p_saved_method::saved_method,
        p_source_video_url, p_acked, v_timestamp
    );

    PERFORM increment_saves_count(v_location_id);

    SELECT calculate_interaction_weight(p_user_id) INTO v_interaction_weight;

    SELECT vibe_vector INTO v_location_vibes FROM locations WHERE location_id = v_location_id;
    SELECT vibe_tag_affinity INTO v_user_vibes FROM users WHERE supabase_id = p_user_id;

    IF p_saved_method IN ('tiktok', 'instagram') THEN
        v_multiplier := 5.0;
    ELSE
        v_multiplier := 3.0;
    END IF;

    -- Guarded update — NULL or short vectors would wipe the user's affinities.
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

-- ── 1b. dislike_location_with_tags with NULL guard ────────────────────────────
CREATE OR REPLACE FUNCTION public.dislike_location_with_tags(
    p_user_id uuid,
    p_location_id integer
) RETURNS jsonb
  LANGUAGE plpgsql
AS $function$
DECLARE
    v_location_id INTEGER;
    v_action_exists BOOLEAN := FALSE;
    v_location_vibes REAL[];
    v_user_vibes REAL[];
    v_interaction_weight NUMERIC;
BEGIN
    SELECT location_id INTO v_location_id
    FROM locations WHERE location_id = p_location_id;

    IF v_location_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Location ID ' || p_location_id || ' not found');
    END IF;

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

    INSERT INTO user_location_actions (
        user_id, location_id, action, acked, created_at
    ) VALUES (
        p_user_id, v_location_id, 'dislike', TRUE, NOW()
    );

    PERFORM increment_dislikes_count(v_location_id);

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
                    v_user_vibes[i] + ((v_user_vibes[i] - v_location_vibes[i]) / 100.0) * 2.0 * v_interaction_weight
                ))
                ORDER BY i
            )
            FROM generate_series(1, 25) AS i
        )
        WHERE supabase_id = p_user_id;
    END IF;

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

-- ── 2. Drop the dead update_user_tag_affinity RPC ─────────────────────────────
DROP FUNCTION IF EXISTS public.update_user_tag_affinity(uuid, jsonb);

-- ── 3. Rebuild user_with_counts type with real[] affinity columns ─────────────
-- CASCADE drops the five dependent functions; we recreate them below.
DROP TYPE IF EXISTS public.user_with_counts CASCADE;

CREATE TYPE public.user_with_counts AS (
    name                            text,
    email                           text,
    created_at                      timestamp without time zone,
    supabase_id                     uuid,
    bio                             text,
    profile_image_url               text,
    phone_number                    text,
    spice_tolerance                 smallint,
    wizard_completed                boolean,
    username                        text,
    fcm_token                       text,
    fcm_token_updated_at            timestamp with time zone,
    vibe_tag_affinity               real[],
    dietary_requirement_tag_affinity real[],
    followers_count                 bigint,
    following_count                 bigint
);

CREATE OR REPLACE FUNCTION public.get_followers(p_user_id uuid)
RETURNS SETOF public.user_with_counts
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT
    u.name, u.email, u.created_at, u.supabase_id, u.bio,
    u.profile_image_url, u.phone_number, u.spice_tolerance,
    u.wizard_completed, u.username, u.fcm_token,
    u.fcm_token_updated_at, u.vibe_tag_affinity,
    u.dietary_requirement_tag_affinity,
    (SELECT count(*) FROM user_friends WHERE followee_id = u.supabase_id AND status = 'accepted') AS followers_count,
    (SELECT count(*) FROM user_friends WHERE follower_id = u.supabase_id AND status = 'accepted') AS following_count
  FROM user_friends f
  JOIN users u ON u.supabase_id = f.follower_id
  WHERE f.followee_id = p_user_id
    AND f.status = 'accepted'
  ORDER BY f.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_followers(uuid)
    TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_following(p_user_id uuid)
RETURNS SETOF public.user_with_counts
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT
    u.name, u.email, u.created_at, u.supabase_id, u.bio,
    u.profile_image_url, u.phone_number, u.spice_tolerance,
    u.wizard_completed, u.username, u.fcm_token,
    u.fcm_token_updated_at, u.vibe_tag_affinity,
    u.dietary_requirement_tag_affinity,
    (SELECT count(*) FROM user_friends WHERE followee_id = u.supabase_id AND status = 'accepted') AS followers_count,
    (SELECT count(*) FROM user_friends WHERE follower_id = u.supabase_id AND status = 'accepted') AS following_count
  FROM user_friends f
  JOIN users u ON u.supabase_id = f.followee_id
  WHERE f.follower_id = p_user_id
    AND f.status = 'accepted'
  ORDER BY f.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_following(uuid)
    TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_incoming_follow_requests(p_user_id uuid)
RETURNS SETOF public.user_with_counts
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT
    u.name, u.email, u.created_at, u.supabase_id, u.bio,
    u.profile_image_url, u.phone_number, u.spice_tolerance,
    u.wizard_completed, u.username, u.fcm_token,
    u.fcm_token_updated_at, u.vibe_tag_affinity,
    u.dietary_requirement_tag_affinity,
    (SELECT count(*) FROM user_friends WHERE followee_id = u.supabase_id AND status = 'accepted') AS followers_count,
    (SELECT count(*) FROM user_friends WHERE follower_id = u.supabase_id AND status = 'accepted') AS following_count
  FROM user_friends f
  JOIN users u ON u.supabase_id = f.follower_id
  WHERE f.followee_id = p_user_id
    AND f.status = 'requested'
  ORDER BY f.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_incoming_follow_requests(uuid)
    TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_blocked_users(p_user_id uuid)
RETURNS SETOF public.user_with_counts
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT
    u.name, u.email, u.created_at, u.supabase_id, u.bio,
    u.profile_image_url, u.phone_number, u.spice_tolerance,
    u.wizard_completed, u.username, u.fcm_token,
    u.fcm_token_updated_at, u.vibe_tag_affinity,
    u.dietary_requirement_tag_affinity,
    (SELECT count(*) FROM user_friends WHERE followee_id = u.supabase_id AND status = 'accepted') AS followers_count,
    (SELECT count(*) FROM user_friends WHERE follower_id = u.supabase_id AND status = 'accepted') AS following_count
  FROM user_friends f
  JOIN users u ON u.supabase_id = f.followee_id
  WHERE f.follower_id = p_user_id
    AND f.status = 'blocked'
  ORDER BY f.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_blocked_users(uuid)
    TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.search_users(p_query text, p_limit int DEFAULT 20)
RETURNS SETOF public.user_with_counts
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT
    u.name, u.email, u.created_at, u.supabase_id, u.bio,
    u.profile_image_url, u.phone_number, u.spice_tolerance,
    u.wizard_completed, u.username, u.fcm_token,
    u.fcm_token_updated_at, u.vibe_tag_affinity,
    u.dietary_requirement_tag_affinity,
    (SELECT count(*) FROM user_friends WHERE followee_id = u.supabase_id AND status = 'accepted') AS followers_count,
    (SELECT count(*) FROM user_friends WHERE follower_id = u.supabase_id AND status = 'accepted') AS following_count
  FROM users u
  WHERE u.name ILIKE '%' || p_query || '%'
     OR u.email ILIKE '%' || p_query || '%'
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.search_users(text, int)
    TO anon, authenticated, service_role;
