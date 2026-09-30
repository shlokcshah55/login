-- Baseline generated from production (umjoqvsfqhirysdjxnaf) on 2026-09-30 via
-- `supabase db dump --linked`, plus storage + pg_cron objects the dump omits.
-- Supersedes every earlier migration (archived in supabase/_archive/migrations/,
-- and in pinit-recommendations/supabase/_archive/). Do not edit — add new migrations.



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "public";






CREATE SCHEMA IF NOT EXISTS "rewards";


ALTER SCHEMA "rewards" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "cube" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "earthdistance" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."action_type" AS ENUM (
    'save',
    'like',
    'shared_video',
    'dislike',
    'bubble_save',
    'been_to'
);


ALTER TYPE "public"."action_type" OWNER TO "postgres";


CREATE TYPE "public"."relationship_status" AS ENUM (
    'requested',
    'accepted',
    'blocked',
    'pending'
);


ALTER TYPE "public"."relationship_status" OWNER TO "postgres";


CREATE TYPE "public"."saved_method" AS ENUM (
    'tiktok',
    'in-app',
    'instagram'
);


ALTER TYPE "public"."saved_method" OWNER TO "postgres";


CREATE TYPE "public"."tag_type" AS ENUM (
    'dietary_requirement',
    'vibe',
    'cuisine'
);


ALTER TYPE "public"."tag_type" OWNER TO "postgres";


CREATE TYPE "public"."user_with_counts" AS (
	"name" "text",
	"email" "text",
	"created_at" timestamp without time zone,
	"supabase_id" "uuid",
	"bio" "text",
	"profile_image_url" "text",
	"phone_number" "text",
	"spice_tolerance" smallint,
	"wizard_completed" boolean,
	"username" "text",
	"fcm_token" "text",
	"fcm_token_updated_at" timestamp with time zone,
	"vibe_tag_affinity" real[],
	"dietary_requirement_tag_affinity" real[],
	"followers_count" bigint,
	"following_count" bigint
);


ALTER TYPE "public"."user_with_counts" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."accept_friendship"("request_from_id" "uuid", "user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  UPDATE public.user_friends
  SET status = 'accepted'::relationship_status
  WHERE followee_id = accept_friendship.user_id
    AND follower_id = request_from_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Friend request not found';
  END IF;

  DELETE FROM public.notifications
  WHERE notifications.user_id = accept_friendship.user_id
    AND type = 'follow_request'
    AND (metadata ->> 'userId') = request_from_id::text;
END;
$$;


ALTER FUNCTION "public"."accept_friendship"("request_from_id" "uuid", "user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."acknowledge_location"("p_user_id" "uuid", "p_location_id" integer, "p_acked" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
     BEGIN
       UPDATE user_location_actions
       SET acked = p_acked
       WHERE user_id = p_user_id
         AND location_id = p_location_id;
     END;
     $$;


ALTER FUNCTION "public"."acknowledge_location"("p_user_id" "uuid", "p_location_id" integer, "p_acked" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_bubble_location"("p_bubble_id" "uuid", "p_location_id" bigint, "p_added_by" "uuid", "p_note" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.bubble_locations (
    bubble_id,
    location_id,
    added_by,
    note,
    added_at
  ) VALUES (
    p_bubble_id,
    p_location_id,
    p_added_by,
    p_note,
    NOW()
  )
  ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION "public"."add_bubble_location"("p_bubble_id" "uuid", "p_location_id" bigint, "p_added_by" "uuid", "p_note" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."add_bubble_location"("p_bubble_id" "uuid", "p_location_id" bigint, "p_added_by" "uuid", "p_note" "text") IS 'Add location to bubble. Bypasses RLS timing issues.';



CREATE OR REPLACE FUNCTION "public"."add_bubble_member"("p_bubble_id" "uuid", "p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$BEGIN
  INSERT INTO public.bubble_members (
    bubble_id,
    user_id,
    added_at
  ) VALUES (
    p_bubble_id,
    p_user_id,
    NOW()
  )
  ON CONFLICT DO NOTHING;
END;$$;


ALTER FUNCTION "public"."add_bubble_member"("p_bubble_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."add_bubble_member"("p_bubble_id" "uuid", "p_user_id" "uuid") IS 'Add member to bubble. Bypasses RLS timing issues.';



CREATE OR REPLACE FUNCTION "public"."add_location_to_collection"("p_collection_id" "uuid", "p_location_id" bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id   uuid;
    v_collection collections%ROWTYPE;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_collection
    FROM collections
    WHERE collection_id = p_collection_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Collection not found');
    END IF;

    -- Collections are read-only for non-owners.
    IF v_collection.created_by IS DISTINCT FROM v_user_id THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Permission denied: read-only collection');
    END IF;

    IF NOT v_collection.is_public AND v_collection.created_by != v_user_id THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Permission denied: collection is private');
    END IF;

    INSERT INTO collection_locations (collection_id, location_id, added_by, note)
    VALUES (p_collection_id, p_location_id, v_user_id, p_note);

    RETURN jsonb_build_object('success', TRUE);

EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object('success', TRUE, 'message', 'Location already in collection');
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid collection or location reference');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."add_location_to_collection"("p_collection_id" "uuid", "p_location_id" bigint, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_user_tags"("p_user_id" "uuid", "p_tag_ids" "uuid"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Insert multiple tags at once
  INSERT INTO public.user_tags (user_id, tag_id)
  SELECT p_user_id, unnest(p_tag_ids);
END;
$$;


ALTER FUNCTION "public"."add_user_tags"("p_user_id" "uuid", "p_tag_ids" "uuid"[]) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."add_user_tags"("p_user_id" "uuid", "p_tag_ids" "uuid"[]) IS 'Batch insert user tags during signup wizard. Bypasses RLS timing issues.';



CREATE OR REPLACE FUNCTION "public"."admin_delete_users"("p_user_ids" "uuid"[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
DECLARE
    v_deleted_profile_count integer := 0;
    v_deleted_auth_count integer := 0;
BEGIN
    -- Delete notifications tied to bubbles owned by these users
    DELETE FROM public.notifications n
    WHERE EXISTS (
        SELECT 1
        FROM public.bubbles b
        WHERE b.created_by = ANY(p_user_ids)
          AND (n.metadata ->> 'bubbleId') = b.bubble_id::text
    );

    -- Delete notifications referencing these users in metadata
    DELETE FROM public.notifications
    WHERE (metadata ->> 'userId')   = ANY(SELECT unnest(p_user_ids)::text)
       OR (metadata ->> 'inviterId') = ANY(SELECT unnest(p_user_ids)::text)
       OR (metadata ->> 'senderId')  = ANY(SELECT unnest(p_user_ids)::text);

    DELETE FROM public.collections
    WHERE created_by = ANY(p_user_ids);

    DELETE FROM public.bubbles
    WHERE created_by = ANY(p_user_ids);

    -- Null out reply references before deleting messages
    UPDATE public.messages
    SET replied_to_message_id = NULL
    WHERE replied_to_message_id IN (
        SELECT id FROM public.messages WHERE sender_id = ANY(p_user_ids)
    );

    DELETE FROM public.messages
    WHERE sender_id = ANY(p_user_ids);

    DELETE FROM public.bubble_locations
    WHERE added_by = ANY(p_user_ids);

    DELETE FROM public.collection_locations
    WHERE added_by = ANY(p_user_ids);

    DELETE FROM public.bubble_members
    WHERE user_id = ANY(p_user_ids);

    DELETE FROM public.location_reviews
    WHERE user_id = ANY(p_user_ids);

    DELETE FROM public.user_location_actions
    WHERE user_id = ANY(p_user_ids);

    DELETE FROM public.user_friends
    WHERE follower_id = ANY(p_user_ids)
       OR followee_id = ANY(p_user_ids);

    IF to_regclass('public.user_tag_affinities') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.user_tag_affinities WHERE user_id = ANY($1)'
        USING p_user_ids;
    END IF;

    DELETE FROM public.users
    WHERE supabase_id = ANY(p_user_ids);
    GET DIAGNOSTICS v_deleted_profile_count = ROW_COUNT;

    DELETE FROM auth.users
    WHERE id = ANY(p_user_ids);
    GET DIAGNOSTICS v_deleted_auth_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', TRUE,
        'profiles_deleted', v_deleted_profile_count,
        'auth_deleted', v_deleted_auth_count
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$_$;


ALTER FUNCTION "public"."admin_delete_users"("p_user_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."backfill_app_signal_pillars"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    rows_updated INTEGER := 0;
    loc RECORD;
BEGIN
    FOR loc IN
        SELECT
            l.location_id,
            l.rating,
            l.user_ratings_total,
            COALESCE(lp.saves_count, 0) AS saves_count,
            COALESCE(lp.dislikes_count, 0) AS dislikes_count,
            COALESCE(lp.been_to_count, 0) AS been_to_count
        FROM public.locations l
        LEFT JOIN public.location_popularity_app lp ON lp.location_id = l.location_id
    LOOP
        INSERT INTO public.location_popularity_app (
            location_id,
            saves_count, dislikes_count, been_to_count,
            app_engagement_score,
            google_baseline_score,
            video_insight_score
        )
        VALUES (
            loc.location_id,
            loc.saves_count, loc.dislikes_count, loc.been_to_count,
            compute_app_engagement_score(loc.saves_count, loc.dislikes_count, loc.been_to_count),
            compute_google_baseline_score(loc.rating, loc.user_ratings_total),
            compute_video_insight_score(loc.location_id)
        )
        ON CONFLICT (location_id) DO UPDATE SET
            app_engagement_score  = EXCLUDED.app_engagement_score,
            google_baseline_score = EXCLUDED.google_baseline_score,
            video_insight_score   = EXCLUDED.video_insight_score,
            updated_at            = NOW();

        PERFORM recompute_location_share_count(loc.location_id);
        rows_updated := rows_updated + 1;
    END LOOP;
    RETURN rows_updated;
END;
$$;


ALTER FUNCTION "public"."backfill_app_signal_pillars"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."backfill_locations_geog"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    updated INTEGER;
BEGIN
    WITH upd AS (
        UPDATE public.locations
        SET geog = ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
        WHERE geog IS NULL
          AND lat IS NOT NULL
          AND lng IS NOT NULL
        RETURNING 1
    )
    SELECT COUNT(*) INTO updated FROM upd;
    RETURN updated;
END;
$$;


ALTER FUNCTION "public"."backfill_locations_geog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."backfill_lpa_geog"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    updated INTEGER;
BEGIN
    WITH upd AS (
        UPDATE public.location_popularity_app lp
        SET geog = l.geog,
            updated_at = NOW()
        FROM public.locations l
        WHERE lp.location_id = l.location_id
          AND lp.geog IS DISTINCT FROM l.geog
          AND l.geog IS NOT NULL
        RETURNING 1
    )
    SELECT COUNT(*) INTO updated FROM upd;
    RETURN updated;
END;
$$;


ALTER FUNCTION "public"."backfill_lpa_geog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."block_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF p_blocker_id = p_blocked_id THEN
    RAISE EXCEPTION 'User cannot block themselves';
  END IF;

  DELETE FROM public.user_friends
  WHERE follower_id = p_blocked_id
    AND followee_id = p_blocker_id;

  INSERT INTO public.user_friends (
    follower_id,
    followee_id,
    status,
    created_at
  ) VALUES (
    p_blocker_id,
    p_blocked_id,
    'blocked'::relationship_status,
    NOW()
  )
  ON CONFLICT (followee_id, follower_id) DO UPDATE SET
    status = 'blocked'::relationship_status;

  DELETE FROM public.notifications
  WHERE notifications.user_id = p_blocker_id
    AND type = 'follow_request'
    AND (metadata ->> 'userId') = p_blocked_id::text;

  DELETE FROM public.notifications
  WHERE notifications.user_id = p_blocked_id
    AND type IN ('follow_request', 'follow_accepted')
    AND (metadata ->> 'userId') = p_blocker_id::text;
END;
$$;


ALTER FUNCTION "public"."block_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bubble_compatibility_score"("p_bubble_id" "uuid") RETURNS integer
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  WITH members AS (
    SELECT u.supabase_id, u.vibe_tag_affinity AS vibe
    FROM bubble_members bm
    JOIN users u ON u.supabase_id = bm.user_id
    WHERE bm.bubble_id = p_bubble_id
      AND u.vibe_tag_affinity IS NOT NULL
      AND array_length(u.vibe_tag_affinity, 1) > 0
  ),
  pairs AS (
    -- self-join to get every unique (i, j) pair
    SELECT a.vibe AS va, b.vibe AS vb
    FROM members a
    JOIN members b ON a.supabase_id < b.supabase_id
  ),
  scored AS (
    SELECT
      (SELECT sum(av * bv)
         FROM unnest(va, vb) AS t(av, bv)
        WHERE av IS NOT NULL AND bv IS NOT NULL
      )::float
      / NULLIF(
          sqrt((SELECT sum(av * av) FROM unnest(va) AS t(av))) *
          sqrt((SELECT sum(bv * bv) FROM unnest(vb) AS t(bv))),
          0
        ) AS cosine
    FROM pairs
  )
  SELECT CASE
    WHEN (SELECT count(*) FROM members) = 0 THEN NULL
    WHEN (SELECT count(*) FROM members) = 1 THEN 100
    ELSE round(avg(cosine) * 100)::integer
  END
  FROM scored
  WHERE cosine IS NOT NULL
$$;


ALTER FUNCTION "public"."bubble_compatibility_score"("p_bubble_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_interaction_weight"("p_user_id" "uuid") RETURNS numeric
    LANGUAGE "plpgsql" STABLE
    AS $$
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
$$;


ALTER FUNCTION "public"."calculate_interaction_weight"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."calculate_interaction_weight"("p_user_id" "uuid") IS 'Calculates interaction weight using inverse-log decay formula.
Returns a value between 0 and 1 that decreases as user interactions increase,
implementing diminishing returns to prevent over-specialization of tag preferences.';



CREATE OR REPLACE FUNCTION "public"."calculate_tag_affinity_delta"("p_current_affinity" numeric, "p_location_tag_score" integer, "p_value" integer, "p_weight" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
BEGIN
    -- Formula: delta = value * weight * ((locationAffinity - 50) / 50)
    -- This normalizes the location tag score to a -1 to +1 range:
    -- - Score 0 = -1.0 (strong negative signal)
    -- - Score 50 = 0.0 (neutral)
    -- - Score 100 = +1.0 (strong positive signal)

    RETURN p_value * p_weight * ((p_location_tag_score - 50.0) / 50.0);
END;
$$;


ALTER FUNCTION "public"."calculate_tag_affinity_delta"("p_current_affinity" numeric, "p_location_tag_score" integer, "p_value" integer, "p_weight" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."calculate_tag_affinity_delta"("p_current_affinity" numeric, "p_location_tag_score" integer, "p_value" integer, "p_weight" numeric) IS 'Calculates the delta change in tag affinity for a user interaction with a location.
Uses normalized location tag scores (-1 to +1) multiplied by action value and interaction weight.';



CREATE OR REPLACE FUNCTION "public"."centered_cosine_similarity"("vec1" integer[], "vec2" integer[]) RETURNS double precision
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
  mean1 FLOAT;
  mean2 FLOAT;
  centered1 FLOAT[];
  centered2 FLOAT[];
  dot_product FLOAT := 0.0;
  norm1 FLOAT := 0.0;
  norm2 FLOAT := 0.0;
  i INT;
  max_len INT;
BEGIN
  -- Handle null/empty vectors
  IF vec1 IS NULL OR vec2 IS NULL OR array_length(vec1, 1) IS NULL OR array_length(vec2, 1) IS NULL THEN
    RETURN 0.0;
  END IF;

  -- Get max length (handle dimension mismatch by padding with zeros conceptually)
  max_len := GREATEST(array_length(vec1, 1), array_length(vec2, 1));

  -- Calculate means
  mean1 := (SELECT AVG(v) FROM unnest(vec1) v);
  mean2 := (SELECT AVG(v) FROM unnest(vec2) v);

  -- Center vectors and compute dot product and norms
  FOR i IN 1..max_len LOOP
    DECLARE
      v1 FLOAT := COALESCE(vec1[i], 0)::FLOAT - mean1;
      v2 FLOAT := COALESCE(vec2[i], 0)::FLOAT - mean2;
    BEGIN
      dot_product := dot_product + (v1 * v2);
      norm1 := norm1 + (v1 * v1);
      norm2 := norm2 + (v2 * v2);
    END;
  END LOOP;

  -- Handle zero norm (uniform vectors) - return 0.0
  IF norm1 = 0 OR norm2 = 0 THEN
    RETURN 0.0;
  END IF;

  -- Compute centered cosine similarity
  DECLARE
    similarity FLOAT := dot_product / (SQRT(norm1) * SQRT(norm2));
  BEGIN
    -- Normalize from [-1, 1] to [0, 1]
    RETURN GREATEST(0.0, LEAST(1.0, (similarity + 1.0) / 2.0));
  END;
END;
$$;


ALTER FUNCTION "public"."centered_cosine_similarity"("vec1" integer[], "vec2" integer[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_location_processing"("p_location_id" integer, "p_request_id" "text", "p_cooldown_seconds" integer DEFAULT 2592000, "p_claim_stale_after_seconds" integer DEFAULT 300) RETURNS boolean
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  did_claim boolean := false;
begin
  update public.locations
  set
    location_processing_claim_id = p_request_id,
    location_processing_claimed_at = now()
  where location_id = p_location_id
    and (
      location_processing_queued_at is null
      or location_processing_queued_at <=
        now() - make_interval(secs => p_cooldown_seconds)
    )
    and (
      location_processing_claimed_at is null
      or location_processing_claimed_at <=
        now() - make_interval(secs => p_claim_stale_after_seconds)
    )
  returning true into did_claim;

  return coalesce(did_claim, false);
end;
$$;


ALTER FUNCTION "public"."claim_location_processing"("p_location_id" integer, "p_request_id" "text", "p_cooldown_seconds" integer, "p_claim_stale_after_seconds" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_location_vibe_processing"("p_location_id" integer, "p_request_id" "text", "p_stale_after_seconds" integer DEFAULT 900) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  did_claim boolean := false;
begin
  update public.locations
  set
    vibe_processing_request_id = p_request_id,
    vibe_processing_started_at = now()
  where location_id = p_location_id
    and coalesce(updated_vibe, false) = false
    and (
      vibe_processing_started_at is null
      or vibe_processing_started_at < now() - make_interval(secs => p_stale_after_seconds)
    )
  returning true into did_claim;

  return coalesce(did_claim, false);
end;
$$;


ALTER FUNCTION "public"."claim_location_vibe_processing"("p_location_id" integer, "p_request_id" "text", "p_stale_after_seconds" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_old_app_analytics_events"("p_retention" interval DEFAULT '7 days'::interval) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM public.app_analytics_events
    WHERE occurred_at < NOW() - p_retention;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_old_app_analytics_events"("p_retention" interval) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_location_processing_queue"("p_location_id" integer, "p_request_id" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  did_complete boolean := false;
begin
  update public.locations
  set
    location_processing_queued_at = now(),
    location_processing_claim_id = null,
    location_processing_claimed_at = null
  where location_id = p_location_id
    and location_processing_claim_id = p_request_id
  returning true into did_complete;

  return coalesce(did_complete, false);
end;
$$;


ALTER FUNCTION "public"."complete_location_processing_queue"("p_location_id" integer, "p_request_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_signup_wizard"("p_user_id" "uuid", "p_spice_tolerance" integer DEFAULT NULL::integer, "p_dietary_tag_ids" "uuid"[] DEFAULT NULL::"uuid"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_user_id      uuid := auth.uid();
  v_request_role      text := coalesce(current_setting('request.jwt.claim.role', true), '');
  v_dietary_affinity real[] := ARRAY[0, 0, 0, 0, 0, 0]::real[];
  v_tag_names        text[];
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  IF v_request_role <> 'service_role'
     AND v_auth_user_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Authenticated user does not match p_user_id';
  END IF;

  IF p_dietary_tag_ids IS NOT NULL AND array_length(p_dietary_tag_ids, 1) > 0 THEN
    SELECT array_agg(
             replace(lower(btrim(t.text)), ' ', '-')
           )
      INTO v_tag_names
      FROM public.tags t
      WHERE t.tag_id = ANY (p_dietary_tag_ids);

    IF v_tag_names IS NOT NULL THEN
      IF 'halal'       = ANY (v_tag_names) THEN v_dietary_affinity[1] := 100; END IF;
      IF 'vegan'       = ANY (v_tag_names) THEN v_dietary_affinity[2] := 100; END IF;
      IF 'gluten-free' = ANY (v_tag_names) THEN v_dietary_affinity[3] := 100; END IF;
      IF 'vegetarian'  = ANY (v_tag_names) THEN v_dietary_affinity[4] := 100; END IF;
      IF 'dairy-free'  = ANY (v_tag_names) THEN v_dietary_affinity[5] := 100; END IF;
      IF 'nut-free'    = ANY (v_tag_names) THEN v_dietary_affinity[6] := 100; END IF;
    END IF;

    RAISE NOTICE 'complete_signup_wizard: user=% tag_ids=% resolved_names=% affinity=%',
      p_user_id, p_dietary_tag_ids, v_tag_names, v_dietary_affinity;
  END IF;

  UPDATE public.users
  SET
    wizard_completed = true,
    spice_tolerance  = COALESCE(p_spice_tolerance, spice_tolerance),
    dietary_requirement_tag_affinity = CASE
      WHEN p_dietary_tag_ids IS NOT NULL
       AND array_length(p_dietary_tag_ids, 1) > 0
        THEN v_dietary_affinity
      ELSE dietary_requirement_tag_affinity
    END
  WHERE supabase_id = p_user_id;

  PERFORM rewards.accept_pending_referral_for_user(p_user_id);
END;
$$;


ALTER FUNCTION "public"."complete_signup_wizard"("p_user_id" "uuid", "p_spice_tolerance" integer, "p_dietary_tag_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_app_engagement_score"("p_saves_count" integer, "p_dislikes_count" integer, "p_been_to_count" integer) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    saves INTEGER := COALESCE(p_saves_count, 0);
    dislikes INTEGER := COALESCE(p_dislikes_count, 0);
    been_to INTEGER := COALESCE(p_been_to_count, 0);
    -- been_to is the strongest positive signal (user actually visited)
    weighted_positive NUMERIC := saves + 1.5 * been_to;
    volume_score NUMERIC;
    dislike_ratio NUMERIC;
BEGIN
    -- Log-saturated volume in [0, 1]; ~50 weighted positives → 0.85
    volume_score := LEAST(LN(1 + weighted_positive) / LN(75), 1.0);

    -- Penalise high-dislike places. Soft additive smoothing.
    IF (weighted_positive + dislikes) > 0 THEN
        dislike_ratio := dislikes::NUMERIC / (weighted_positive + dislikes + 1);
    ELSE
        dislike_ratio := 0.0;
    END IF;

    RETURN GREATEST(0.0, volume_score * (1.0 - dislike_ratio));
END;
$$;


ALTER FUNCTION "public"."compute_app_engagement_score"("p_saves_count" integer, "p_dislikes_count" integer, "p_been_to_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_google_baseline_score"("p_rating" double precision, "p_user_ratings_total" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    bayesian_rating NUMERIC;
    review_trust NUMERIC;
BEGIN
    -- Shrink towards 3.8 prior with 50 pseudo-reviews
    bayesian_rating := (COALESCE(p_rating, 3.8) * COALESCE(p_user_ratings_total, 0)
                        + 3.8 * 50)
                       / (COALESCE(p_user_ratings_total, 0) + 50);

    -- Log-power trust curve: ~500 reviews → 0.95
    review_trust := LEAST(
        0.95 * POWER(LN(1 + COALESCE(p_user_ratings_total, 0)) / LN(501), 0.6),
        1.0
    );

    -- Anti-mispricing cap so review volume can't overwhelm rating
    RETURN (bayesian_rating / 5.0)
           * LEAST(review_trust, 0.85 + 0.15 * (bayesian_rating / 5.0));
END;
$$;


ALTER FUNCTION "public"."compute_google_baseline_score"("p_rating" double precision, "p_user_ratings_total" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_location_quality_score"("p_location_id" bigint) RETURNS double precision
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  loc RECORD;
  bayesian_rating FLOAT;
  review_trust FLOAT;
  rating_score FLOAT;
  social_score FLOAT;
  feature_count INT;
  feature_score FLOAT;
BEGIN
  SELECT
    l.rating,
    l.user_ratings_total,
    l.saved_count,
    l.outdoor_seating,
    l.live_music,
    l.serves_cocktails,
    l.serves_brunch,
    l.serves_wine,
    l.serves_beer,
    l.good_for_groups,
    l.good_for_children,
    l.serves_vegetarian_food,
    l.serves_breakfast,
    l.serves_lunch,
    l.serves_dinner,
    l.serves_coffee,
    l.serves_dessert,
    l.good_for_watching_sports
  INTO loc
  FROM locations l
  WHERE l.location_id = p_location_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Bayesian rating: shrink towards 3.8 prior with 50 pseudo-reviews
  bayesian_rating := (COALESCE(loc.rating, 3.8) * COALESCE(loc.user_ratings_total, 0) + 3.8 * 50)
                     / (COALESCE(loc.user_ratings_total, 0) + 50);

  -- Review trust: log-power curve
  review_trust := LEAST(
    0.95 * POWER(LN(1 + COALESCE(loc.user_ratings_total, 0)) / LN(501), 0.6),
    1.0
  );

  -- Rating score
  rating_score := (bayesian_rating / 5.0) * review_trust;

  -- Social proof from saves
  social_score := LEAST(
    LN(1 + COALESCE(loc.saved_count, 0)) / LN(100),
    1.0
  );

  -- Feature richness
  feature_count := (
    COALESCE(loc.outdoor_seating, false)::INT +
    COALESCE(loc.live_music, false)::INT +
    COALESCE(loc.serves_cocktails, false)::INT +
    COALESCE(loc.serves_brunch, false)::INT +
    COALESCE(loc.serves_wine, false)::INT +
    COALESCE(loc.serves_beer, false)::INT +
    COALESCE(loc.good_for_groups, false)::INT +
    COALESCE(loc.good_for_children, false)::INT +
    COALESCE(loc.serves_vegetarian_food, false)::INT +
    COALESCE(loc.serves_breakfast, false)::INT +
    COALESCE(loc.serves_lunch, false)::INT +
    COALESCE(loc.serves_dinner, false)::INT +
    COALESCE(loc.serves_coffee, false)::INT +
    COALESCE(loc.serves_dessert, false)::INT +
    COALESCE(loc.good_for_watching_sports, false)::INT
  );
  feature_score := LEAST(feature_count / 8.0, 1.0);

  -- Final: 35% rating, 25% review trust, 25% social, 15% features
  RETURN LEAST(
    (0.35 * rating_score) +
    (0.25 * review_trust) +
    (0.25 * social_score) +
    (0.15 * feature_score),
    1.0
  );
END;
$$;


ALTER FUNCTION "public"."compute_location_quality_score"("p_location_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" numeric, "saved_count" smallint DEFAULT 0) RETURNS double precision
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
  bayesian_rating FLOAT;
  review_trust FLOAT;
  rating_score FLOAT;
  social_score FLOAT;
BEGIN
  -- Bayesian rating: shrink towards 3.8 prior with 50 pseudo-reviews
  bayesian_rating := (COALESCE(rating, 3.8) * COALESCE(user_ratings_total, 0) + 3.8 * 50)
                     / (COALESCE(user_ratings_total, 0) + 50);

  -- Review trust: log-power curve, punishes low reviews hard
  -- 0→0.0, 3→0.34, 10→0.52, 30→0.70, 100→0.83, 500→0.95
  review_trust := LEAST(
    0.95 * POWER(LN(1 + COALESCE(user_ratings_total, 0)) / LN(501), 0.6),
    1.0
  );

  -- Rating score: bayesian rating normalised to 0-1, scaled by review trust
  rating_score := (bayesian_rating / 5.0) * review_trust;

  -- Pinit social proof: log scale, ~100 saves maxes out
  social_score := LEAST(
    LN(1 + COALESCE(saved_count, 0)) / LN(100),
    1.0
  );

  -- Final score: 60% rating (includes trust), 40% social proof
  RETURN LEAST(
    (0.6 * rating_score) + (0.4 * social_score),
    1.0
  );
END;
$$;


ALTER FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" numeric, "saved_count" smallint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" integer, "saved_count" integer, "outdoor_seating" boolean, "live_music" boolean, "serves_cocktails" boolean, "serves_brunch" boolean, "serves_wine" boolean, "serves_beer" boolean, "good_for_groups" boolean, "good_for_children" boolean, "serves_vegetarian_food" boolean, "serves_breakfast" boolean, "serves_lunch" boolean, "serves_dinner" boolean, "serves_coffee" boolean, "serves_dessert" boolean, "good_for_watching_sports" boolean) RETURNS double precision
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
  bayesian_rating FLOAT;
  review_trust FLOAT;
  rating_score FLOAT;
  social_score FLOAT;
  feature_count INT;
  feature_score FLOAT;
BEGIN
  -- Bayesian rating: shrink towards 3.8 prior with 50 pseudo-reviews
  bayesian_rating := (COALESCE(rating, 3.8) * COALESCE(user_ratings_total, 0) + 3.8 * 50)
                     / (COALESCE(user_ratings_total, 0) + 50);

  -- Review trust: log-power curve, punishes low reviews hard
  -- 0→0.0, 3→0.34, 10→0.52, 30→0.70, 100→0.83, 500→0.95
  review_trust := LEAST(
    0.95 * POWER(LN(1 + COALESCE(user_ratings_total, 0)) / LN(501), 0.6),
    1.0
  );

  -- Rating score: bayesian rating normalised to 0-1, scaled by review trust
  rating_score := (bayesian_rating / 5.0) * review_trust;

  -- Pinit social proof: log scale, ~100 saves maxes out
  social_score := LEAST(
    LN(1 + COALESCE(saved_count, 0)) / LN(100),
    1.0
  );

  -- Feature richness: count of true boolean attributes, 8+ maxes out
  feature_count := (
    COALESCE(outdoor_seating, false)::INT +
    COALESCE(live_music, false)::INT +
    COALESCE(serves_cocktails, false)::INT +
    COALESCE(serves_brunch, false)::INT +
    COALESCE(serves_wine, false)::INT +
    COALESCE(serves_beer, false)::INT +
    COALESCE(good_for_groups, false)::INT +
    COALESCE(good_for_children, false)::INT +
    COALESCE(serves_vegetarian_food, false)::INT +
    COALESCE(serves_breakfast, false)::INT +
    COALESCE(serves_lunch, false)::INT +
    COALESCE(serves_dinner, false)::INT +
    COALESCE(serves_coffee, false)::INT +
    COALESCE(serves_dessert, false)::INT +
    COALESCE(good_for_watching_sports, false)::INT
  );
  feature_score := LEAST(feature_count / 8.0, 1.0);

  -- Final score: 35% rating, 25% review trust, 25% social, 15% features
  RETURN LEAST(
    (0.35 * rating_score) +
    (0.25 * review_trust) +
    (0.25 * social_score) +
    (0.15 * feature_score),
    1.0
  );
END;
$$;


ALTER FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" integer, "saved_count" integer, "outdoor_seating" boolean, "live_music" boolean, "serves_cocktails" boolean, "serves_brunch" boolean, "serves_wine" boolean, "serves_beer" boolean, "good_for_groups" boolean, "good_for_children" boolean, "serves_vegetarian_food" boolean, "serves_breakfast" boolean, "serves_lunch" boolean, "serves_dinner" boolean, "serves_coffee" boolean, "serves_dessert" boolean, "good_for_watching_sports" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_quality_score_v3"("p_rating" double precision, "p_user_ratings_total" numeric, "p_saved_count" smallint DEFAULT 0, "p_saves_count_app" integer DEFAULT 0, "p_dislikes_count_app" integer DEFAULT 0, "p_recent_reviews_90d" integer DEFAULT 0, "p_total_app_reviews" integer DEFAULT 0, "p_location_age_days" integer DEFAULT 365) RETURNS double precision
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$DECLARE
  bayesian_rating FLOAT;
  review_trust FLOAT;
  velocity_boost FLOAT;
  rating_score FLOAT;
  social_score FLOAT;
  saves_total INTEGER;
  cold_start_bonus FLOAT;
BEGIN
  -- Bayesian rating: shrink towards 3.8 prior with 50 pseudo-reviews
  bayesian_rating := (COALESCE(p_rating, 3.8) * COALESCE(p_user_ratings_total, 0) + 3.8 * 50)
                     / (COALESCE(p_user_ratings_total, 0) + 50);

  -- Review trust: log-power curve
  review_trust := LEAST(
    0.95 * POWER(LN(1 + COALESCE(p_user_ratings_total, 0)) / LN(501), 0.6),
    1.0
  );

  -- Review velocity boost: recent reviews indicate active/trending location
  IF COALESCE(p_total_app_reviews, 0) > 0 THEN
    velocity_boost := 1.0 + 0.3 * (COALESCE(p_recent_reviews_90d, 0)::FLOAT / (p_total_app_reviews + 1));
  ELSE
    velocity_boost := 1.0;
  END IF;
  review_trust := LEAST(review_trust * velocity_boost, 1.0);

  -- Anti-mispricing: cap trust so volume can't overwhelm quality
  -- A 3.5-star place with 5000 reviews can't outscore a 4.8-star with 100
  rating_score := (bayesian_rating / 5.0) * LEAST(review_trust, 0.85 + 0.15 * (bayesian_rating / 5.0));

  -- Social proof from in-app engagement (prefer app data over Google saved_count)
  saves_total := GREATEST(COALESCE(p_saves_count_app, 0), COALESCE(p_saved_count, 0)::INTEGER);
  social_score := LEAST(
    LN(1 + saves_total) / LN(100),
    1.0
  );
  -- Penalize locations with high dislike ratio
  IF (saves_total + COALESCE(p_dislikes_count_app, 0)) > 0 THEN
    social_score := social_score * (1.0 - COALESCE(p_dislikes_count_app, 0)::FLOAT / (saves_total + COALESCE(p_dislikes_count_app, 0) + 1));
  END IF;

  -- Cold-start discovery bonus: new locations get temporary visibility boost
  cold_start_bonus := 0.0;
  IF COALESCE(p_location_age_days, 365) < 30 AND COALESCE(p_total_app_reviews, 0) < 5 THEN
    cold_start_bonus := 0.1 * (1.0 - COALESCE(p_location_age_days, 30)::FLOAT / 30.0);
  END IF;

  RETURN LEAST(
    (0.6 * rating_score) + (0.4 * social_score) + cold_start_bonus,
    1.0
  );
END;$$;


ALTER FUNCTION "public"."compute_quality_score_v3"("p_rating" double precision, "p_user_ratings_total" numeric, "p_saved_count" smallint, "p_saves_count_app" integer, "p_dislikes_count_app" integer, "p_recent_reviews_90d" integer, "p_total_app_reviews" integer, "p_location_age_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_video_insight_score"("p_location_id" bigint) RETURNS numeric
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
    distinct_creators INTEGER;
    total_videos INTEGER;
    pos_videos INTEGER;
    neg_videos INTEGER;
    avg_age_days NUMERIC;
    volume_score NUMERIC;
    sentiment_factor NUMERIC;
    recency_factor NUMERIC;
BEGIN
    SELECT
        COUNT(DISTINCT NULLIF(creator_handle, '')),
        COUNT(*),
        COUNT(*) FILTER (WHERE sentiment IN ('positive', 'very_positive')),
        COUNT(*) FILTER (WHERE sentiment IN ('negative', 'very_negative')),
        COALESCE(AVG(EXTRACT(EPOCH FROM (NOW() - extracted_at)) / 86400.0), 180)
    INTO distinct_creators, total_videos, pos_videos, neg_videos, avg_age_days
    FROM public.video_insights
    WHERE location_id = p_location_id;

    IF COALESCE(total_videos, 0) = 0 THEN
        RETURN 0.0;
    END IF;

    -- Distinct creators dominate volume (3 creators → 0.7, 10 → ~1.0)
    volume_score := LEAST(LN(1 + COALESCE(distinct_creators, 0)) / LN(11), 1.0);

    -- Sentiment factor in [0.4, 1.2]: very negative drags down, positive lifts
    IF total_videos > 0 THEN
        sentiment_factor := 0.8
            + 0.4 * (pos_videos::NUMERIC / total_videos)
            - 0.4 * (neg_videos::NUMERIC / total_videos);
    ELSE
        sentiment_factor := 1.0;
    END IF;
    sentiment_factor := GREATEST(0.4, LEAST(sentiment_factor, 1.2));

    -- Recency: half-life 180 days
    recency_factor := EXP(-avg_age_days / 180.0);

    RETURN GREATEST(0.0, LEAST(volume_score * sentiment_factor * recency_factor, 1.0));
END;
$$;


ALTER FUNCTION "public"."compute_video_insight_score"("p_location_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_bubble_with_member"("p_name" "text", "p_created_by" "uuid", "p_is_private" boolean DEFAULT false) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_bubble_id UUID;
BEGIN
  -- Create the bubble
  INSERT INTO public.bubbles (
    name,
    created_by,
    is_private,
    created_at
  ) VALUES (
    p_name,
    p_created_by,
    p_is_private,
    NOW()
  )
  RETURNING bubble_id INTO v_bubble_id;

  -- Add creator as a member
  INSERT INTO public.bubble_members (
    bubble_id,
    user_id,
    added_at
  ) VALUES (
    v_bubble_id,
    p_created_by,
    NOW()
  );

  RETURN v_bubble_id;
END;
$$;


ALTER FUNCTION "public"."create_bubble_with_member"("p_name" "text", "p_created_by" "uuid", "p_is_private" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_bubble_with_member"("p_name" "text", "p_created_by" "uuid", "p_is_private" boolean) IS 'Create bubble and add creator as member. Bypasses RLS timing issues.';



CREATE OR REPLACE FUNCTION "public"."create_collection"("p_name" "text", "p_is_public" boolean DEFAULT true) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id         uuid;
    new_collection_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    INSERT INTO collections (name, created_by, is_public, created_at)
    VALUES (trim(p_name), v_user_id, p_is_public, now())
    RETURNING collection_id INTO new_collection_id;

    RETURN new_collection_id;
END;
$$;


ALTER FUNCTION "public"."create_collection"("p_name" "text", "p_is_public" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_collection_with_locations"("p_user_id" "uuid", "p_name" "text", "p_location_ids" bigint[], "p_description" "text" DEFAULT NULL::"text", "p_emoji" "text" DEFAULT NULL::"text", "p_cover_color" "text" DEFAULT NULL::"text", "p_is_public" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_collection_id uuid;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'p_user_id is required');
    END IF;

    IF p_name IS NULL OR trim(p_name) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Collection name is required');
    END IF;

    IF p_location_ids IS NULL OR array_length(p_location_ids, 1) IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'At least one location is required');
    END IF;

    INSERT INTO collections (name, description, emoji, cover_color, created_by, is_public)
    VALUES (trim(p_name), p_description, p_emoji, p_cover_color, p_user_id, p_is_public)
    RETURNING collection_id INTO v_collection_id;

    -- Bulk insert all locations in same transaction via unnest
    INSERT INTO collection_locations (collection_id, location_id, added_by)
    SELECT v_collection_id, unnest(p_location_ids), p_user_id
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object(
        'success',        true,
        'collection_id',  v_collection_id,
        'location_count', array_length(p_location_ids, 1)
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object('success', false, 'error', 'One or more location IDs are invalid');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."create_collection_with_locations"("p_user_id" "uuid", "p_name" "text", "p_location_ids" bigint[], "p_description" "text", "p_emoji" "text", "p_cover_color" "text", "p_is_public" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_friendship"("p_follower_id" "uuid", "p_followee_id" "uuid", "p_status" "text" DEFAULT 'requested'::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF p_follower_id = p_followee_id THEN
    RAISE EXCEPTION 'User cannot follow themselves';
  END IF;

  INSERT INTO public.user_friends (
    follower_id,
    followee_id,
    status,
    created_at
  ) VALUES (
    p_follower_id,
    p_followee_id,
    p_status::relationship_status,
    NOW()
  )
  ON CONFLICT (followee_id, follower_id) DO UPDATE SET
    status = EXCLUDED.status;
END;
$$;


ALTER FUNCTION "public"."create_friendship"("p_follower_id" "uuid", "p_followee_id" "uuid", "p_status" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_friendship"("p_follower_id" "uuid", "p_followee_id" "uuid", "p_status" "text") IS 'Create friendship/follow relationship. Bypasses RLS timing issues.';



CREATE OR REPLACE FUNCTION "public"."create_location_review"("p_location_id" bigint, "p_content" "text" DEFAULT NULL::"text", "p_rating" numeric DEFAULT NULL::numeric, "p_gatekeep" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
  v_review  public.location_reviews%ROWTYPE;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  INSERT INTO public.location_reviews (
    location_id,
    user_id,
    content,
    rating,
    private
  )
  VALUES (
    p_location_id,
    v_user_id,
    p_content,
    p_rating,
    p_gatekeep
  )
  RETURNING * INTO v_review;

  -- Record the been_to action (idempotent via ON CONFLICT UPDATE)
  PERFORM public.create_user_location_action(
    p_user_id      => v_user_id,
    p_location_id  => p_location_id,
    p_action       => 'been_to'
  );

  RETURN jsonb_build_object(
    'success', true,
    'id',      v_review.id
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."create_location_review"("p_location_id" bigint, "p_content" "text", "p_rating" numeric, "p_gatekeep" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_new_collection"("p_name" "text", "p_description" "text", "p_emoji" "text", "p_cover_color" "text", "p_user_id" "uuid", "p_is_public" boolean) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    new_collection_id uuid;
BEGIN
    INSERT INTO collections (name, description, emoji, cover_color, created_by, is_curated, is_public, created_at)
    VALUES (p_name, p_description, p_emoji, p_cover_color, p_user_id, true, p_is_public, now())
    RETURNING collection_id INTO new_collection_id;

    RETURN new_collection_id;
END;
$$;


ALTER FUNCTION "public"."create_new_collection"("p_name" "text", "p_description" "text", "p_emoji" "text", "p_cover_color" "text", "p_user_id" "uuid", "p_is_public" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_user_location_action"("p_user_id" "uuid", "p_location_id" bigint, "p_action" "text", "p_saved_method" "text" DEFAULT NULL::"text", "p_preference" "text" DEFAULT NULL::"text", "p_source_video_url" "text" DEFAULT NULL::"text", "p_acked" boolean DEFAULT false) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO public.user_location_actions (
    user_id,
    location_id,
    action,
    saved_method,
    preference,
    source_video_url,
    acked,
    created_at
  ) VALUES (
    p_user_id,
    p_location_id,
    p_action::action_type,           -- Cast to Enum
    p_saved_method::saved_method,   -- Cast to Enum
    p_preference::saved_method,     -- Cast to Enum
    p_source_video_url,
    p_acked,
    NOW()
  )
  -- The conflict target must match the UNIQUE constraint exactly
  ON CONFLICT (user_id, location_id, action) 
  DO UPDATE SET
    saved_method = EXCLUDED.saved_method,
    preference = EXCLUDED.preference,
    source_video_url = EXCLUDED.source_video_url,
    acked = EXCLUDED.acked,
    created_at = NOW();
END;
$$;


ALTER FUNCTION "public"."create_user_location_action"("p_user_id" "uuid", "p_location_id" bigint, "p_action" "text", "p_saved_method" "text", "p_preference" "text", "p_source_video_url" "text", "p_acked" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_user_location_action"("p_user_id" "uuid", "p_location_id" bigint, "p_action" "text", "p_saved_method" "text", "p_preference" "text", "p_source_video_url" "text", "p_acked" boolean) IS 'Create user location action (save/like/dislike). Bypasses RLS timing issues.';



CREATE OR REPLACE FUNCTION "public"."create_user_profile"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    INSERT INTO public.users (supabase_id, email, name, created_at, wizard_completed, username)
    VALUES (p_supabase_id, p_email, p_name, NOW(), false, p_username);

    INSERT INTO public.collections (name, created_by, is_public, is_curated)
    SELECT default_collection.name, p_supabase_id, true, false
    FROM (VALUES ('Been To'), ('Shared Finds')) AS default_collection(name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.collections existing_collection
        WHERE existing_collection.created_by = p_supabase_id
          AND existing_collection.name = default_collection.name
    );
END;
$$;


ALTER FUNCTION "public"."create_user_profile"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_user_recommendation"("p_user_id" "uuid", "p_location_id" bigint, "p_score" real, "p_reason" "jsonb" DEFAULT NULL::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.user_recommendations (
    user_id,
    location_id,
    score,
    reason,
    generated_at
  ) VALUES (
    p_user_id,
    p_location_id,
    p_score,
    p_reason,
    NOW()
  )
  ON CONFLICT (user_id, location_id) DO UPDATE SET
    score = EXCLUDED.score,
    reason = EXCLUDED.reason,
    generated_at = EXCLUDED.generated_at;
END;
$$;


ALTER FUNCTION "public"."create_user_recommendation"("p_user_id" "uuid", "p_location_id" bigint, "p_score" real, "p_reason" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_user_recommendation"("p_user_id" "uuid", "p_location_id" bigint, "p_score" real, "p_reason" "jsonb") IS 'Create/update user recommendation. Used by recommendation engine.';



CREATE OR REPLACE FUNCTION "public"."decrement_saves_count"("loc_id" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
  BEGIN
    -- Update the location_popularity_app table
    UPDATE location_popularity_app
    SET saves_count = GREATEST(saves_count - 1, 0), -- Prevent negative counts
        updated_at = NOW()
    WHERE location_id = loc_id;

    -- If no row exists yet, insert one with count 0
    IF NOT FOUND THEN
      INSERT INTO location_popularity_app (location_id, saves_count, likes_count, updated_at)
      VALUES (loc_id, 0, 0, NOW());
    END IF;
  END;
  $$;


ALTER FUNCTION "public"."decrement_saves_count"("loc_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_collection"("p_collection_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id    uuid;
    v_collection collections%ROWTYPE;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_collection
    FROM collections
    WHERE collection_id = p_collection_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Collection not found');
    END IF;

    IF v_collection.created_by <> v_user_id THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Permission denied');
    END IF;

    IF v_collection.name IN ('Been To', 'Shared Finds') THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Auto-generated collections cannot be deleted'
        );
    END IF;

    DELETE FROM collections WHERE collection_id = p_collection_id;

    RETURN jsonb_build_object('success', TRUE);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."delete_collection"("p_collection_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_my_account"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth', 'storage'
    AS $_$
DECLARE
    v_user_id uuid;
    v_deleted_profile_count integer := 0;
    v_deleted_auth_count integer := 0;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    DELETE FROM public.notifications n
    WHERE EXISTS (
        SELECT 1
        FROM public.bubbles b
        WHERE b.created_by = v_user_id
          AND (n.metadata ->> 'bubbleId') = b.bubble_id::text
    );

    DELETE FROM public.notifications
    WHERE (metadata ->> 'userId') = v_user_id::text
       OR (metadata ->> 'inviterId') = v_user_id::text
       OR (metadata ->> 'senderId') = v_user_id::text;

    -- TODO: Delete collection cover and profile photo assets through the
    -- Storage API before removing the user record. Direct deletion from
    -- storage.objects is not allowed in this RPC.

    DELETE FROM public.collections
    WHERE created_by = v_user_id;

    DELETE FROM public.bubbles
    WHERE created_by = v_user_id;

    UPDATE public.messages
    SET replied_to_message_id = NULL
    WHERE replied_to_message_id IN (
        SELECT id
        FROM public.messages
        WHERE sender_id = v_user_id
    );

    DELETE FROM public.messages
    WHERE sender_id = v_user_id;

    DELETE FROM public.bubble_locations
    WHERE added_by = v_user_id;

    DELETE FROM public.collection_locations
    WHERE added_by = v_user_id;

    DELETE FROM public.bubble_members
    WHERE user_id = v_user_id;

    DELETE FROM public.location_reviews
    WHERE user_id = v_user_id;

    DELETE FROM public.user_location_actions
    WHERE user_id = v_user_id;

    DELETE FROM public.user_friends
    WHERE follower_id = v_user_id
       OR followee_id = v_user_id;

    IF to_regclass('public.user_tag_affinities') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.user_tag_affinities WHERE user_id = $1'
        USING v_user_id;
    END IF;

    DELETE FROM public.users
    WHERE supabase_id = v_user_id;
    GET DIAGNOSTICS v_deleted_profile_count = ROW_COUNT;

    DELETE FROM auth.users
    WHERE id = v_user_id;
    GET DIAGNOSTICS v_deleted_auth_count = ROW_COUNT;

    IF v_deleted_auth_count = 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Authenticated user not found in auth.users'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'profile_deleted', v_deleted_profile_count > 0,
        'auth_deleted', TRUE
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$_$;


ALTER FUNCTION "public"."delete_my_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."dislike_location_with_tags"("p_user_id" "uuid", "p_location_id" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$DECLARE
    v_location_id INTEGER;
    v_action_exists BOOLEAN := FALSE;
    v_location_vibes REAL[];
    v_user_vibes REAL[];
    v_interaction_weight NUMERIC;
    v_top_k INTEGER := 2;
    v_top_k_indices INTEGER[];
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
    SELECT calculate_interaction_weight(p_user_id) INTO v_interaction_weight;

    SELECT vibe_vector INTO v_location_vibes FROM locations WHERE location_id = v_location_id;
    SELECT vibe_tag_affinity INTO v_user_vibes FROM users WHERE supabase_id = p_user_id;

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
                            v_user_vibes[i] + ((v_user_vibes[i] - v_location_vibes[i]) / 100.0) * 2.0 * v_interaction_weight
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
END;$$;


ALTER FUNCTION "public"."dislike_location_with_tags"("p_user_id" "uuid", "p_location_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_user_record_exists"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    INSERT INTO public.users (
        supabase_id,
        email,
        name,
        username,
        created_at,
        wizard_completed,
        vibe_tag_affinity,
        dietary_requirement_tag_affinity
    )
    VALUES (
        p_supabase_id,
        p_email,
        p_name,
        p_username,
        NOW(),
        false,
        ARRAY[50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 0, 50, 50, 50, 50],
        ARRAY[0, 0, 0, 0, 0, 0]
    )
    ON CONFLICT (supabase_id) DO NOTHING;

    INSERT INTO public.collections (name, created_by, is_public, is_curated)
    SELECT default_collection.name, p_supabase_id, true, false
    FROM (VALUES ('Been To'), ('Shared Finds')) AS default_collection(name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.collections existing_collection
        WHERE existing_collection.created_by = p_supabase_id
          AND existing_collection.name = default_collection.name
    );

    RETURN p_supabase_id;
END;
$$;


ALTER FUNCTION "public"."ensure_user_record_exists"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") RETURNS SETOF "public"."user_with_counts"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_bubble_activity"("p_bubble_id" "uuid") RETURNS TABLE("action_id" bigint, "location_id" bigint, "action" "text", "created_at" timestamp without time zone, "saved_method" "text", "preference" "text", "user_id" "uuid", "source_video_url" "text", "acked" boolean, "user_name" "text", "profile_image_url" "text", "location_name" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NOT EXISTS (
      SELECT 1 FROM bubble_members bm
      WHERE bm.bubble_id = p_bubble_id 
      AND bm.user_id = auth.uid()
  ) THEN
      RAISE EXCEPTION 'User not a member of this bubble';
  END IF;

  RETURN QUERY
  SELECT 
    ula.action_id,
    ula.location_id,
    ula.action::text,
    ula.created_at,
    ula.saved_method::text,
    ula.preference::text,
    ula.user_id,
    ula.source_video_url,
    ula.acked,
    u.name,
    u.profile_image_url,
    l.name
  FROM user_location_actions ula
  INNER JOIN bubble_members bm ON bm.user_id = ula.user_id
  INNER JOIN users u ON u.supabase_id = ula.user_id
  INNER JOIN locations l ON l.location_id = ula.location_id
  WHERE bm.bubble_id = p_bubble_id
  ORDER BY ula.created_at DESC
  LIMIT 10;
END;
$$;


ALTER FUNCTION "public"."get_bubble_activity"("p_bubble_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_bubble_member_ids_excluding_user"("p_bubble_id" "uuid", "p_excluded_user_id" "uuid") RETURNS TABLE("user_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT bm.user_id
    FROM public.bubble_members bm
    WHERE bm.bubble_id = p_bubble_id
      AND bm.user_id <> p_excluded_user_id;
END;
$$;


ALTER FUNCTION "public"."get_bubble_member_ids_excluding_user"("p_bubble_id" "uuid", "p_excluded_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_bubble_members"("p_bubble_id" "uuid") RETURNS TABLE("user_id" "uuid", "supabase_id" "uuid", "name" "text", "profile_image_url" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    bm.user_id,
    u.supabase_id,
    u.name,
    u.profile_image_url
  FROM public.bubble_members bm
  INNER JOIN public.users u
    ON u.supabase_id = bm.user_id
  WHERE bm.bubble_id = p_bubble_id
  ORDER BY bm.added_at ASC;
END;
$$;


ALTER FUNCTION "public"."get_bubble_members"("p_bubble_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_bubble_messages"("p_bubble_id" "uuid", "p_limit" integer DEFAULT 50, "p_before_timestamp" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS TABLE("id" "uuid", "sender_id" "uuid", "sender_name" "text", "sender_avatar_url" "text", "content" "text", "message_type" "text", "metadata" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "replied_to_message_id" "uuid", "location_id" bigint, "liked" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;

    RETURN QUERY
    SELECT
        m.id,
        m.sender_id,
        u.name as sender_name,
        u.profile_image_url as sender_avatar_url,
        m.content,
        m.message_type,
        m.metadata,
        m.created_at,
        m.updated_at,
        m.replied_to_message_id,
        m.location_id,
        m.liked
    FROM messages m
    JOIN users u ON m.sender_id = u.supabase_id
    WHERE m.bubble_id = p_bubble_id
    AND m.is_deleted = false
    AND (p_before_timestamp IS NULL OR m.created_at < p_before_timestamp)
    ORDER BY m.created_at DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_bubble_messages"("p_bubble_id" "uuid", "p_limit" integer, "p_before_timestamp" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_collections_by_ids"("p_collection_ids" "uuid"[], "p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("collection_id" "uuid", "name" "text", "emoji" "text", "cover_color" "text", "photo" "text", "curated_city" "text", "place_count" bigint, "owner_name" "text", "owner_avatar_url" "text", "is_public" boolean, "can_edit" boolean, "is_saved" boolean, "save_count" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    WITH save_counts AS (
        SELECT collection_id, COUNT(*)::bigint AS save_count
        FROM public.collection_saves
        GROUP BY collection_id
    )
    SELECT
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        c.curated_city,
        COUNT(cl.id)::bigint AS place_count,
        u.name               AS owner_name,
        u.profile_image_url  AS owner_avatar_url,
        c.is_public,
        FALSE                AS can_edit,
        (ucs.user_id IS NOT NULL) AS is_saved,
        COALESCE(sc.save_count, 0)::bigint AS save_count
    FROM public.collections c
    LEFT JOIN public.collection_locations cl
        ON cl.collection_id = c.collection_id
    LEFT JOIN public.users u
        ON u.supabase_id = c.created_by
    LEFT JOIN public.collection_saves ucs
        ON ucs.collection_id = c.collection_id
       AND ucs.user_id = p_user_id
    LEFT JOIN save_counts sc
        ON sc.collection_id = c.collection_id
    WHERE c.collection_id = ANY(p_collection_ids)
      AND c.is_public = TRUE
    GROUP BY
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        c.curated_city,
        u.name,
        u.profile_image_url,
        c.is_public,
        ucs.user_id,
        sc.save_count
    ORDER BY array_position(p_collection_ids, c.collection_id);
$$;


ALTER FUNCTION "public"."get_collections_by_ids"("p_collection_ids" "uuid"[], "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_curated_collections"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("collection_id" "uuid", "name" "text", "description" "text", "emoji" "text", "cover_color" "text", "photo" "text", "curated_city" "text", "place_count" bigint, "owner_name" "text", "owner_avatar_url" "text", "is_public" boolean, "can_edit" boolean, "is_saved" boolean, "save_count" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT
    c.collection_id,
    c.name,
    c.description,
    c.emoji,
    c.cover_color,
    c.photo,
    c.curated_city,
    COUNT(DISTINCT cl.location_id)                         AS place_count,
    NULL::text                                             AS owner_name,
    NULL::text                                             AS owner_avatar_url,
    c.is_public,
    false                                                  AS can_edit,
    CASE WHEN p_user_id IS NOT NULL
         THEN EXISTS (
           SELECT 1 FROM collection_saves cs
           WHERE cs.collection_id = c.collection_id
             AND cs.user_id = p_user_id
         )
         ELSE false
    END                                                    AS is_saved,
    (SELECT COUNT(*) FROM collection_saves cs2
     WHERE cs2.collection_id = c.collection_id)           AS save_count
  FROM collections c
  LEFT JOIN collection_locations cl ON cl.collection_id = c.collection_id
  WHERE c.is_curated = true
  GROUP BY c.collection_id
  ORDER BY c.curated_city NULLS LAST, c.name;
$$;


ALTER FUNCTION "public"."get_curated_collections"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_fill_locations"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer DEFAULT 1000) RETURNS TABLE("location_id" bigint, "name" "text", "vicinity" "text", "lat" numeric, "lng" numeric, "cuisine" "text", "cuisine_primary" "text", "rating" real, "user_ratings_total" numeric, "price_level" numeric, "google_place_id" "text", "types" "text", "emoji" "text", "vibe_vector" real[], "dietary_requirement_vector" integer[], "distance_km" double precision, "app_engagement_score" numeric, "google_baseline_score" numeric, "video_insight_score" numeric, "share_count" integer, "has_app_signal" boolean, "quality_bias" numeric)
    LANGUAGE "sql" STABLE
    AS $$
    WITH center AS (
        SELECT ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography AS g
    ),
    fill_candidates AS (
        SELECT
            l.location_id,
            l.name,
            l.vicinity,
            l.lat,
            l.lng,
            l.cuisine,
            l.cuisine_primary,
            l.rating,
            l.user_ratings_total,
            l.price_level,
            l.google_place_id,
            l.types,
            l.emoji,
            l.vibe_vector,
            l.dietary_requirement_vector,
            (ST_Distance(l.geog, center.g) / 1000.0)::FLOAT AS distance_km,
            0.0::NUMERIC AS app_engagement_score,
            compute_google_baseline_score(l.rating, l.user_ratings_total) AS google_baseline_score,
            0.0::NUMERIC AS video_insight_score,
            0::INTEGER AS share_count,
            FALSE AS has_app_signal,
            0.0::NUMERIC AS quality_bias,
            ROW_NUMBER() OVER (ORDER BY l.geog <-> center.g, l.location_id ASC) AS rn
        FROM public.locations l
        CROSS JOIN center
        WHERE l.geog IS NOT NULL
          AND ST_DWithin(l.geog, center.g, radius_meters)
          AND NOT EXISTS (
              SELECT 1
              FROM public.location_popularity_app lp
              WHERE lp.location_id = l.location_id
          )
        ORDER BY l.geog <-> center.g
        LIMIT result_limit
    )
    SELECT
        fc.location_id,
        fc.name,
        fc.vicinity,
        fc.lat,
        fc.lng,
        fc.cuisine,
        fc.cuisine_primary,
        fc.rating,
        fc.user_ratings_total,
        fc.price_level,
        fc.google_place_id,
        fc.types,
        fc.emoji,
        fc.vibe_vector,
        fc.dietary_requirement_vector,
        fc.distance_km,
        fc.app_engagement_score,
        fc.google_baseline_score,
        fc.video_insight_score,
        fc.share_count,
        fc.has_app_signal,
        fc.quality_bias
    FROM fill_candidates fc
    WHERE fc.rn <= result_limit
    ORDER BY fc.distance_km ASC, fc.location_id ASC;
$$;


ALTER FUNCTION "public"."get_fill_locations"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_followers"("p_user_id" "uuid") RETURNS SETOF "public"."user_with_counts"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_followers"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_following"("p_user_id" "uuid") RETURNS SETOF "public"."user_with_counts"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_following"("p_user_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."locations" (
    "location_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "vicinity" "text",
    "lat" numeric(9,6),
    "lng" numeric(9,6),
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "cuisine" "text",
    "rating" real,
    "user_ratings_total" numeric,
    "price_level" numeric,
    "photo_reference" "text",
    "saved_count" smallint,
    "google_place_id" "text",
    "business_status" "text",
    "editorial_summary" "text",
    "website" "text",
    "international_phone_number" "text",
    "types" "text",
    "opening_hours_text" "text"[],
    "opening_hours_periods" "jsonb",
    "open_now" boolean,
    "cuisine_detected" "text",
    "cuisine_source" "text",
    "cuisine_primary" "text",
    "is_open_late" boolean,
    "is_open_early" boolean,
    "is_sunday_open" boolean,
    "price_bucket" "text",
    "derived_attributes" "jsonb",
    "data_version" "text" DEFAULT 'v1'::"text" NOT NULL,
    "ingested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "photo_reference_valid_until" timestamp with time zone,
    "photo_reference_score" "text",
    "image_stored" boolean DEFAULT false,
    "emoji" "text",
    "updated_at" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text"),
    "google_maps_uri" "text",
    "photos" "jsonb",
    "reviews" "jsonb",
    "review_summary" "text",
    "good_for_children" boolean,
    "good_for_groups" boolean,
    "good_for_watching_sports" boolean,
    "live_music" boolean,
    "outdoor_seating" boolean,
    "serves_beer" boolean,
    "serves_breakfast" boolean,
    "serves_brunch" boolean,
    "serves_cocktails" boolean,
    "serves_coffee" boolean,
    "serves_dessert" boolean,
    "serves_dinner" boolean,
    "serves_lunch" boolean,
    "serves_vegetarian_food" boolean,
    "serves_wine" boolean,
    "menu" "text",
    "generated_summary" "text",
    "reccomended_dishes" "text",
    "menu_analysis_confidence" "text",
    "geog" "public"."geography"(Point,4326),
    "vibe_vector" real[],
    "updated_vibe" boolean DEFAULT false,
    "is_takeaway" boolean,
    "dietary_requirement_vector" integer[],
    "cuisine_scores_json" "jsonb",
    "photo_source" "text",
    "image_unavailable" boolean DEFAULT false NOT NULL,
    "extra_photos_stored" smallint DEFAULT 0 NOT NULL,
    "vibe_processing_request_id" "text",
    "vibe_processing_started_at" timestamp with time zone,
    "google_details_fetched_at" timestamp with time zone,
    "location_processing_queued_at" timestamp with time zone,
    "location_processing_claim_id" "text",
    "location_processing_claimed_at" timestamp with time zone
);


ALTER TABLE "public"."locations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."locations"."photo_reference_score" IS 'value from 1-5 that says how good the first image of the place is';



COMMENT ON COLUMN "public"."locations"."menu" IS 'Link to the menu';



COMMENT ON COLUMN "public"."locations"."vibe_vector" IS 'Order : ["cafe", "casual", "cozy", "coffee_shop", "bar",   "elegant", "fine_dining", "food_truck", "hole_in_the_wall", "late_night",     "live_music", "michelin_starred", "modern", "fast_food", "quiet",     "romantic", "sports_bar", "trendy", "takeout_friendly", "pub", "grocery_store", "brunch", "outdoor_dining", "wavy", "bossman"]';



COMMENT ON COLUMN "public"."locations"."dietary_requirement_vector" IS '"halal"     "vegan"     "gluten-free"     "vegetarian"     "dairy-free"     "nut-free"';



COMMENT ON COLUMN "public"."locations"."photo_source" IS 'Source of stored photo: og_image or google';



CREATE OR REPLACE FUNCTION "public"."get_hottest_shared_places"("p_limit" integer DEFAULT 10) RETURNS SETOF "public"."locations"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  return query
  select l.*
  from public.locations l
  join public.location_popularity_app lpa
    on l.location_id = lpa.location_id
  where exists (
    select 1
    from public.user_location_actions ula
    where ula.location_id = l.location_id
      and ula.action = 'save'
      and ula.source_video_url is not null
      and btrim(ula.source_video_url) <> ''
  )
  order by
    coalesce(lpa.app_engagement_score, 0.0) desc,
    coalesce(lpa.share_count, 0) desc,
    lpa.updated_at desc
  limit coalesce(p_limit, 10);
end;
$$;


ALTER FUNCTION "public"."get_hottest_shared_places"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_incoming_follow_requests"("p_user_id" "uuid") RETURNS SETOF "public"."user_with_counts"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_incoming_follow_requests"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_latest_shared_video_url"("p_location_id" bigint) RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT ula.source_video_url
    FROM public.user_location_actions ula
    WHERE ula.location_id = p_location_id
      AND ula.source_video_url IS NOT NULL
      AND btrim(ula.source_video_url) <> ''
    ORDER BY ula.created_at DESC
    LIMIT 1;
$$;


ALTER FUNCTION "public"."get_latest_shared_video_url"("p_location_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_location_collection_ids"("p_location_id" bigint) RETURNS TABLE("collection_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT cl.collection_id
  FROM public.collection_locations cl
  INNER JOIN public.collections c ON c.collection_id = cl.collection_id
  WHERE cl.location_id = p_location_id
    AND c.created_by = auth.uid();
END;
$$;


ALTER FUNCTION "public"."get_location_collection_ids"("p_location_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_locations_in_collection"("p_collection_id" "uuid") RETURNS SETOF "public"."locations"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
    SELECT l.*
    FROM collection_locations cl
    JOIN locations l ON l.location_id = cl.location_id
    WHERE cl.collection_id = p_collection_id
    ORDER BY cl.added_at ASC;
$$;


ALTER FUNCTION "public"."get_locations_in_collection"("p_collection_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_locations_with_pillars"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer DEFAULT 1000) RETURNS TABLE("location_id" bigint, "name" "text", "vicinity" "text", "lat" numeric, "lng" numeric, "cuisine" "text", "cuisine_primary" "text", "rating" real, "user_ratings_total" numeric, "price_level" numeric, "google_place_id" "text", "types" "text", "emoji" "text", "vibe_vector" real[], "dietary_requirement_vector" integer[], "distance_km" double precision, "app_engagement_score" numeric, "google_baseline_score" numeric, "video_insight_score" numeric, "share_count" integer, "has_app_signal" boolean, "quality_bias" numeric)
    LANGUAGE "sql" STABLE
    AS $$
    WITH center AS (
        SELECT ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography AS g
    ),
    primary_set AS (
        SELECT
            l.location_id,
            l.name,
            l.vicinity,
            l.lat,
            l.lng,
            l.cuisine,
            l.cuisine_primary,
            l.rating,
            l.user_ratings_total,
            l.price_level,
            l.google_place_id,
            l.types,
            l.emoji,
            l.vibe_vector,
            l.dietary_requirement_vector,
            (ST_Distance(lp.geog, center.g) / 1000.0)::FLOAT AS distance_km,
            COALESCE(lp.app_engagement_score, 0.0) AS app_engagement_score,
            COALESCE(
                lp.google_baseline_score,
                compute_google_baseline_score(l.rating, l.user_ratings_total)
            ) AS google_baseline_score,
            COALESCE(lp.video_insight_score, 0.0) AS video_insight_score,
            COALESCE(lp.share_count, 0) AS share_count,
            TRUE AS has_app_signal,
            COALESCE(lp.quality_score, 0.0) AS quality_bias
        FROM public.location_popularity_app lp
        INNER JOIN public.locations l ON l.location_id = lp.location_id
        CROSS JOIN center
        WHERE lp.geog IS NOT NULL
          AND ST_DWithin(lp.geog, center.g, radius_meters)
        ORDER BY lp.geog <-> center.g
        LIMIT result_limit
    ),
    primary_count AS (
        SELECT COUNT(*)::INT AS count FROM primary_set
    ),
    fill_candidates AS (
        SELECT
            l.location_id,
            l.name,
            l.vicinity,
            l.lat,
            l.lng,
            l.cuisine,
            l.cuisine_primary,
            l.rating,
            l.user_ratings_total,
            l.price_level,
            l.google_place_id,
            l.types,
            l.emoji,
            l.vibe_vector,
            l.dietary_requirement_vector,
            (ST_Distance(l.geog, center.g) / 1000.0)::FLOAT AS distance_km,
            0.0::NUMERIC AS app_engagement_score,
            compute_google_baseline_score(l.rating, l.user_ratings_total) AS google_baseline_score,
            0.0::NUMERIC AS video_insight_score,
            0::INTEGER AS share_count,
            FALSE AS has_app_signal,
            0.0::NUMERIC AS quality_bias
        FROM public.locations l
        CROSS JOIN center
        CROSS JOIN primary_count pc
        WHERE l.geog IS NOT NULL
          AND pc.count < result_limit
          AND ST_DWithin(l.geog, center.g, radius_meters)
          AND NOT EXISTS (
              SELECT 1
              FROM public.location_popularity_app lp
              WHERE lp.location_id = l.location_id
          )
        ORDER BY l.geog <-> center.g
        LIMIT result_limit
    ),
    fill_ranked AS (
        SELECT
            fc.*,
            ROW_NUMBER() OVER (ORDER BY fc.distance_km ASC, fc.location_id ASC) AS rn
        FROM fill_candidates fc
    ),
    fill_set AS (
        SELECT
            fr.location_id,
            fr.name,
            fr.vicinity,
            fr.lat,
            fr.lng,
            fr.cuisine,
            fr.cuisine_primary,
            fr.rating,
            fr.user_ratings_total,
            fr.price_level,
            fr.google_place_id,
            fr.types,
            fr.emoji,
            fr.vibe_vector,
            fr.dietary_requirement_vector,
            fr.distance_km,
            fr.app_engagement_score,
            fr.google_baseline_score,
            fr.video_insight_score,
            fr.share_count,
            fr.has_app_signal,
            fr.quality_bias
        FROM fill_ranked fr
        CROSS JOIN primary_count pc
        WHERE fr.rn <= GREATEST(result_limit - pc.count, 0)
    )
    SELECT *
    FROM (
        SELECT * FROM primary_set
        UNION ALL
        SELECT * FROM fill_set
    ) combined
    ORDER BY has_app_signal DESC, distance_km ASC;
$$;


ALTER FUNCTION "public"."get_locations_with_pillars"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_other_collections"("p_user_id" "uuid") RETURNS TABLE("collection_id" "uuid", "name" "text", "emoji" "text", "cover_color" "text", "photo" "text", "place_count" bigint, "owner_name" "text", "owner_avatar_url" "text", "is_public" boolean, "can_edit" boolean, "is_saved" boolean, "save_count" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    WITH friends AS (
        -- p_user_id is the follower, friend is the followee
        SELECT followee_id AS friend_id
        FROM public.user_friends
        WHERE follower_id = p_user_id
          AND status      = 'accepted'

        UNION

        -- p_user_id is the followee, friend is the follower
        SELECT follower_id AS friend_id
        FROM public.user_friends
        WHERE followee_id = p_user_id
          AND status      = 'accepted'
    ),
    save_counts AS (
        SELECT collection_id, COUNT(*)::bigint AS save_count
        FROM public.collection_saves
        GROUP BY collection_id
    )
    SELECT
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        COUNT(cl.id)::bigint AS place_count,
        u.name AS owner_name,
        u.profile_image_url AS owner_avatar_url,
        c.is_public,
        FALSE AS can_edit,
        (ucs.user_id IS NOT NULL) AS is_saved,
        COALESCE(sc.save_count, 0)::bigint AS save_count
    FROM friends f
    JOIN public.collections c
        ON c.created_by = f.friend_id
       AND c.is_public = TRUE
    LEFT JOIN public.collection_locations cl
        ON cl.collection_id = c.collection_id
    JOIN public.users u
        ON u.supabase_id = f.friend_id
    LEFT JOIN public.collection_saves ucs
        ON ucs.collection_id = c.collection_id
       AND ucs.user_id = p_user_id
    LEFT JOIN save_counts sc
        ON sc.collection_id = c.collection_id
    GROUP BY
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        u.name,
        u.profile_image_url,
        c.is_public,
        ucs.user_id,
        sc.save_count
    ORDER BY c.created_at DESC;
$$;


ALTER FUNCTION "public"."get_other_collections"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_popular_locations"("p_limit" integer) RETURNS TABLE("like" "public"."locations")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT l.*
    FROM locations l
    INNER JOIN location_popularity_app lpa ON l.location_id = lpa.location_id
    ORDER BY (lpa.saves_count - COALESCE(lpa.dislikes_count, 0)) DESC, lpa.updated_at DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_popular_locations"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_popular_locations"("p_limit" integer, "p_lat" double precision, "p_lng" double precision) RETURNS TABLE("like" "public"."locations")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    user_geog geography := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
BEGIN
    RETURN QUERY
    SELECT l.*
    FROM locations l
    INNER JOIN location_popularity_app lpa ON l.location_id = lpa.location_id
    ORDER BY
        -- Blend popularity score with proximity: higher popularity and closer distance both rank higher.
        -- Popularity score is normalised roughly to [0, ~1000]; distance in km is added as a penalty.
        (lpa.saves_count - COALESCE(lpa.dislikes_count, 0))
        - (ST_Distance(l.geog, user_geog) / 1000.0)  -- subtract distance_km as penalty
        DESC,
        lpa.updated_at DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_popular_locations"("p_limit" integer, "p_lat" double precision, "p_lng" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_ranked_proximal_recommendations"("p_supabase_id" "uuid", "center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "quality_weight" double precision DEFAULT 0.33, "vibe_weight" double precision DEFAULT 0.34, "dietary_weight" double precision DEFAULT 0.33, "result_limit" integer DEFAULT 1000) RETURNS TABLE("location_id" bigint, "name" "text", "vicinity" "text", "lat" numeric, "lng" numeric, "created_at" timestamp without time zone, "cuisine" "text", "rating" real, "user_ratings_total" numeric, "price_level" numeric, "photo_reference" "text", "saved_count" smallint, "google_place_id" "text", "business_status" "text", "editorial_summary" "text", "website" "text", "international_phone_number" "text", "types" "text", "opening_hours_text" "text"[], "opening_hours_periods" "jsonb", "open_now" boolean, "cuisine_detected" "text", "cuisine_source" "text", "cuisine_primary" "text", "review_language_counts_json" "jsonb", "is_open_late" boolean, "is_open_early" boolean, "is_sunday_open" boolean, "price_bucket" "text", "derived_attributes" "jsonb", "data_version" "text", "ingested_at" timestamp without time zone, "emoji" "text", "image_stored" boolean, "image_unavailable" boolean, "photos" "jsonb", "extra_photos_stored" smallint, "vibe_vector" integer[], "dietary_requirement_vector" integer[], "distance_km" double precision, "vibe_score" double precision, "dietary_score" double precision, "quality_score" double precision, "final_score" double precision, "rank" integer)
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  RETURN QUERY
  WITH user_data AS (
    -- Get user's vector affinities
    SELECT
      vibe_tag_affinity AS vibe_affinity_vector,
      dietary_requirement_tag_affinity AS dietary_requirement_affinity_vector
    FROM users
    WHERE supabase_id = p_supabase_id
  ),
  nearby_locations AS (
    -- Get ALL location columns within radius with distance
    SELECT
      l.*,  -- Select all location columns
      -- Calculate distance in kilometers
      ST_Distance(
        l.geog,
        ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography
      ) / 1000.0 AS distance_km
    FROM locations l
    WHERE ST_DWithin(
      l.geog,
      ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography,
      radius_meters
    )
  ),
  scored_locations AS (
    -- Compute all component scores
    SELECT
      nl.*,
      -- Vibe score using centered cosine similarity
      COALESCE(
        centered_cosine_similarity(
          u.vibe_affinity_vector,
          nl.vibe_vector
        ),
        0.0
      ) AS vibe_score,
      -- Dietary score using normalized dot product
      COALESCE(
        normalized_dot_product(
          u.dietary_requirement_affinity_vector,
          nl.dietary_requirement_vector
        ),
        0.0
      ) AS dietary_score,
      -- Quality score based on ratings and social proof
      compute_quality_score(
        nl.rating,
        nl.user_ratings_total,
        nl.saved_count
      ) AS quality_score
    FROM nearby_locations nl
    CROSS JOIN user_data u
  ),
  final_ranked AS (
    -- Calculate final weighted score and rank
    SELECT
      sl.*,
      (
        quality_weight * sl.quality_score +
        vibe_weight * sl.vibe_score +
        dietary_weight * sl.dietary_score
      ) AS final_score
    FROM scored_locations sl
    ORDER BY
      (
        quality_weight * sl.quality_score +
        vibe_weight * sl.vibe_score +
        dietary_weight * sl.dietary_score
      ) DESC,
      sl.distance_km ASC
    LIMIT result_limit
  )
  SELECT
    fr.location_id,
    fr.name,
    fr.vicinity,
    fr.lat,
    fr.lng,
    fr.created_at,
    fr.cuisine,
    fr.rating,
    fr.user_ratings_total,
    fr.price_level,
    fr.photo_reference,
    fr.saved_count,
    fr.google_place_id,
    fr.business_status,
    fr.editorial_summary,
    fr.website,
    fr.international_phone_number,
    fr.types,
    fr.opening_hours_text,
    fr.opening_hours_periods,
    fr.open_now,
    fr.cuisine_detected,
    fr.cuisine_source,
    fr.cuisine_primary,
    fr.review_language_counts_json,
    fr.is_open_late,
    fr.is_open_early,
    fr.is_sunday_open,
    fr.price_bucket,
    fr.derived_attributes,
    fr.data_version,
    fr.ingested_at,
    fr.emoji,
    fr.image_stored,
    fr.image_unavailable,
    fr.photos,
    fr.extra_photos_stored,
    fr.vibe_vector,
    fr.dietary_requirement_vector,
    fr.distance_km,
    fr.vibe_score,
    fr.dietary_score,
    fr.quality_score,
    fr.final_score,
    ROW_NUMBER() OVER (ORDER BY fr.final_score DESC, fr.distance_km ASC)::INT AS rank
  FROM final_ranked fr;
END;
$$;


ALTER FUNCTION "public"."get_ranked_proximal_recommendations"("p_supabase_id" "uuid", "center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "quality_weight" double precision, "vibe_weight" double precision, "dietary_weight" double precision, "result_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_saved_locations_not_in_collections"("p_user_id" "uuid", "p_collection_ids" "uuid"[]) RETURNS SETOF "public"."locations"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
    SELECT l.*
    FROM public.user_location_actions ula
    JOIN public.locations l ON l.location_id = ula.location_id
    WHERE ula.user_id = p_user_id
      AND ula.action IN ('save', 'bubble_save')
      AND NOT EXISTS (
          SELECT 1
          FROM public.collection_locations cl
          WHERE cl.location_id = ula.location_id
            AND cl.collection_id = ANY(p_collection_ids)
      )
    -- one row per location even if the user has saved it multiple times
    GROUP BY l.location_id;
$$;


ALTER FUNCTION "public"."get_saved_locations_not_in_collections"("p_user_id" "uuid", "p_collection_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shared_video_summaries"("p_location_ids" bigint[]) RETURNS TABLE("location_id" bigint, "social_video_count" integer, "social_video_url" "text", "social_video_creator_handle" "text", "tiktok_recommended_dish" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    WITH shared_urls AS (
        SELECT
            ula.location_id,
            btrim(ula.source_video_url) AS source_video_url,
            COUNT(*) AS share_count,
            MAX(ula.created_at) AS latest_shared_at
        FROM public.user_location_actions ula
        WHERE ula.location_id = ANY(p_location_ids)
          AND ula.source_video_url IS NOT NULL
          AND btrim(ula.source_video_url) <> ''
        GROUP BY ula.location_id, btrim(ula.source_video_url)
    ),
    ranked_urls AS (
        SELECT
            shared_urls.*,
            ROW_NUMBER() OVER (
                PARTITION BY shared_urls.location_id
                ORDER BY shared_urls.share_count DESC,
                         shared_urls.latest_shared_at DESC,
                         shared_urls.source_video_url ASC
            ) AS rn
        FROM shared_urls
    ),
    url_counts AS (
        SELECT
            shared_urls.location_id,
            COUNT(*)::integer AS social_video_count
        FROM shared_urls
        GROUP BY shared_urls.location_id
    ),
    dish_candidates AS (
        SELECT
            vi.location_id,
            NULLIF(btrim(dish.value ->> 'name'), '') AS dish_name,
            ROW_NUMBER() OVER (
                PARTITION BY vi.location_id
                ORDER BY vi.extracted_at DESC, vi.id
            ) AS rn
        FROM public.video_insights vi
        CROSS JOIN LATERAL jsonb_array_elements(
            COALESCE(vi.key_dishes, '[]'::jsonb)
        ) AS dish(value)
        WHERE vi.location_id = ANY(p_location_ids)
          AND NULLIF(btrim(dish.value ->> 'name'), '') IS NOT NULL
    )
    SELECT
        ranked_urls.location_id,
        url_counts.social_video_count,
        ranked_urls.source_video_url AS social_video_url,
        vi.creator_handle AS social_video_creator_handle,
        dish_candidates.dish_name AS tiktok_recommended_dish
    FROM ranked_urls
    INNER JOIN url_counts
        ON url_counts.location_id = ranked_urls.location_id
    LEFT JOIN public.video_insights vi
        ON vi.location_id = ranked_urls.location_id
       AND vi.source_video_url = ranked_urls.source_video_url
    LEFT JOIN dish_candidates
        ON dish_candidates.location_id = ranked_urls.location_id
       AND dish_candidates.rn = 1
    WHERE ranked_urls.rn = 1;
$$;


ALTER FUNCTION "public"."get_shared_video_summaries"("p_location_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_suggested_users"("p_supabase_id" "uuid", "p_limit" integer DEFAULT 10) RETURNS TABLE("supabase_id" "uuid", "name" "text", "email" "text", "profile_image_url" "text", "created_at" timestamp without time zone, "bio" "text", "spice_tolerance" integer, "wizard_completed" boolean, "username" "text", "vibe_tag_affinity" real[], "dietary_requirement_tag_affinity" integer[], "generated_collections" boolean, "followers_count" bigint, "following_count" bigint)
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  current_vibe real[];
BEGIN
  SELECT u.vibe_tag_affinity INTO current_vibe
  FROM users u
  WHERE u.supabase_id = p_supabase_id;

  RETURN QUERY
  WITH candidates AS (
    -- All users the current user has no relationship with yet
    SELECT u.*
    FROM users u
    WHERE u.supabase_id <> p_supabase_id
      AND NOT EXISTS (
        SELECT 1 FROM user_friends uf
        WHERE (uf.follower_id = p_supabase_id AND uf.followee_id = u.supabase_id)
           OR (uf.follower_id = u.supabase_id AND uf.followee_id = p_supabase_id)
      )
  ),
  scored AS (
    SELECT
      c.*,
      CASE
        WHEN current_vibe IS NULL
          OR c.vibe_tag_affinity IS NULL
          OR array_length(current_vibe, 1) IS NULL
          OR array_length(c.vibe_tag_affinity, 1) IS NULL
        THEN -1.0::double precision
        ELSE (
          SELECT
            CASE
              WHEN norm1 = 0 OR norm2 = 0 THEN 0.0
              ELSE GREATEST(0.0, LEAST(1.0,
                (dot / (SQRT(norm1) * SQRT(norm2)) + 1.0) / 2.0
              ))
            END
          FROM (
            SELECT
              SUM((a_v - a_mean) * (b_v - b_mean)) AS dot,
              SUM(POWER(a_v - a_mean, 2))           AS norm1,
              SUM(POWER(b_v - b_mean, 2))           AS norm2
            FROM (
              SELECT
                COALESCE(current_vibe[gs], 0)::float         AS a_v,
                COALESCE(c.vibe_tag_affinity[gs], 0)::float  AS b_v,
                (SELECT AVG(x::float) FROM unnest(current_vibe) x)            AS a_mean,
                (SELECT AVG(x::float) FROM unnest(c.vibe_tag_affinity) x)     AS b_mean
              FROM generate_series(
                1,
                GREATEST(
                  COALESCE(array_length(current_vibe, 1), 0),
                  COALESCE(array_length(c.vibe_tag_affinity, 1), 0)
                )
              ) gs
            ) elems
          ) agg
        )
      END AS vibe_similarity
    FROM candidates c
  )
  SELECT
    s.supabase_id,
    s.name,
    s.email,
    s.profile_image_url,
    s.created_at,
    s.bio,
    s.spice_tolerance::integer,
    s.wizard_completed,
    s.username,
    s.vibe_tag_affinity,
    CASE
      WHEN s.dietary_requirement_tag_affinity IS NULL THEN NULL::integer[]
      ELSE ARRAY(
        SELECT (x::integer)
        FROM unnest(s.dietary_requirement_tag_affinity) AS x
      )
    END AS dietary_requirement_tag_affinity,
    s.generated_collections IS NOT NULL AS generated_collections,
    (SELECT COUNT(*) FROM user_friends uf
     WHERE uf.followee_id = s.supabase_id
       AND uf.status = 'accepted')::bigint AS followers_count,
    (SELECT COUNT(*) FROM user_friends uf
     WHERE uf.follower_id = s.supabase_id
       AND uf.status = 'accepted')::bigint AS following_count
  FROM scored s
  ORDER BY s.vibe_similarity DESC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_suggested_users"("p_supabase_id" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_actions"("p_user_id" "uuid", "p_limit" integer DEFAULT 50) RETURNS TABLE("location_id" bigint, "action_type" "text", "created_at" timestamp without time zone, "name" "text", "bubble_name" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY

    -- Actions from user_location_actions
    SELECT
        l.location_id,
        ula.action::text,
        ula.created_at,
        l.name,
        ''
    FROM user_location_actions ula
    INNER JOIN locations l ON l.location_id = ula.location_id
    WHERE ula.user_id = p_user_id

    UNION ALL

    -- Bubble saves from bubble_locations
    SELECT
        l.location_id,
        'bubble_save',
        bl.added_at,
        l.name,
        b.name
    FROM bubble_locations bl
    INNER JOIN locations l ON l.location_id = bl.location_id
    INNER JOIN bubbles b ON b.bubble_id = bl.bubble_id
    WHERE b.created_by = p_user_id  -- adjust if bubble membership is used instead

    ORDER BY created_at DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_user_actions"("p_user_id" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_been_to_count"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT count(*)::integer
  FROM public.user_location_actions
  WHERE user_id = p_user_id
    AND action = 'been_to';
$$;


ALTER FUNCTION "public"."get_user_been_to_count"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_been_to_reviews"("p_user_id" "uuid") RETURNS TABLE("review_id" "uuid", "location_id" bigint, "location_name" "text", "image_url" "text", "rating" numeric, "content" "text", "private" boolean, "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT
    lr.id            AS review_id,
    lr.location_id,
    l.name           AS location_name,
    l.photo_reference AS image_url,
    lr.rating,
    lr.content,
    lr.private,
    lr.created_at
  FROM public.location_reviews lr
  JOIN public.locations l ON l.location_id = lr.location_id
  JOIN public.user_location_actions ula
    ON ula.user_id    = lr.user_id
   AND ula.location_id = lr.location_id
   AND ula.action      = 'been_to'
  WHERE lr.user_id = p_user_id
  ORDER BY lr.rating DESC;
$$;


ALTER FUNCTION "public"."get_user_been_to_reviews"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_chats"() RETURNS TABLE("bubble_id" "uuid", "bubble_name" "text", "last_message_at" timestamp with time zone, "unread_count" bigint, "last_message" "jsonb", "muted" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ubc.bubble_id,
        ubc.bubble_name,
        ubc.last_message_at,
        ubc.unread_count,
        ubc.last_message,
        ubc.muted
    FROM user_bubble_chats ubc
    WHERE ubc.user_id = auth.uid()
    ORDER BY ubc.last_message_at DESC NULLS LAST;
END;
$$;


ALTER FUNCTION "public"."get_user_chats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_collection_library"("p_user_id" "uuid") RETURNS TABLE("collection_id" "uuid", "name" "text", "emoji" "text", "cover_color" "text", "photo" "text", "place_count" bigint, "is_public" boolean, "owner_name" "text", "owner_avatar_url" "text", "can_edit" boolean, "is_saved" boolean, "save_count" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    WITH save_counts AS (
        SELECT collection_id, COUNT(*)::bigint AS save_count
        FROM public.collection_saves
        GROUP BY collection_id
    )
    SELECT
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        COUNT(cl.id)::bigint AS place_count,
        c.is_public,
        NULL::text AS owner_name,
        NULL::text AS owner_avatar_url,
        TRUE AS can_edit,
        FALSE AS is_saved,
        COALESCE(sc.save_count, 0)::bigint AS save_count
    FROM public.collections c
    LEFT JOIN public.collection_locations cl ON cl.collection_id = c.collection_id
    LEFT JOIN save_counts sc ON sc.collection_id = c.collection_id
    WHERE c.created_by = p_user_id
    GROUP BY c.collection_id, c.name, c.emoji, c.cover_color, c.photo, c.is_public, sc.save_count

    UNION ALL

    SELECT
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        COUNT(cl.id)::bigint AS place_count,
        c.is_public,
        u.name AS owner_name,
        u.profile_image_url AS owner_avatar_url,
        FALSE AS can_edit,
        TRUE AS is_saved,
        COALESCE(sc.save_count, 0)::bigint AS save_count
    FROM public.collection_saves cs
    JOIN public.collections c
        ON c.collection_id = cs.collection_id
       AND c.is_public = TRUE
    LEFT JOIN public.collection_locations cl ON cl.collection_id = c.collection_id
    JOIN public.users u ON u.supabase_id = c.created_by
    LEFT JOIN save_counts sc ON sc.collection_id = c.collection_id
    WHERE cs.user_id = p_user_id
      AND c.created_by IS DISTINCT FROM p_user_id
    GROUP BY c.collection_id, c.name, c.emoji, c.cover_color, c.photo, c.is_public, u.name, u.profile_image_url, sc.save_count;
$$;


ALTER FUNCTION "public"."get_user_collection_library"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_collections"("p_user_id" "uuid") RETURNS TABLE("collection_id" "uuid", "name" "text", "emoji" "text", "cover_color" "text", "photo" "text", "place_count" bigint, "is_public" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        COUNT(cl.id)::bigint AS place_count,
        c.is_public
    FROM collections c
    LEFT JOIN collection_locations cl ON cl.collection_id = c.collection_id
    WHERE c.created_by = p_user_id
    GROUP BY c.collection_id, c.name, c.emoji, c.cover_color, c.photo, c.is_public
    ORDER BY c.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_user_collections"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_public_collections"("p_user_id" "uuid") RETURNS TABLE("collection_id" "uuid", "name" "text", "emoji" "text", "cover_color" "text", "photo" "text", "place_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.collection_id,
        c.name,
        c.emoji,
        c.cover_color,
        c.photo,
        COUNT(cl.id)::bigint AS place_count
    FROM collections c
    LEFT JOIN collection_locations cl ON cl.collection_id = c.collection_id
    WHERE c.created_by = p_user_id
      AND c.is_public  = TRUE
    GROUP BY c.collection_id, c.name, c.emoji, c.cover_color, c.photo
    ORDER BY c.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_user_public_collections"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_tag_scores"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(jsonb_build_object(
            'tag_id', tag_id,
            'affinity', affinity
        )),
        '[]'::jsonb
    ) INTO v_result
    FROM user_tag_affinities
    WHERE user_id = p_user_id;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_user_tag_scores"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_top_vibes"("p_user_id" "uuid") RETURNS TABLE("tag" "text", "score" double precision)
    LANGUAGE "plpgsql"
    AS $$
declare
  readable_tags text[] := ARRAY[
    'Cafe', 'Casual', 'Cozy', 'Coffee shop', 'Bar', 'Elegant',
    'Fine dining', 'Food truck', 'Hole in the wall', 'Late night',
    'Live music', 'Bougie', 'Modern', 'Fast food', 'Quiet',
    'Romantic', 'Sports bar', 'Trendy', 'Takeout friendly', 'Pub',
    'Shop', 'Brunch', 'Outdoor dining', 'Wavy', 'Bossman'
  ];

  readable_diet_tags text[] := ARRAY[
    'Halal', 'Vegan', 'Gluten free', 'Vegetarian', 'Dairy free', 'Nut free'
  ];

  scores float8[];
  dietary_scores float8[];
begin
  -- Pull the vibe affinity array
  select vibe_tag_affinity
  into scores
  from users
  where supabase_id = p_user_id;

  -- Pull dietary affinity array
  select dietary_requirement_tag_affinity
  into dietary_scores
  from users
  where supabase_id = p_user_id;

  -- Return top 3 vibe tags
  return query
    select t.tag, t.score
    from unnest(readable_tags, scores) as t(tag, score)
    order by t.score desc
    limit 3;

  -- Return dietary tags with score > 50
  return query
    select d.tag, d.score
    from unnest(readable_diet_tags, dietary_scores) as d(tag, score)
    where d.score > 50;

end;
$$;


ALTER FUNCTION "public"."get_user_top_vibes"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_dislikes_count"("loc_id" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$BEGIN
    -- Update the location_popularity_app table
    UPDATE location_popularity_app
    SET dislikes_count = dislikes_count + 1,
        updated_at = NOW()
    WHERE location_id = loc_id;

    -- If no row exists yet, insert one
    IF NOT FOUND THEN
      INSERT INTO location_popularity_app (location_id, saves_count, dislikes_count, updated_at)
      VALUES (loc_id, 0, 1, NOW());
    END IF;
  END;$$;


ALTER FUNCTION "public"."increment_dislikes_count"("loc_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_saves_count"("loc_id" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$BEGIN
    -- Update the location_popularity_app table
    UPDATE location_popularity_app
    SET saves_count = saves_count + 1,
        updated_at = NOW()
    WHERE location_id = loc_id;

    -- If no row exists yet, insert one
    IF NOT FOUND THEN
      INSERT INTO location_popularity_app (location_id, saves_count, dislikes_count, updated_at)
      VALUES (loc_id, 1, 0, NOW());
    END IF;
  END;$$;


ALTER FUNCTION "public"."increment_saves_count"("loc_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."initialize_bubble_chat"("p_bubble_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Verify user is a bubble member
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;
    
    -- Create chat state if doesn't exist
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id) DO NOTHING;
END;
$$;


ALTER FUNCTION "public"."initialize_bubble_chat"("p_bubble_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."initialize_chat_state_for_new_member"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Initialize chat state for new member
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (NEW.user_id, NEW.bubble_id, NOW())
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."initialize_chat_state_for_new_member"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."initialize_vibe_tags_for_user"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    UPDATE users
    SET vibe_tag_affinity = ARRAY[50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 0, 50, 50, 50, 50]
    WHERE supabase_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."initialize_vibe_tags_for_user"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."leave_bubble"("p_bubble_id" "uuid", "p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  BEGIN
    DELETE FROM bubble_members
    WHERE bubble_id = p_bubble_id
      AND user_id = p_user_id;
  END;
  $$;


ALTER FUNCTION "public"."leave_bubble"("p_bubble_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."locations_within_radius"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "max_results" integer DEFAULT 10000) RETURNS TABLE("location_id" bigint, "name" "text", "vicinity" "text", "lat" numeric, "lng" numeric, "cuisine_primary" "text", "rating" real, "user_ratings_total" numeric, "price_level" numeric, "google_place_id" "text", "distance_km" double precision)
    LANGUAGE "plpgsql" STABLE
    AS $$
  BEGIN
      RETURN QUERY
      SELECT
          l.location_id,
          l.name,
          l.vicinity,
          l.lat,
          l.lng,
          l.cuisine_primary,
          l.rating,
          l.user_ratings_total,
          l.price_level,
          l.google_place_id,
          ST_Distance(l.geog, ST_MakePoint(center_lng, center_lat)::geography) / 1000.0 AS distance_km
      FROM locations l
      WHERE ST_DWithin(
          l.geog,
          ST_MakePoint(center_lng, center_lat)::geography,
          radius_meters
      )
      ORDER BY l.geog <-> ST_MakePoint(center_lng, center_lat)::geography  -- Use index for ordering
      LIMIT max_results;
  END;
  $$;


ALTER FUNCTION "public"."locations_within_radius"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "max_results" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_bubble_read"("p_bubble_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Verify user is a bubble member
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;
    
    -- Update last_read_at
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id) 
    DO UPDATE SET last_read_at = NOW();
END;
$$;


ALTER FUNCTION "public"."mark_bubble_read"("p_bubble_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_location_extra_photos_stored"("p_location_id" bigint, "p_count" smallint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.locations
  SET extra_photos_stored = GREATEST(extra_photos_stored, p_count)
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."mark_location_extra_photos_stored"("p_location_id" bigint, "p_count" smallint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_location_image_unavailable"("p_location_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE locations
  SET image_unavailable = true
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."mark_location_image_unavailable"("p_location_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_location_image_uploaded"("p_location_id" bigint, "p_photos" "jsonb", "p_photo_reference" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.locations
  SET
    image_stored       = true,
    image_unavailable  = false,
    photos             = COALESCE(p_photos, photos),
    photo_reference    = COALESCE(p_photo_reference, photo_reference)
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."mark_location_image_uploaded"("p_location_id" bigint, "p_photos" "jsonb", "p_photo_reference" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalized_dot_product"("vec1" integer[], "vec2" integer[]) RETURNS double precision
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
  dot_prod FLOAT := 0.0;
  max_len INT;
  max_possible FLOAT;
  i INT;
BEGIN
  -- Handle null/empty vectors
  IF vec1 IS NULL OR vec2 IS NULL OR array_length(vec1, 1) IS NULL OR array_length(vec2, 1) IS NULL THEN
    RETURN 0.0;
  END IF;

  -- Get max length
  max_len := GREATEST(array_length(vec1, 1), array_length(vec2, 1));

  -- Compute dot product
  FOR i IN 1..max_len LOOP
    dot_prod := dot_prod + (COALESCE(vec1[i], 0)::FLOAT * COALESCE(vec2[i], 0)::FLOAT);
  END LOOP;

  -- Normalize to [0, 1] assuming values are in 0-100 range
  max_possible := max_len * 100.0 * 100.0;

  IF max_possible = 0 THEN
    RETURN 0.0;
  END IF;

  RETURN GREATEST(0.0, LEAST(1.0, dot_prod / max_possible));
END;
$$;


ALTER FUNCTION "public"."normalized_dot_product"("vec1" integer[], "vec2" integer[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_new_message"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Notify via pg_notify for real-time subscriptions
    PERFORM pg_notify(
        'new_message',
        json_build_object(
            'bubble_id', NEW.bubble_id,
            'message_id', NEW.id,
            'sender_id', NEW.sender_id,
            'message_type', NEW.message_type,
            'content', NEW.content
        )::text
    );
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_new_message"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_no_recommendations_in_area_internal"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_enabled BOOLEAN;
    v_api_url TEXT;
    v_api_key TEXT;
    v_title TEXT;
    v_body TEXT;
    v_meta JSONB;
    r RECORD;
BEGIN
    IF NEW.event_name IS NULL OR NEW.event_name <> 'no_recommendations_in_area_shown' THEN
        RETURN NEW;
    END IF;

    SELECT enabled, push_api_url, push_api_key
    INTO v_enabled, v_api_url, v_api_key
    FROM public.internal_alert_config
    WHERE id = 1;

    IF COALESCE(v_enabled, FALSE) IS FALSE THEN
        RETURN NEW;
    END IF;

    IF v_api_url IS NULL OR TRIM(v_api_url) = '' OR v_api_key IS NULL OR TRIM(v_api_key) = '' THEN
        RETURN NEW;
    END IF;

    v_title := 'Out of area search';
    v_body := 'A user hit "Sorry, we haven''t landed in your area yet".';
    v_meta := COALESCE(NEW.properties, '{}'::jsonb);

    FOR r IN
        SELECT u.supabase_id AS user_id, u.fcm_token AS fcm_token
        FROM public.internal_alert_recipients recipients
        JOIN public.users u ON u.supabase_id = recipients.user_id
        WHERE recipients.enabled = TRUE
          AND u.fcm_token IS NOT NULL
          AND TRIM(u.fcm_token) <> ''
    LOOP
        PERFORM net.http_post(
            url := v_api_url,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_api_key
            ),
            body := jsonb_build_object(
                'fcm_token', r.fcm_token,
                'user_id', r.user_id,
                -- Reuse an existing app notification type that requires no deep-link.
                'type', 'notes_import_complete',
                'title', v_title,
                'body', v_body,
                'metadata', jsonb_build_object(
                    'sourceEvent', NEW.event_name,
                    'occurredAt', NEW.occurred_at,
                    'properties', v_meta
                )
            )
        );
    END LOOP;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Never fail app analytics ingestion because alerting is misconfigured.
        RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_no_recommendations_in_area_internal"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."photos_name_array"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
  arr jsonb;
BEGIN
  IF p IS NULL THEN
    RETURN NULL;
  END IF;

  IF jsonb_typeof(p) = 'array' THEN
    arr := p;
  ELSIF jsonb_typeof(p) = 'string' THEN
    -- #>> '{}' unwraps the jsonb string to raw text; cast back to jsonb
    -- parses it. Swallow parse errors so one bad row can't poison a batch.
    BEGIN
      arr := (p #>> '{}')::jsonb;
    EXCEPTION WHEN others THEN
      RETURN NULL;
    END;
    IF arr IS NULL OR jsonb_typeof(arr) <> 'array' THEN
      RETURN NULL;
    END IF;
  ELSE
    RETURN NULL;
  END IF;

  RETURN (
    SELECT jsonb_agg(jsonb_build_object('name', elem->>'name'))
    FROM jsonb_array_elements(arr) AS elem
    WHERE elem ? 'name'
  );
END;
$$;


ALTER FUNCTION "public"."photos_name_array"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recompute_location_share_count"("p_location_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    total INTEGER;
BEGIN
    SELECT COUNT(*) INTO total
    FROM public.user_location_actions
    WHERE location_id = p_location_id
      AND action = 'save'
      AND saved_method IN ('tiktok', 'instagram');

    INSERT INTO public.location_popularity_app (location_id, share_count)
    VALUES (p_location_id, COALESCE(total, 0))
    ON CONFLICT (location_id) DO UPDATE
        SET share_count = EXCLUDED.share_count,
            updated_at = NOW();
END;
$$;


ALTER FUNCTION "public"."recompute_location_share_count"("p_location_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_location_quality_scores"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    affected INTEGER;
BEGIN
    WITH action_stats AS (
        SELECT
            location_id,
            COUNT(*) FILTER (WHERE action = 'save')              AS saves_count,
            COUNT(*) FILTER (WHERE action = 'been_to')           AS been_to_count,
            COUNT(*) FILTER (WHERE action = 'dislike')           AS dislikes_count,
            -- share_count = social-media saves only (matches v4 trigger logic)
            COUNT(*) FILTER (
                WHERE action = 'save'
                  AND saved_method IN ('tiktok', 'instagram')
            )                                                     AS share_count
        FROM public.user_location_actions
        GROUP BY location_id
    ),
    targets AS (
        -- Anything with engagement, OR already in LPA (manual biases etc.)
        SELECT location_id FROM action_stats
        UNION
        SELECT location_id FROM public.location_popularity_app
    )
    INSERT INTO public.location_popularity_app AS lp (
        location_id,
        saves_count,
        dislikes_count,
        been_to_count,
        share_count,
        app_engagement_score,
        google_baseline_score,
        video_insight_score,
        updated_at
    )
    SELECT
        t.location_id,
        COALESCE(a.saves_count,    0)::INTEGER,
        COALESCE(a.dislikes_count, 0)::INTEGER,
        COALESCE(a.been_to_count,  0)::INTEGER,
        COALESCE(a.share_count,    0)::INTEGER,
        compute_app_engagement_score(
            COALESCE(a.saves_count,    0)::INTEGER,
            COALESCE(a.dislikes_count, 0)::INTEGER,
            COALESCE(a.been_to_count,  0)::INTEGER
        ),
        compute_google_baseline_score(l.rating, l.user_ratings_total),
        compute_video_insight_score(t.location_id),
        NOW()
    FROM targets t
    INNER JOIN public.locations l       ON l.location_id = t.location_id
    LEFT JOIN  action_stats     a       ON a.location_id = t.location_id
    ON CONFLICT (location_id) DO UPDATE SET
        saves_count            = EXCLUDED.saves_count,
        dislikes_count         = EXCLUDED.dislikes_count,
        been_to_count          = EXCLUDED.been_to_count,
        share_count            = EXCLUDED.share_count,
        app_engagement_score   = EXCLUDED.app_engagement_score,
        google_baseline_score  = EXCLUDED.google_baseline_score,
        video_insight_score    = EXCLUDED.video_insight_score,
        updated_at             = NOW()
        -- NOTE: quality_score is intentionally NOT in the SET list. The
        -- manual bias is preserved across cron runs.
    ;

    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;


ALTER FUNCTION "public"."refresh_location_quality_scores"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reject_friendship"("request_from_id" "uuid", "user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  DELETE FROM public.user_friends
  WHERE followee_id = reject_friendship.user_id
    AND follower_id = request_from_id
    AND status = 'requested'::relationship_status;

  DELETE FROM public.notifications
  WHERE notifications.user_id = reject_friendship.user_id
    AND type = 'follow_request'
    AND (metadata ->> 'userId') = request_from_id::text;
END;
$$;


ALTER FUNCTION "public"."reject_friendship"("request_from_id" "uuid", "user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."release_location_processing_claim"("p_location_id" integer, "p_request_id" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  did_release boolean := false;
begin
  update public.locations
  set
    location_processing_claim_id = null,
    location_processing_claimed_at = null
  where location_id = p_location_id
    and location_processing_claim_id = p_request_id
  returning true into did_release;

  return coalesce(did_release, false);
end;
$$;


ALTER FUNCTION "public"."release_location_processing_claim"("p_location_id" integer, "p_request_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_location_from_bubble"("p_bubble_id" "uuid", "p_location_id" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
     BEGIN
       DELETE FROM bubble_locations
       WHERE bubble_id = p_bubble_id
         AND location_id = p_location_id;
     END;
     $$;


ALTER FUNCTION "public"."remove_location_from_bubble"("p_bubble_id" "uuid", "p_location_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_location_from_collection"("p_collection_id" "uuid", "p_location_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id    uuid;
    v_collection public.collections%ROWTYPE;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_collection
    FROM public.collections
    WHERE collection_id = p_collection_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Collection not found');
    END IF;

    IF v_collection.created_by IS DISTINCT FROM v_user_id THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Permission denied');
    END IF;

    DELETE FROM public.collection_locations
    WHERE collection_id = p_collection_id
      AND location_id   = p_location_id;

    RETURN jsonb_build_object('success', TRUE);
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."remove_location_from_collection"("p_collection_id" "uuid", "p_location_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_collection"("p_collection_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid;
    v_collection public.collections%ROWTYPE;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_collection
    FROM public.collections
    WHERE collection_id = p_collection_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Collection not found');
    END IF;

    IF v_collection.created_by = v_user_id THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Cannot save your own collection');
    END IF;

    IF v_collection.is_public IS NOT TRUE THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Collection is private');
    END IF;

    INSERT INTO public.collection_saves (user_id, collection_id)
    VALUES (v_user_id, p_collection_id);

    RETURN jsonb_build_object('success', TRUE);
EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object('success', TRUE, 'message', 'Already saved');
    WHEN foreign_key_violation THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid collection reference');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."save_collection"("p_collection_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_location_with_tags"("p_user_id" "uuid", "p_location_id" integer, "p_saved_method" "text", "p_acked" boolean, "p_source_video_url" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."save_location_with_tags"("p_user_id" "uuid", "p_location_id" integer, "p_saved_method" "text", "p_acked" boolean, "p_source_video_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_locations"("p_query" "text", "p_limit" integer DEFAULT 10, "p_lat" double precision DEFAULT NULL::double precision, "p_lng" double precision DEFAULT NULL::double precision) RETURNS TABLE("location_id" bigint, "name" "text", "vicinity" "text", "lat" numeric, "lng" numeric, "cuisine" "text", "rating" real, "user_ratings_total" numeric, "price_level" numeric, "price_bucket" "text", "photo_reference" "text", "photos" "jsonb", "image_stored" boolean, "image_unavailable" boolean, "saved_count" smallint, "google_place_id" "text", "google_maps_uri" "text", "business_status" "text", "open_now" boolean, "emoji" "text", "types" "text")
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  q text := lower(btrim(coalesce(p_query, '')));
  user_geog geography := CASE
    WHEN p_lat IS NULL OR p_lng IS NULL THEN NULL
    ELSE ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  END;
BEGIN
  IF q = '' THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH ranked AS (
    SELECT
      l.location_id AS lid,
      GREATEST(
        similarity(lower(coalesce(l.name,     '')), q) * 1.0,
        similarity(lower(coalesce(l.cuisine,  '')), q) * 0.7,
        similarity(lower(coalesce(l.vicinity, '')), q) * 0.5
      ) AS score,
      CASE
        WHEN user_geog IS NULL OR l.geog IS NULL THEN NULL
        ELSE ST_Distance(l.geog, user_geog)
      END AS distance_m
    FROM public.locations l
    WHERE
      l.name     % q
      OR l.cuisine  % q
      OR l.vicinity % q
  )
  SELECT
    l.location_id,
    l.name,
    l.vicinity,
    l.lat,
    l.lng,
    l.cuisine,
    l.rating,
    l.user_ratings_total,
    l.price_level,
    l.price_bucket,
    l.photo_reference,
    l.photos,
    l.image_stored,
    l.image_unavailable,
    l.saved_count,
    l.google_place_id,
    l.google_maps_uri,
    l.business_status,
    l.open_now,
    l.emoji,
    l.types
  FROM ranked r
  JOIN public.locations l ON l.location_id = r.lid
  WHERE r.score > 0.15
  ORDER BY
    r.score DESC,
    COALESCE(r.distance_m, 0) / 1000000.0 ASC,
    l.name ASC
  LIMIT GREATEST(p_limit, 1);
END;
$$;


ALTER FUNCTION "public"."search_locations"("p_query" "text", "p_limit" integer, "p_lat" double precision, "p_lng" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_users"("p_query" "text", "p_limit" integer DEFAULT 20) RETURNS SETOF "public"."user_with_counts"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."search_users"("p_query" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_message"("p_bubble_id" "uuid", "p_content" "text", "p_message_type" "text" DEFAULT 'text'::"text", "p_metadata" "jsonb" DEFAULT NULL::"jsonb", "p_replied_to" "uuid" DEFAULT NULL::"uuid", "p_location_id" bigint DEFAULT NULL::bigint) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_message_id UUID;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;

    INSERT INTO messages (
        bubble_id,
        sender_id,
        content,
        message_type,
        metadata,
        replied_to_message_id,
        location_id
    )
    VALUES (
        p_bubble_id,
        auth.uid(),
        p_content,
        p_message_type,
        p_metadata,
        p_replied_to,
        p_location_id
    )
    RETURNING id INTO v_message_id;

    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id)
    DO UPDATE SET last_read_at = NOW();

    RETURN v_message_id;
END;
$$;


ALTER FUNCTION "public"."send_message"("p_bubble_id" "uuid", "p_content" "text", "p_message_type" "text", "p_metadata" "jsonb", "p_replied_to" "uuid", "p_location_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_message_liked"("p_message_id" "uuid", "p_liked" boolean) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_bubble_id uuid;
  v_liked boolean;
BEGIN
  SELECT m.bubble_id
  INTO v_bubble_id
  FROM public.messages m
  WHERE m.id = p_message_id
    AND m.is_deleted = false;

  IF v_bubble_id IS NULL THEN
    RAISE EXCEPTION 'Message not found';
  END IF;

  IF NOT EXISTS (
      SELECT 1 FROM public.bubble_members bm
      WHERE bm.bubble_id = v_bubble_id
        AND bm.user_id = auth.uid()
  ) THEN
      RAISE EXCEPTION 'User not a member of this bubble';
  END IF;

  UPDATE public.messages
  SET liked = p_liked,
      updated_at = NOW()
  WHERE id = p_message_id
  RETURNING liked INTO v_liked;

  RETURN v_liked;
END;
$$;


ALTER FUNCTION "public"."set_message_liked"("p_message_id" "uuid", "p_liked" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."touch_social_review_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."touch_social_review_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."track_app_event"("p_event_name" "text", "p_event_category" "text", "p_session_id" "text", "p_anon_id" "uuid", "p_screen_name" "text", "p_feature_name" "text", "p_duration_ms" integer, "p_occurred_at" timestamp with time zone, "p_app_version" "text", "p_build_number" "text", "p_platform" "text", "p_os_version" "text", "p_locale" "text", "p_timezone" "text", "p_properties" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
    v_user_id UUID := auth.uid();
    v_event_name TEXT := LOWER(TRIM(COALESCE(p_event_name, '')));
    v_session_id TEXT := TRIM(COALESCE(p_session_id, ''));
    v_feature_name TEXT := NULLIF(TRIM(COALESCE(p_feature_name, '')), '');
    v_properties JSONB := NULL;
BEGIN
    IF v_event_name = '' THEN
        RETURN;
    END IF;

    IF v_event_name !~ '^[a-z][a-z0-9_]*$' THEN
        RETURN;
    END IF;

    IF v_session_id = '' THEN
        RETURN;
    END IF;

    IF v_user_id IS NULL AND p_anon_id IS NULL THEN
        RETURN;
    END IF;

    IF v_event_name NOT IN (
        'session_started',
        'app_foregrounded',
        'session_ended',
        'screen_view',
        'tab_switched',
        'search_opened',
        'magic_search_submitted',
        'location_card_opened',
        'location_saved',
        'location_disliked',
        'collection_created',
        'bubble_opened',
        'notification_permission_prompted',
        'notification_permission_result',
        'notification_received',
        'notification_opened',
        'deep_link_routed',
        'deep_link_failed',
        'no_recommendations_in_area_shown'
    ) THEN
        RETURN;
    END IF;

    IF v_event_name = 'notification_permission_result' THEN
        IF p_properties IS NOT NULL
           AND COALESCE(p_properties->>'status', '') <> '' THEN
            v_properties := jsonb_build_object(
                'status',
                p_properties->>'status'
            );
        END IF;
    END IF;

    IF v_event_name = 'no_recommendations_in_area_shown' THEN
        IF p_properties IS NOT NULL THEN
            v_properties := jsonb_strip_nulls(
                jsonb_build_object(
                    'list_type', p_properties->'list_type',
                    'vibe_tag_count', p_properties->'vibe_tag_count',
                    'cuisine_tag_count', p_properties->'cuisine_tag_count',
                    'availability_filter', p_properties->'availability_filter',
                    'center_lat', p_properties->'center_lat',
                    'center_lng', p_properties->'center_lng',
                    'radius_km', p_properties->'radius_km',
                    'camera_zoom', p_properties->'camera_zoom'
                )
            );
        END IF;
    END IF;

    IF v_event_name NOT IN (
        'search_opened',
        'magic_search_submitted',
        'location_card_opened',
        'location_saved',
        'location_disliked',
        'collection_created',
        'bubble_opened'
    ) THEN
        v_feature_name := NULL;
    END IF;

    INSERT INTO public.app_analytics_events (
        occurred_at,
        event_name,
        session_id,
        user_id,
        anon_id,
        feature_name,
        properties
    )
    VALUES (
        COALESCE(p_occurred_at, NOW()),
        v_event_name,
        v_session_id,
        v_user_id,
        p_anon_id,
        v_feature_name,
        v_properties
    );
END;
$_$;


ALTER FUNCTION "public"."track_app_event"("p_event_name" "text", "p_event_category" "text", "p_session_id" "text", "p_anon_id" "uuid", "p_screen_name" "text", "p_feature_name" "text", "p_duration_ms" integer, "p_occurred_at" timestamp with time zone, "p_app_version" "text", "p_build_number" "text", "p_platform" "text", "p_os_version" "text", "p_locale" "text", "p_timezone" "text", "p_properties" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_locations_propagate_geog"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.geog IS DISTINCT FROM OLD.geog THEN
        UPDATE public.location_popularity_app
        SET geog = NEW.geog,
            updated_at = NOW()
        WHERE location_id = NEW.location_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_locations_propagate_geog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_locations_set_geog"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL THEN
        -- Only recompute when geog is missing OR the coords changed.
        IF NEW.geog IS NULL
           OR TG_OP = 'INSERT'
           OR OLD.lat IS DISTINCT FROM NEW.lat
           OR OLD.lng IS DISTINCT FROM NEW.lng
        THEN
            NEW.geog := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_locations_set_geog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_lpa_fill_geog"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.geog IS NULL THEN
        SELECT l.geog INTO NEW.geog
        FROM public.locations l
        WHERE l.location_id = NEW.location_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_lpa_fill_geog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_user_location_actions_share_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    is_relevant_old BOOLEAN := FALSE;
    is_relevant_new BOOLEAN := FALSE;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') AND OLD IS NOT NULL THEN
        is_relevant_old := (OLD.action = 'save'
                            AND OLD.saved_method IN ('tiktok', 'instagram'));
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') AND NEW IS NOT NULL THEN
        is_relevant_new := (NEW.action = 'save'
                            AND NEW.saved_method IN ('tiktok', 'instagram'));
    END IF;

    -- Recompute when the row touches the predicate on either side.
    IF is_relevant_new THEN
        PERFORM recompute_location_share_count(NEW.location_id);
    END IF;
    IF is_relevant_old AND (NEW IS NULL OR OLD.location_id IS DISTINCT FROM NEW.location_id) THEN
        PERFORM recompute_location_share_count(OLD.location_id);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."trg_user_location_actions_share_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unblock_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  DELETE FROM public.user_friends
  WHERE follower_id = p_blocker_id
    AND followee_id = p_blocked_id
    AND status = 'blocked'::relationship_status;
END;
$$;


ALTER FUNCTION "public"."unblock_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unfollow_user"("p_follower_id" "uuid", "p_followee_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  BEGIN
    DELETE FROM user_friends
    WHERE follower_id = p_follower_id
      AND followee_id = p_followee_id;
  END;
  $$;


ALTER FUNCTION "public"."unfollow_user"("p_follower_id" "uuid", "p_followee_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unsave_collection"("p_collection_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
    END IF;

    DELETE FROM public.collection_saves
    WHERE user_id = v_user_id
      AND collection_id = p_collection_id;

    RETURN jsonb_build_object('success', TRUE);
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."unsave_collection"("p_collection_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unsave_location"("p_user_id" "uuid", "p_location_id" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

    -- Step 2: Apply an inverse nudge (top-K only), mirroring save_location_with_tags.
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

    -- Step 4: Mirror save_location_with_tags by handling popularity bookkeeping.
    PERFORM decrement_saves_count(p_location_id);
END;
$$;


ALTER FUNCTION "public"."unsave_location"("p_user_id" "uuid", "p_location_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  update collections
  set
    name        = coalesce(p_name, name),
    cover_color = p_cover_color
  where collection_id = p_collection_id
    and created_by = auth.uid();
end;
$$;


ALTER FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text", "p_is_public" boolean DEFAULT NULL::boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE collections
  SET
    name        = COALESCE(p_name, name),
    cover_color = p_cover_color,
    is_public   = COALESCE(p_is_public, is_public)
  WHERE collection_id = p_collection_id
    AND created_by = auth.uid();
END;
$$;


ALTER FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text", "p_is_public" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_fcm_token"("p_user_id" "uuid", "p_fcm_token" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if auth.role() <> 'service_role' and p_user_id is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  update users
  set fcm_token = p_fcm_token,
      fcm_token_updated_at = now()
  where supabase_id = p_user_id;
end;
$$;


ALTER FUNCTION "public"."update_fcm_token"("p_user_id" "uuid", "p_fcm_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_location_image_url"("p_location_id" bigint, "p_image_url" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE locations
  SET image_stored = true
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."update_location_image_url"("p_location_id" bigint, "p_image_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_location_photo_reference"("p_location_id" bigint, "p_photo_reference" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE locations
  SET photo_reference = p_photo_reference
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."update_location_photo_reference"("p_location_id" bigint, "p_photo_reference" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_location_photos"("p_location_id" bigint, "p_photos" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE locations
  SET photos = p_photos,
      updated_at = now()
  WHERE location_id = p_location_id;
END;
$$;


ALTER FUNCTION "public"."update_location_photos"("p_location_id" bigint, "p_photos" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_location_popularity"("p_location_id" integer, "p_saves_delta" integer DEFAULT 0, "p_likes_delta" integer DEFAULT 0) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
     BEGIN
       INSERT INTO location_popularity_app (location_id, saves_count, likes_count,
     updated_at)
       VALUES (p_location_id, GREATEST(p_saves_delta, 0), GREATEST(p_likes_delta, 0),
     NOW())
       ON CONFLICT (location_id) DO UPDATE SET
         saves_count = GREATEST(location_popularity_app.saves_count + p_saves_delta, 0),
         likes_count = GREATEST(location_popularity_app.likes_count + p_likes_delta, 0),
         updated_at = NOW();
     END;
     $$;


ALTER FUNCTION "public"."update_location_popularity"("p_location_id" integer, "p_saves_delta" integer, "p_likes_delta" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_location_review"("p_location_id" bigint, "p_content" "text" DEFAULT NULL::"text", "p_rating" numeric DEFAULT NULL::numeric, "p_gatekeep" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
  v_review_id uuid;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Update the most recent review row for this user/location.
  SELECT id
    INTO v_review_id
  FROM public.location_reviews
  WHERE user_id = v_user_id
    AND location_id = p_location_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_review_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No existing review');
  END IF;

  UPDATE public.location_reviews
  SET
    content = p_content,
    rating  = p_rating,
    private = p_gatekeep
  WHERE id = v_review_id
    AND user_id = v_user_id;

  -- Ensure the been_to action exists (idempotent).
  PERFORM public.create_user_location_action(
    p_user_id      => v_user_id,
    p_location_id  => p_location_id,
    p_action       => 'been_to'
  );

  RETURN jsonb_build_object('success', true, 'id', v_review_id);

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."update_location_review"("p_location_id" bigint, "p_content" "text", "p_rating" numeric, "p_gatekeep" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_location"("p_user_id" "uuid", "p_lat" double precision, "p_lng" double precision) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if auth.role() <> 'service_role' and p_user_id is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  update users
  set last_lat = p_lat,
      last_lng = p_lng,
      last_location_at = now()
  where supabase_id = p_user_id;
end;
$$;


ALTER FUNCTION "public"."update_user_location"("p_user_id" "uuid", "p_lat" double precision, "p_lng" double precision) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "name" "text" DEFAULT ''::"text" NOT NULL,
    "email" "text" DEFAULT ''::"text" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "supabase_id" "uuid" NOT NULL,
    "bio" "text" DEFAULT ''::"text",
    "profile_image_url" "text",
    "phone_number" "text",
    "spice_tolerance" smallint,
    "wizard_completed" boolean,
    "username" "text" NOT NULL,
    "fcm_token" "text",
    "fcm_token_updated_at" timestamp with time zone,
    "vibe_tag_affinity" real[],
    "dietary_requirement_tag_affinity" real[],
    "generated_collections" timestamp with time zone,
    "legal_consent_accepted_at" timestamp with time zone,
    "referral_code" "text",
    "verified" boolean DEFAULT false,
    "last_lat" double precision,
    "last_lng" double precision,
    "last_location_at" timestamp with time zone
);


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON COLUMN "public"."users"."spice_tolerance" IS 'spice tolerance from 1-5';



COMMENT ON COLUMN "public"."users"."vibe_tag_affinity" IS 'Order : ["cafe", "casual", "cozy", "coffee_shop", "bar",   "elegant", "fine_dining", "food_truck", "hole_in_the_wall", "late_night",     "live_music", "michelin_starred", "modern", "fast_food", "quiet",     "romantic", "sports_bar", "trendy", "takeout_friendly", "pub", "grocery_store", "brunch", "outdoor_dining", "wavy", "bossman"]';



COMMENT ON COLUMN "public"."users"."dietary_requirement_tag_affinity" IS '"halal", "vegan","gluten-free","vegetarian", "dairy-free","nut-free"';



COMMENT ON COLUMN "public"."users"."referral_code" IS 'Referral code applied by the user during onboarding before rewards unlock on wizard completion.';



CREATE OR REPLACE FUNCTION "public"."update_user_profile"("p_user_id" "uuid", "p_name" "text" DEFAULT NULL::"text", "p_username" "text" DEFAULT NULL::"text", "p_bio" "text" DEFAULT NULL::"text", "p_profile_image_url" "text" DEFAULT NULL::"text") RETURNS SETOF "public"."users"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  UPDATE public.users AS u  -- Use an alias 'u'
  SET
    name = COALESCE(p_name, u.name),
    username = COALESCE(p_username, u.username),
    bio = COALESCE(p_bio, u.bio),
    profile_image_url = COALESCE(p_profile_image_url, u.profile_image_url)
  WHERE u.supabase_id = p_user_id -- Explicitly reference the table alias
  RETURNING u.*;
END;
$$;


ALTER FUNCTION "public"."update_user_profile"("p_user_id" "uuid", "p_name" "text", "p_username" "text", "p_bio" "text", "p_profile_image_url" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rewards"."referrals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "referral_code_id" "uuid" NOT NULL,
    "inviter_user_id" "uuid",
    "invitee_user_id" "uuid" NOT NULL,
    "entered_code" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "entered_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "accepted_at" timestamp with time zone,
    "voided_at" timestamp with time zone,
    "acceptance_trigger" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "referrals_check" CHECK (("inviter_user_id" <> "invitee_user_id")),
    CONSTRAINT "referrals_check1" CHECK (((("status" = 'pending'::"text") AND ("accepted_at" IS NULL) AND ("voided_at" IS NULL)) OR (("status" = 'accepted'::"text") AND ("accepted_at" IS NOT NULL) AND ("voided_at" IS NULL)) OR (("status" = 'voided'::"text") AND ("accepted_at" IS NULL) AND ("voided_at" IS NOT NULL)))),
    CONSTRAINT "referrals_entered_code_check" CHECK (("btrim"("entered_code") <> ''::"text")),
    CONSTRAINT "referrals_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'voided'::"text"])))
);


ALTER TABLE "rewards"."referrals" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."accept_pending_referral_for_user"("p_user_id" "uuid") RETURNS "rewards"."referrals"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'rewards', 'public'
    AS $$
DECLARE
  v_auth_user_id uuid := auth.uid();
  v_request_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
  v_referral rewards.referrals;
  v_wizard_completed boolean;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  IF v_request_role <> 'service_role'
     AND v_auth_user_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Authenticated user does not match p_user_id';
  END IF;

  SELECT u.wizard_completed
  INTO v_wizard_completed
  FROM public.users u
  WHERE u.supabase_id = p_user_id;

  IF coalesce(v_request_role, '') <> 'service_role'
     AND coalesce(v_wizard_completed, false) = false THEN
    RAISE EXCEPTION 'Signup wizard must be completed before referral acceptance';
  END IF;

  SELECT *
  INTO v_referral
  FROM rewards.referrals
  WHERE invitee_user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_referral.status = 'pending' THEN
    UPDATE rewards.referrals
    SET
      status = 'accepted',
      accepted_at = now(),
      acceptance_trigger = 'wizard_completion'
    WHERE id = v_referral.id
    RETURNING *
    INTO v_referral;
  END IF;

  PERFORM rewards.issue_referral_vouchers(v_referral);

  RETURN v_referral;
END;
$$;


ALTER FUNCTION "rewards"."accept_pending_referral_for_user"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."admin_accept_pending_referral_for_user"("p_user_id" "uuid", "p_acceptance_trigger" "text" DEFAULT 'admin_sql_editor'::"text") RETURNS "rewards"."referrals"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'rewards'
    AS $$
DECLARE
  v_referral rewards.referrals;
  v_effective_acceptance_trigger text := coalesce(
    nullif(btrim(p_acceptance_trigger), ''),
    'admin_sql_editor'
  );
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  SELECT *
  INTO v_referral
  FROM rewards.referrals
  WHERE invitee_user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_referral.status = 'pending' THEN
    UPDATE rewards.referrals
    SET
      status = 'accepted',
      accepted_at = now(),
      acceptance_trigger = v_effective_acceptance_trigger
    WHERE id = v_referral.id
    RETURNING *
    INTO v_referral;
  END IF;

  PERFORM rewards.issue_referral_vouchers(v_referral);

  RETURN v_referral;
END;
$$;


ALTER FUNCTION "rewards"."admin_accept_pending_referral_for_user"("p_user_id" "uuid", "p_acceptance_trigger" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."apply_referral_code"("p_code" "text") RETURNS "rewards"."referrals"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'rewards', 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_normalized_code text;
  v_referral_code rewards.referral_codes;
  v_referral rewards.referrals;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is null';
  END IF;

  v_normalized_code := upper(
    regexp_replace(
      coalesce(btrim(p_code), ''),
      '[^a-zA-Z0-9]+',
      '',
      'g'
    )
  );

  IF v_normalized_code = '' THEN
    RAISE EXCEPTION 'Referral code is required';
  END IF;

  SELECT *
  INTO v_referral_code
  FROM rewards.referral_codes
  WHERE normalized_code = v_normalized_code
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Referral code is invalid or inactive';
  END IF;

  IF v_referral_code.owner_user_id = v_user_id THEN
    RAISE EXCEPTION 'You cannot apply your own referral code';
  END IF;

  INSERT INTO rewards.referrals (
    referral_code_id,
    inviter_user_id,
    invitee_user_id,
    entered_code
  )
  VALUES (
    v_referral_code.id,
    v_referral_code.owner_user_id,
    v_user_id,
    btrim(p_code)
  )
  ON CONFLICT (invitee_user_id) DO UPDATE
  SET
    referral_code_id = EXCLUDED.referral_code_id,
    inviter_user_id = EXCLUDED.inviter_user_id,
    entered_code = EXCLUDED.entered_code,
    entered_at = now(),
    accepted_at = NULL,
    voided_at = NULL,
    acceptance_trigger = NULL,
    status = 'pending'
  WHERE rewards.referrals.status = 'pending'
  RETURNING *
  INTO v_referral;

  IF NOT FOUND THEN
    SELECT *
    INTO v_referral
    FROM rewards.referrals
    WHERE invitee_user_id = v_user_id;

    IF FOUND AND v_referral.status <> 'pending' THEN
      RAISE EXCEPTION 'Referral is already locked for this user';
    END IF;

    RAISE EXCEPTION 'Referral could not be applied';
  END IF;

  UPDATE public.users
  SET referral_code = v_referral_code.code
  WHERE supabase_id = v_user_id;

  RETURN v_referral;
END;
$$;


ALTER FUNCTION "rewards"."apply_referral_code"("p_code" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rewards"."referral_codes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_user_id" "uuid",
    "code" "text" NOT NULL,
    "normalized_code" "text" GENERATED ALWAYS AS ("upper"("regexp_replace"("code", '[^a-zA-Z0-9]+'::"text", ''::"text", 'g'::"text"))) STORED,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "referral_codes_code_check" CHECK (("btrim"("code") <> ''::"text")),
    CONSTRAINT "referral_codes_normalized_code_check" CHECK (("normalized_code" <> ''::"text"))
);


ALTER TABLE "rewards"."referral_codes" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."ensure_referral_code"() RETURNS "rewards"."referral_codes"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'rewards', 'public'
    AS $$
DECLARE
  v_owner_user_id uuid := auth.uid();
  v_referral_code rewards.referral_codes;
BEGIN
  IF v_owner_user_id IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is null';
  END IF;

  SELECT *
  INTO v_referral_code
  FROM rewards.referral_codes
  WHERE owner_user_id = v_owner_user_id;

  IF FOUND THEN
    RETURN v_referral_code;
  END IF;

  INSERT INTO rewards.referral_codes (
    owner_user_id,
    code
  )
  VALUES (
    v_owner_user_id,
    rewards.generate_referral_code(v_owner_user_id)
  )
  ON CONFLICT (owner_user_id) DO UPDATE
  SET code = rewards.referral_codes.code
  RETURNING *
  INTO v_referral_code;

  RETURN v_referral_code;
END;
$$;


ALTER FUNCTION "rewards"."ensure_referral_code"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."generate_referral_code"("p_owner_user_id" "uuid", "p_seed_text" "text" DEFAULT NULL::"text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_seed text;
begin
  v_seed := left(
    coalesce(
      nullif(
        regexp_replace(
          upper(coalesce(nullif(btrim(p_seed_text), ''), 'PIN')),
          '[^A-Z0-9]+',
          '',
          'g'
        ),
        ''
      ),
      'PIN'
    ),
    10
  );

  return format(
    '%s-%s',
    v_seed,
    upper(replace(p_owner_user_id::text, '-', ''))
  );
end;
$$;


ALTER FUNCTION "rewards"."generate_referral_code"("p_owner_user_id" "uuid", "p_seed_text" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."get_my_referral_dashboard"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'rewards', 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_referral_code rewards.referral_codes;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is null';
  END IF;

  SELECT *
  INTO v_referral_code
  FROM rewards.referral_codes
  WHERE owner_user_id = v_user_id;

  IF v_referral_code.id IS NULL THEN
    v_referral_code := rewards.ensure_referral_code();
  END IF;

  RETURN jsonb_build_object(
    'referral_code',
    v_referral_code.code,
    'accepted_referral_count',
    (
      SELECT count(*)::integer
      FROM rewards.referrals r
      WHERE r.inviter_user_id = v_user_id
        AND r.status = 'accepted'
    ),
    'has_entered_referral_code',
    EXISTS (
      SELECT 1
      FROM rewards.referrals r
      WHERE r.invitee_user_id = v_user_id
    ),
    'available_vouchers',
    coalesce(
      (
        SELECT jsonb_agg(
                 rewards.voucher_to_json(v)
                 ORDER BY v.issued_at DESC, v.id DESC
               )
        FROM rewards.vouchers v
        WHERE v.user_id = v_user_id
          AND v.status = 'available'
          AND (v.expires_at IS NULL OR v.expires_at > now())
          AND (
            SELECT count(*)
            FROM rewards.vouchers redeemed
            WHERE redeemed.user_id = v.user_id
              AND redeemed.campaign_key = v.campaign_key
              AND redeemed.status = 'redeemed'
          ) = 0
      ),
      '[]'::jsonb
    ),
    'used_vouchers',
    coalesce(
      (
        SELECT jsonb_agg(
                 rewards.voucher_to_json(v)
                 ORDER BY v.redeemed_at DESC NULLS LAST, v.issued_at DESC, v.id DESC
               )
        FROM rewards.vouchers v
        WHERE v.user_id = v_user_id
          AND v.status = 'redeemed'
      ),
      '[]'::jsonb
    )
  );
END;
$$;


ALTER FUNCTION "rewards"."get_my_referral_dashboard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."issue_referral_vouchers"("p_referral" "rewards"."referrals") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'rewards', 'public'
    AS $$
DECLARE
  v_constraint_name text;
  v_campaign_key text := 'imperial_farmers_market_10pct_selected_stores';
BEGIN
  IF p_referral.status IS DISTINCT FROM 'accepted' THEN
    RETURN;
  END IF;

  -- Promo codes: issue that code's vouchers to the invitee only.
  IF EXISTS (
    SELECT 1
    FROM rewards.promo_code_vouchers t
    WHERE t.referral_code_id = p_referral.referral_code_id
  ) THEN
    INSERT INTO rewards.vouchers (
      user_id,
      source_referral_id,
      source_type,
      campaign_key,
      title,
      description,
      merchant_name,
      terms_text,
      discount_percent,
      location_id,
      is_single_use,
      issued_at,
      expires_at,
      metadata
    )
    SELECT
      p_referral.invitee_user_id,
      p_referral.id,
      'promo_reward',
      t.campaign_key,
      t.title,
      t.description,
      t.merchant_name,
      t.terms_text,
      t.discount_percent,
      t.location_id,
      t.is_single_use,
      -- The dashboard sorts by issued_at desc; offset so vouchers keep sort_order.
      now() - make_interval(secs => t.sort_order),
      t.expires_at,
      jsonb_build_object(
        'reward_role', 'promo',
        'promo_code', p_referral.entered_code,
        'acceptance_trigger', p_referral.acceptance_trigger
      )
    FROM rewards.promo_code_vouchers t
    WHERE t.referral_code_id = p_referral.referral_code_id
      AND t.is_active
      AND (t.expires_at IS NULL OR t.expires_at > now())
      AND NOT EXISTS (
        SELECT 1
        FROM rewards.vouchers existing
        WHERE existing.user_id = p_referral.invitee_user_id
          AND existing.campaign_key = t.campaign_key
          AND existing.status IN ('available', 'redeemed')
      )
    ON CONFLICT DO NOTHING;

    RETURN;
  END IF;

  -- User referral codes: existing Imperial Farmers Market rewards.
  BEGIN
    INSERT INTO rewards.vouchers (
      user_id,
      source_referral_id,
      source_type,
      campaign_key,
      title,
      description,
      merchant_name,
      terms_text,
      metadata
    )
    SELECT
      p_referral.invitee_user_id,
      p_referral.id,
      'invitee_reward',
      v_campaign_key,
      'Imperial Farmers Market 10% Off',
      'Reward for completing signup with a referral code.',
      'Imperial Farmers Market',
      'Valid for 10% off at selected Imperial Farmers Market stores. Single use.',
      jsonb_build_object(
        'reward_role', 'invitee',
        'acceptance_trigger', p_referral.acceptance_trigger
      )
    WHERE NOT EXISTS (
      SELECT 1
      FROM rewards.vouchers existing
      WHERE existing.user_id = p_referral.invitee_user_id
        AND existing.campaign_key = v_campaign_key
        AND existing.source_type = 'invitee_reward'
        AND existing.status IN ('available', 'redeemed')
      GROUP BY existing.user_id, existing.campaign_key, existing.source_type
      HAVING count(*) >= coalesce(
        (
          SELECT r.max_applications_per_user_per_campaign
          FROM rewards.voucher_source_type_rules r
          WHERE r.source_type = 'invitee_reward'
        ),
        2147483647
      )
    )
    ON CONFLICT (user_id, campaign_key, source_type)
    WHERE status = 'available'
    DO NOTHING;
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_constraint_name = CONSTRAINT_NAME;

    IF v_constraint_name NOT IN (
      'vouchers_user_campaign_type_available_unique_idx',
      'vouchers_source_referral_user_type_unique_idx'
    ) THEN
      RAISE;
    END IF;
  END;

  IF p_referral.inviter_user_id IS NULL THEN
    RETURN;
  END IF;

  BEGIN
    INSERT INTO rewards.vouchers (
      user_id,
      source_referral_id,
      source_type,
      campaign_key,
      title,
      description,
      merchant_name,
      terms_text,
      metadata
    )
    SELECT
      p_referral.inviter_user_id,
      p_referral.id,
      'inviter_reward',
      v_campaign_key,
      'Imperial Farmers Market 10% Off',
      'Reward for a successful referral signup completion.',
      'Imperial Farmers Market',
      'Valid for 10% off at selected Imperial Farmers Market stores. Single use.',
      jsonb_build_object(
        'reward_role', 'inviter',
        'acceptance_trigger', p_referral.acceptance_trigger
      )
    WHERE NOT EXISTS (
      SELECT 1
      FROM rewards.vouchers existing
      WHERE existing.user_id = p_referral.inviter_user_id
        AND existing.campaign_key = v_campaign_key
        AND existing.source_type = 'inviter_reward'
        AND existing.status IN ('available', 'redeemed')
      GROUP BY existing.user_id, existing.campaign_key, existing.source_type
      HAVING count(*) >= coalesce(
        (
          SELECT r.max_applications_per_user_per_campaign
          FROM rewards.voucher_source_type_rules r
          WHERE r.source_type = 'inviter_reward'
        ),
        2147483647
      )
    )
    ON CONFLICT (user_id, campaign_key, source_type)
    WHERE status = 'available'
    DO NOTHING;
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_constraint_name = CONSTRAINT_NAME;

    IF v_constraint_name NOT IN (
      'vouchers_user_campaign_type_available_unique_idx',
      'vouchers_source_referral_user_type_unique_idx'
    ) THEN
      RAISE;
    END IF;
  END;
END;
$$;


ALTER FUNCTION "rewards"."issue_referral_vouchers"("p_referral" "rewards"."referrals") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rewards"."vouchers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "source_referral_id" "uuid",
    "source_type" "text" NOT NULL,
    "campaign_key" "text" DEFAULT 'imperial_farmers_market_10pct_selected_stores'::"text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "merchant_name" "text" NOT NULL,
    "terms_text" "text",
    "discount_percent" integer DEFAULT 10 NOT NULL,
    "status" "text" DEFAULT 'available'::"text" NOT NULL,
    "issued_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "redeemed_at" timestamp with time zone,
    "expires_at" timestamp with time zone,
    "redemption_token" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "location_id" bigint,
    "is_single_use" boolean DEFAULT true NOT NULL,
    "redemption_count" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "vouchers_discount_percent_check" CHECK ((("discount_percent" >= 0) AND ("discount_percent" <= 100))),
    CONSTRAINT "vouchers_merchant_name_check" CHECK (("btrim"("merchant_name") <> ''::"text")),
    CONSTRAINT "vouchers_source_type_check" CHECK (("source_type" = ANY (ARRAY['inviter_reward'::"text", 'invitee_reward'::"text", 'promo_reward'::"text"]))),
    CONSTRAINT "vouchers_status_check" CHECK (("status" = ANY (ARRAY['available'::"text", 'redeemed'::"text", 'expired'::"text", 'voided'::"text"]))),
    CONSTRAINT "vouchers_title_check" CHECK (("btrim"("title") <> ''::"text"))
);


ALTER TABLE "rewards"."vouchers" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."redeem_voucher"("p_voucher_id" "uuid") RETURNS "rewards"."vouchers"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'rewards', 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_voucher rewards.vouchers;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is null';
  END IF;

  SELECT *
  INTO v_voucher
  FROM rewards.vouchers
  WHERE id = p_voucher_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voucher not found';
  END IF;

  IF v_voucher.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Voucher does not belong to the authenticated user';
  END IF;

  IF v_voucher.status <> 'available' THEN
    RAISE EXCEPTION 'Voucher is not available for redemption';
  END IF;

  IF v_voucher.expires_at IS NOT NULL AND v_voucher.expires_at <= now() THEN
    RAISE EXCEPTION 'Voucher has expired';
  END IF;

  IF NOT v_voucher.is_single_use THEN
    UPDATE rewards.vouchers
    SET
      redemption_count = redemption_count + 1,
      redeemed_at = now()
    WHERE id = p_voucher_id
    RETURNING *
    INTO v_voucher;

    RETURN v_voucher;
  END IF;

  PERFORM 1
  FROM rewards.vouchers locked
  WHERE locked.user_id = v_user_id
    AND locked.campaign_key = v_voucher.campaign_key
  FOR UPDATE;

  IF (
    SELECT count(*)
    FROM rewards.vouchers redeemed
    WHERE redeemed.user_id = v_user_id
      AND redeemed.campaign_key = v_voucher.campaign_key
      AND redeemed.status = 'redeemed'
  ) > 0 THEN
    RAISE EXCEPTION 'Voucher redemption limit reached for this campaign';
  END IF;

  UPDATE rewards.vouchers
  SET
    status = 'redeemed',
    redemption_count = redemption_count + 1,
    redeemed_at = now()
  WHERE id = p_voucher_id
  RETURNING *
  INTO v_voucher;

  UPDATE rewards.vouchers
  SET status = 'voided'
  WHERE user_id = v_user_id
    AND campaign_key = v_voucher.campaign_key
    AND status = 'available'
    AND id <> v_voucher.id;

  RETURN v_voucher;
END;
$$;


ALTER FUNCTION "rewards"."redeem_voucher"("p_voucher_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION "rewards"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "rewards"."voucher_to_json"("p_voucher" "rewards"."vouchers") RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT jsonb_build_object(
    'id', p_voucher.id,
    'source_type', p_voucher.source_type,
    'campaign_key', p_voucher.campaign_key,
    'title', p_voucher.title,
    'description', p_voucher.description,
    'merchant_name', p_voucher.merchant_name,
    'terms_text', p_voucher.terms_text,
    'discount_percent', p_voucher.discount_percent,
    'location_id', p_voucher.location_id,
    'is_single_use', p_voucher.is_single_use,
    'redemption_count', p_voucher.redemption_count,
    'status', p_voucher.status,
    'issued_at', p_voucher.issued_at,
    'redeemed_at', p_voucher.redeemed_at,
    'expires_at', p_voucher.expires_at
  );
$$;


ALTER FUNCTION "rewards"."voucher_to_json"("p_voucher" "rewards"."vouchers") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_analytics_events" (
    "id" bigint NOT NULL,
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_name" "text" NOT NULL,
    "session_id" "text" NOT NULL,
    "user_id" "uuid",
    "anon_id" "uuid",
    "feature_name" "text",
    "properties" "jsonb",
    CONSTRAINT "app_analytics_events_v2_actor_presence_chk" CHECK ((("user_id" IS NOT NULL) OR ("anon_id" IS NOT NULL))),
    CONSTRAINT "app_analytics_events_v2_event_name_snake_case_chk" CHECK (("event_name" ~ '^[a-z][a-z0-9_]*$'::"text"))
);


ALTER TABLE "public"."app_analytics_events" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."analytics_daily_user_activity" WITH ("security_invoker"='true') AS
 WITH "activity" AS (
         SELECT (("app_analytics_events"."occurred_at" AT TIME ZONE 'UTC'::"text"))::"date" AS "activity_date",
            COALESCE(("app_analytics_events"."user_id")::"text", ("app_analytics_events"."anon_id")::"text") AS "actor_id",
            "app_analytics_events"."session_id"
           FROM "public"."app_analytics_events"
          WHERE ("app_analytics_events"."event_name" = ANY (ARRAY['session_started'::"text", 'app_foregrounded'::"text", 'session_ended'::"text", 'screen_view'::"text", 'tab_switched'::"text", 'search_opened'::"text", 'magic_search_submitted'::"text", 'location_saved'::"text", 'location_disliked'::"text", 'bubble_opened'::"text"]))
        ), "daily" AS (
         SELECT "activity"."activity_date",
            "count"(DISTINCT "activity"."actor_id") AS "dau",
            "count"(DISTINCT "activity"."session_id") AS "total_sessions"
           FROM "activity"
          GROUP BY "activity"."activity_date"
        )
 SELECT "d"."activity_date",
    "d"."dau",
    "d"."total_sessions",
    "round"((("d"."total_sessions")::numeric / (NULLIF("d"."dau", 0))::numeric), 3) AS "sessions_per_active_user",
    ( SELECT "count"(DISTINCT "a"."actor_id") AS "count"
           FROM "activity" "a"
          WHERE (("a"."activity_date" >= ("d"."activity_date" - 6)) AND ("a"."activity_date" <= "d"."activity_date"))) AS "wau",
    ( SELECT "count"(DISTINCT "a"."actor_id") AS "count"
           FROM "activity" "a"
          WHERE (("a"."activity_date" >= ("d"."activity_date" - 29)) AND ("a"."activity_date" <= "d"."activity_date"))) AS "mau",
    "round"((("d"."dau")::numeric / (NULLIF(( SELECT "count"(DISTINCT "a"."actor_id") AS "count"
           FROM "activity" "a"
          WHERE (("a"."activity_date" >= ("d"."activity_date" - 29)) AND ("a"."activity_date" <= "d"."activity_date"))), 0))::numeric), 4) AS "dau_mau_stickiness",
    "round"(( SELECT "avg"(("user_days"."days_active")::numeric) AS "avg"
           FROM ( SELECT "a"."actor_id",
                    "count"(DISTINCT "a"."activity_date") AS "days_active"
                   FROM "activity" "a"
                  WHERE (("a"."activity_date" >= ("d"."activity_date" - 6)) AND ("a"."activity_date" <= "d"."activity_date"))
                  GROUP BY "a"."actor_id") "user_days"), 3) AS "avg_active_days_per_user_7d"
   FROM "daily" "d"
  ORDER BY "d"."activity_date" DESC;


ALTER TABLE "public"."analytics_daily_user_activity" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."analytics_feature_adoption_daily" WITH ("security_invoker"='true') AS
 SELECT (("app_analytics_events"."occurred_at" AT TIME ZONE 'UTC'::"text"))::"date" AS "activity_date",
    COALESCE("app_analytics_events"."feature_name", "app_analytics_events"."event_name") AS "feature_name",
    "count"(*) AS "event_count",
    "count"(DISTINCT COALESCE(("app_analytics_events"."user_id")::"text", ("app_analytics_events"."anon_id")::"text")) AS "unique_users"
   FROM "public"."app_analytics_events"
  WHERE ("app_analytics_events"."event_name" = ANY (ARRAY['search_opened'::"text", 'magic_search_submitted'::"text", 'location_card_opened'::"text", 'location_saved'::"text", 'location_disliked'::"text", 'collection_created'::"text", 'bubble_opened'::"text"]))
  GROUP BY ((("app_analytics_events"."occurred_at" AT TIME ZONE 'UTC'::"text"))::"date"), COALESCE("app_analytics_events"."feature_name", "app_analytics_events"."event_name")
  ORDER BY ((("app_analytics_events"."occurred_at" AT TIME ZONE 'UTC'::"text"))::"date") DESC, COALESCE("app_analytics_events"."feature_name", "app_analytics_events"."event_name");


ALTER TABLE "public"."analytics_feature_adoption_daily" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."analytics_notification_funnel_daily" WITH ("security_invoker"='true') AS
 WITH "base" AS (
         SELECT (("app_analytics_events"."occurred_at" AT TIME ZONE 'UTC'::"text"))::"date" AS "activity_date",
            "app_analytics_events"."event_name",
            COALESCE(("app_analytics_events"."user_id")::"text", ("app_analytics_events"."anon_id")::"text") AS "actor_id",
            "app_analytics_events"."properties"
           FROM "public"."app_analytics_events"
          WHERE ("app_analytics_events"."event_name" = ANY (ARRAY['notification_permission_prompted'::"text", 'notification_permission_result'::"text", 'notification_received'::"text", 'notification_opened'::"text", 'deep_link_routed'::"text", 'deep_link_failed'::"text"]))
        )
 SELECT "base"."activity_date",
    "count"(*) FILTER (WHERE ("base"."event_name" = 'notification_permission_prompted'::"text")) AS "permission_prompted",
    "count"(*) FILTER (WHERE (("base"."event_name" = 'notification_permission_result'::"text") AND (COALESCE(("base"."properties" ->> 'status'::"text"), ''::"text") = ANY (ARRAY['authorized'::"text", 'provisional'::"text"])))) AS "permission_enabled_events",
    "count"(*) FILTER (WHERE ("base"."event_name" = 'notification_received'::"text")) AS "notifications_received",
    "count"(*) FILTER (WHERE ("base"."event_name" = 'notification_opened'::"text")) AS "notifications_opened",
    "count"(*) FILTER (WHERE ("base"."event_name" = 'deep_link_routed'::"text")) AS "deep_link_routed",
    "count"(*) FILTER (WHERE ("base"."event_name" = 'deep_link_failed'::"text")) AS "deep_link_failed",
    "count"(DISTINCT "base"."actor_id") FILTER (WHERE ("base"."event_name" = 'notification_received'::"text")) AS "users_received",
    "count"(DISTINCT "base"."actor_id") FILTER (WHERE ("base"."event_name" = 'notification_opened'::"text")) AS "users_opened",
    "round"((("count"(*) FILTER (WHERE ("base"."event_name" = 'notification_opened'::"text")))::numeric / (NULLIF("count"(*) FILTER (WHERE ("base"."event_name" = 'notification_received'::"text")), 0))::numeric), 4) AS "open_rate"
   FROM "base"
  GROUP BY "base"."activity_date"
  ORDER BY "base"."activity_date" DESC;


ALTER TABLE "public"."analytics_notification_funnel_daily" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."analytics_retention_cohorts" WITH ("security_invoker"='true') AS
 WITH "activity" AS (
         SELECT DISTINCT COALESCE(("app_analytics_events"."user_id")::"text", ("app_analytics_events"."anon_id")::"text") AS "actor_id",
            (("app_analytics_events"."occurred_at" AT TIME ZONE 'UTC'::"text"))::"date" AS "activity_date"
           FROM "public"."app_analytics_events"
          WHERE ("app_analytics_events"."event_name" = ANY (ARRAY['session_started'::"text", 'app_foregrounded'::"text"]))
        ), "first_seen" AS (
         SELECT "activity"."actor_id",
            "min"("activity"."activity_date") AS "cohort_date"
           FROM "activity"
          GROUP BY "activity"."actor_id"
        )
 SELECT "fs"."cohort_date",
    "count"(*) AS "cohort_size",
    "count"(*) FILTER (WHERE (EXISTS ( SELECT 1
           FROM "activity" "a"
          WHERE (("a"."actor_id" = "fs"."actor_id") AND ("a"."activity_date" = ("fs"."cohort_date" + 1)))))) AS "d1_retained_users",
    "count"(*) FILTER (WHERE (EXISTS ( SELECT 1
           FROM "activity" "a"
          WHERE (("a"."actor_id" = "fs"."actor_id") AND ("a"."activity_date" = ("fs"."cohort_date" + 7)))))) AS "d7_retained_users",
    "count"(*) FILTER (WHERE (EXISTS ( SELECT 1
           FROM "activity" "a"
          WHERE (("a"."actor_id" = "fs"."actor_id") AND ("a"."activity_date" = ("fs"."cohort_date" + 30)))))) AS "d30_retained_users",
    "round"((("count"(*) FILTER (WHERE (EXISTS ( SELECT 1
           FROM "activity" "a"
          WHERE (("a"."actor_id" = "fs"."actor_id") AND ("a"."activity_date" = ("fs"."cohort_date" + 1)))))))::numeric / (NULLIF("count"(*), 0))::numeric), 4) AS "d1_retention_rate",
    "round"((("count"(*) FILTER (WHERE (EXISTS ( SELECT 1
           FROM "activity" "a"
          WHERE (("a"."actor_id" = "fs"."actor_id") AND ("a"."activity_date" = ("fs"."cohort_date" + 7)))))))::numeric / (NULLIF("count"(*), 0))::numeric), 4) AS "d7_retention_rate",
    "round"((("count"(*) FILTER (WHERE (EXISTS ( SELECT 1
           FROM "activity" "a"
          WHERE (("a"."actor_id" = "fs"."actor_id") AND ("a"."activity_date" = ("fs"."cohort_date" + 30)))))))::numeric / (NULLIF("count"(*), 0))::numeric), 4) AS "d30_retention_rate"
   FROM "first_seen" "fs"
  GROUP BY "fs"."cohort_date"
  ORDER BY "fs"."cohort_date" DESC;


ALTER TABLE "public"."analytics_retention_cohorts" OWNER TO "postgres";


ALTER TABLE "public"."app_analytics_events" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."app_analytics_events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."bubble_locations" (
    "bubble_location_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bubble_id" "uuid" NOT NULL,
    "location_id" bigint NOT NULL,
    "added_by" "uuid",
    "added_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "note" "text"
);


ALTER TABLE "public"."bubble_locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bubble_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bubble_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "added_at" timestamp without time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."bubble_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bubbles" (
    "bubble_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "is_private" boolean DEFAULT false NOT NULL,
    "activity" smallint
);


ALTER TABLE "public"."bubbles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."collection_locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "collection_id" "uuid" NOT NULL,
    "location_id" bigint NOT NULL,
    "added_by" "uuid",
    "added_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "note" "text"
);


ALTER TABLE "public"."collection_locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."collection_saves" (
    "user_id" "uuid" NOT NULL,
    "collection_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."collection_saves" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."collections" (
    "collection_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "emoji" "text",
    "cover_color" "text",
    "created_by" "uuid",
    "is_curated" boolean DEFAULT false NOT NULL,
    "is_public" boolean DEFAULT true NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "photo" "text",
    "curated_city" "text"
);


ALTER TABLE "public"."collections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."internal_alert_config" (
    "id" integer DEFAULT 1 NOT NULL,
    "enabled" boolean DEFAULT false NOT NULL,
    "push_api_url" "text",
    "push_api_key" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "internal_alert_config_singleton_chk" CHECK (("id" = 1))
);


ALTER TABLE "public"."internal_alert_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."internal_alert_recipients" (
    "user_id" "uuid" NOT NULL,
    "enabled" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."internal_alert_recipients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."location_popularity_app" (
    "location_id" bigint NOT NULL,
    "saves_count" integer DEFAULT 0 NOT NULL,
    "dislikes_count" integer DEFAULT 0 NOT NULL,
    "updated_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "been_to_count" integer,
    "quality_score" numeric,
    "share_count" integer DEFAULT 0 NOT NULL,
    "app_engagement_score" numeric,
    "google_baseline_score" numeric,
    "video_insight_score" numeric,
    "geog" "public"."geography"(Point,4326)
);


ALTER TABLE "public"."location_popularity_app" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."location_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "content" "text",
    "rating" numeric(3,1),
    "user_id" "uuid",
    "private" boolean DEFAULT false,
    "location_id" bigint
);


ALTER TABLE "public"."location_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."location_similarities" (
    "location_id_a" bigint NOT NULL,
    "location_id_b" bigint NOT NULL,
    "similarity_score" double precision NOT NULL,
    "co_save_count" integer DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."location_similarities" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."locations_location_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."locations_location_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."locations_location_id_seq" OWNED BY "public"."locations"."location_id";



CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bubble_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "content" "text",
    "message_type" "text" DEFAULT 'text'::"text",
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_deleted" boolean DEFAULT false,
    "replied_to_message_id" "uuid",
    "location_id" bigint,
    "liked" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "title" "text",
    "message" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_read" boolean DEFAULT false NOT NULL,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dismissed_at" timestamp with time zone
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."social_post_actions" (
    "social_post_action_id" bigint NOT NULL,
    "url" "text" NOT NULL,
    "normalized_url" "text" GENERATED ALWAYS AS ("lower"("regexp_replace"(
CASE
    WHEN ("btrim"("url") ~* '^https?://'::"text") THEN "split_part"("split_part"("btrim"("url"), '#'::"text", 1), '?'::"text", 1)
    ELSE ('https://'::"text" || "split_part"("split_part"("btrim"("url"), '#'::"text", 1), '?'::"text", 1))
END, '/+$'::"text", ''::"text"))) STORED,
    "platform" "text" NOT NULL,
    "location_ids" bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    "eat_list_collection_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "social_post_actions_has_action" CHECK ((("cardinality"("location_ids") > 0) OR ("eat_list_collection_id" IS NOT NULL))),
    CONSTRAINT "social_post_actions_location_ids_not_null" CHECK (("array_position"("location_ids", NULL::bigint) IS NULL)),
    CONSTRAINT "social_post_actions_platform_check" CHECK (("platform" = ANY (ARRAY['tiktok'::"text", 'instagram'::"text"]))),
    CONSTRAINT "social_post_actions_url_not_blank" CHECK (("btrim"("url") <> ''::"text"))
);


ALTER TABLE "public"."social_post_actions" OWNER TO "postgres";


ALTER TABLE "public"."social_post_actions" ALTER COLUMN "social_post_action_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."social_post_actions_social_post_action_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."social_post_place_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "social_post_place_id" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "corrected_google_place_id" "text",
    "corrected_location_id" bigint,
    "location_id" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "confirmed_by_user" boolean DEFAULT false NOT NULL,
    CONSTRAINT "social_post_place_reviews_action_check" CHECK (("action" = ANY (ARRAY['saved'::"text", 'discarded'::"text", 'corrected'::"text", 'manual_added'::"text"])))
);


ALTER TABLE "public"."social_post_place_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."social_post_places" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "social_post_id" "uuid" NOT NULL,
    "location_id" bigint,
    "google_place_id" "text",
    "name" "text" NOT NULL,
    "address" "text",
    "candidate_name" "text",
    "candidate_area" "text",
    "confidence_score" real,
    "confidence_tier" "text",
    "extracted_context" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "added_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "social_post_places_tier_check" CHECK ((("confidence_tier" IS NULL) OR ("confidence_tier" = ANY (ARRAY['high'::"text", 'medium'::"text", 'low'::"text"]))))
);


ALTER TABLE "public"."social_post_places" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."social_post_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "social_post_id" "uuid" NOT NULL,
    "shared_url" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "snoozed_at" timestamp with time zone,
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "social_post_reviews_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'later'::"text", 'reviewed'::"text", 'dismissed'::"text"])))
);


ALTER TABLE "public"."social_post_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."social_posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "canonical_url" "text" NOT NULL,
    "platform" "text" NOT NULL,
    "creator_handle" "text",
    "title" "text",
    "status" "text" DEFAULT 'processing'::"text" NOT NULL,
    "vibes" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "sentiment" "text",
    "evidence_flags" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "error" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "processed_at" timestamp with time zone,
    "caption" "text",
    "thumbnail_url" "text",
    CONSTRAINT "social_posts_platform_check" CHECK (("platform" = ANY (ARRAY['tiktok'::"text", 'instagram'::"text"]))),
    CONSTRAINT "social_posts_status_check" CHECK (("status" = ANY (ARRAY['processing'::"text", 'processed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."social_posts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tags" (
    "tag_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "text" "text",
    "prompt_description" "text",
    "tag_type" "text",
    "Colour" "text"
);


ALTER TABLE "public"."tags" OWNER TO "postgres";


COMMENT ON TABLE "public"."tags" IS 'Tags applicable to users and locations';



CREATE TABLE IF NOT EXISTS "public"."user_chat_state" (
    "user_id" "uuid" NOT NULL,
    "bubble_id" "uuid" NOT NULL,
    "last_read_at" timestamp with time zone DEFAULT "now"(),
    "muted" boolean DEFAULT false
);


ALTER TABLE "public"."user_chat_state" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."user_bubble_chats" WITH ("security_invoker"='true') AS
 SELECT "b"."bubble_id",
    "b"."name" AS "bubble_name",
    "ucs"."user_id",
    "ucs"."last_read_at",
    "ucs"."muted",
    COALESCE(( SELECT "count"(*) AS "count"
           FROM "public"."messages" "m"
          WHERE (("m"."bubble_id" = "b"."bubble_id") AND ("m"."created_at" > "ucs"."last_read_at") AND ("m"."is_deleted" = false) AND ("m"."sender_id" <> "ucs"."user_id"))), (0)::bigint) AS "unread_count",
    ( SELECT "json_build_object"('id', "m"."id", 'content', "m"."content", 'sender_id', "m"."sender_id", 'message_type', "m"."message_type", 'created_at', "m"."created_at") AS "json_build_object"
           FROM "public"."messages" "m"
          WHERE (("m"."bubble_id" = "b"."bubble_id") AND ("m"."is_deleted" = false))
          ORDER BY "m"."created_at" DESC
         LIMIT 1) AS "last_message",
    ( SELECT "max"("m"."created_at") AS "max"
           FROM "public"."messages" "m"
          WHERE (("m"."bubble_id" = "b"."bubble_id") AND ("m"."is_deleted" = false))) AS "last_message_at"
   FROM ("public"."bubbles" "b"
     JOIN "public"."user_chat_state" "ucs" ON (("b"."bubble_id" = "ucs"."bubble_id")));


ALTER TABLE "public"."user_bubble_chats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_friends" (
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "followee_id" "uuid" NOT NULL,
    "follower_id" "uuid" NOT NULL,
    "status" "public"."relationship_status",
    "influence" smallint
);


ALTER TABLE "public"."user_friends" OWNER TO "postgres";


COMMENT ON COLUMN "public"."user_friends"."status" IS 'relationship status';



CREATE TABLE IF NOT EXISTS "public"."user_location_actions" (
    "action_id" bigint NOT NULL,
    "location_id" bigint NOT NULL,
    "action" "public"."action_type" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "saved_method" "public"."saved_method",
    "preference" "public"."saved_method",
    "user_id" "uuid",
    "source_video_url" "text",
    "acked" boolean,
    "video_extras" "jsonb"
);


ALTER TABLE "public"."user_location_actions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."user_location_actions_action_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."user_location_actions_action_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."user_location_actions_action_id_seq" OWNED BY "public"."user_location_actions"."action_id";



CREATE TABLE IF NOT EXISTS "public"."user_recommendations" (
    "user_id" "uuid" NOT NULL,
    "location_id" bigint NOT NULL,
    "score" real NOT NULL,
    "generated_at" timestamp without time zone DEFAULT "now"(),
    "reason" "jsonb"
);


ALTER TABLE "public"."user_recommendations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."user_recommendations"."reason" IS 'Of form: {   "friend_influence": 0.5,   "social_popularity": 0.3,   "tag_similarity": 0.2 }';



CREATE TABLE IF NOT EXISTS "public"."v_action_exists" (
    "exists" boolean
);


ALTER TABLE "public"."v_action_exists" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."video_insights" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "source_video_url" "text" NOT NULL,
    "location_id" bigint NOT NULL,
    "key_dishes" "jsonb",
    "creator_notes" "text",
    "vibe_signals" "jsonb",
    "sentiment" "text",
    "creator_handle" "text",
    "video_description" "text",
    "extracted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "extraction_model" "text",
    "special_offers" "jsonb"
);


ALTER TABLE "public"."video_insights" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."waitlist" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "email" "text" NOT NULL
);


ALTER TABLE "public"."waitlist" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."worldcup_notification_drafts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "fixture_id" "text" NOT NULL,
    "match_utc" timestamp with time zone NOT NULL,
    "team_a" "text" NOT NULL,
    "team_b" "text" NOT NULL,
    "notif_type" "text" NOT NULL,
    "title_template" "text" NOT NULL,
    "body_template" "text" NOT NULL,
    "cuisine_a" "text",
    "cuisine_b" "text",
    "sample_preview" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "status" "text" DEFAULT 'pending_review'::"text" NOT NULL,
    "slack_message_ts" "text",
    "approved_by" "text",
    "sent_count" integer DEFAULT 0 NOT NULL,
    "send_window_minutes" integer DEFAULT 120 NOT NULL,
    "override_body" "text",
    CONSTRAINT "worldcup_notification_drafts_notif_type_check" CHECK (("notif_type" = ANY (ARRAY['watch'::"text", 'taste'::"text"]))),
    CONSTRAINT "worldcup_notification_drafts_status_check" CHECK (("status" = ANY (ARRAY['pending_review'::"text", 'approved'::"text", 'reviewing'::"text", 'rejected'::"text", 'sent'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."worldcup_notification_drafts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."worldcup_notification_recipients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "draft_id" "uuid" NOT NULL,
    "user_id" "text" NOT NULL,
    "fcm_token" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "sent_at" timestamp with time zone,
    CONSTRAINT "worldcup_notification_recipients_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'sent'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."worldcup_notification_recipients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rewards"."promo_code_vouchers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "referral_code_id" "uuid" NOT NULL,
    "campaign_key" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "merchant_name" "text" NOT NULL,
    "terms_text" "text",
    "discount_percent" integer DEFAULT 0 NOT NULL,
    "location_id" bigint,
    "is_single_use" boolean DEFAULT true NOT NULL,
    "expires_at" timestamp with time zone,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "promo_code_vouchers_campaign_key_check" CHECK (("btrim"("campaign_key") <> ''::"text")),
    CONSTRAINT "promo_code_vouchers_discount_percent_check" CHECK ((("discount_percent" >= 0) AND ("discount_percent" <= 100))),
    CONSTRAINT "promo_code_vouchers_merchant_name_check" CHECK (("btrim"("merchant_name") <> ''::"text")),
    CONSTRAINT "promo_code_vouchers_title_check" CHECK (("btrim"("title") <> ''::"text"))
);


ALTER TABLE "rewards"."promo_code_vouchers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rewards"."voucher_source_type_rules" (
    "source_type" "text" NOT NULL,
    "max_applications_per_user_per_campaign" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "voucher_source_type_rules_max_applications_per_user_per_c_check" CHECK (("max_applications_per_user_per_campaign" > 0)),
    CONSTRAINT "voucher_source_type_rules_source_type_check" CHECK (("source_type" = ANY (ARRAY['inviter_reward'::"text", 'invitee_reward'::"text", 'promo_reward'::"text"])))
);


ALTER TABLE "rewards"."voucher_source_type_rules" OWNER TO "postgres";


ALTER TABLE ONLY "public"."locations" ALTER COLUMN "location_id" SET DEFAULT "nextval"('"public"."locations_location_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."user_location_actions" ALTER COLUMN "action_id" SET DEFAULT "nextval"('"public"."user_location_actions_action_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."app_analytics_events"
    ADD CONSTRAINT "app_analytics_events_v2_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bubble_locations"
    ADD CONSTRAINT "bubble_locations_pkey" PRIMARY KEY ("bubble_location_id");



ALTER TABLE ONLY "public"."bubble_locations"
    ADD CONSTRAINT "bubble_locations_unique" UNIQUE ("bubble_id", "location_id");



ALTER TABLE ONLY "public"."bubble_members"
    ADD CONSTRAINT "bubble_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bubble_members"
    ADD CONSTRAINT "bubble_members_unique" UNIQUE ("bubble_id", "user_id");



ALTER TABLE ONLY "public"."bubbles"
    ADD CONSTRAINT "bubbles_pkey" PRIMARY KEY ("bubble_id");



ALTER TABLE ONLY "public"."collection_locations"
    ADD CONSTRAINT "collection_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."collection_locations"
    ADD CONSTRAINT "collection_locations_unique" UNIQUE ("collection_id", "location_id");



ALTER TABLE ONLY "public"."collection_saves"
    ADD CONSTRAINT "collection_saves_pkey" PRIMARY KEY ("user_id", "collection_id");



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "collections_pkey" PRIMARY KEY ("collection_id");



ALTER TABLE ONLY "public"."internal_alert_config"
    ADD CONSTRAINT "internal_alert_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."internal_alert_recipients"
    ADD CONSTRAINT "internal_alert_recipients_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."location_popularity_app"
    ADD CONSTRAINT "location_popularity_app_pkey" PRIMARY KEY ("location_id");



ALTER TABLE ONLY "public"."location_reviews"
    ADD CONSTRAINT "location_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."location_similarities"
    ADD CONSTRAINT "location_similarities_pkey" PRIMARY KEY ("location_id_a", "location_id_b");



ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "locations_pkey" PRIMARY KEY ("location_id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."social_post_actions"
    ADD CONSTRAINT "social_post_actions_pkey" PRIMARY KEY ("social_post_action_id");



ALTER TABLE ONLY "public"."social_post_place_reviews"
    ADD CONSTRAINT "social_post_place_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."social_post_place_reviews"
    ADD CONSTRAINT "social_post_place_reviews_user_place_key" UNIQUE ("user_id", "social_post_place_id");



ALTER TABLE ONLY "public"."social_post_places"
    ADD CONSTRAINT "social_post_places_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."social_post_reviews"
    ADD CONSTRAINT "social_post_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."social_post_reviews"
    ADD CONSTRAINT "social_post_reviews_user_post_key" UNIQUE ("user_id", "social_post_id");



ALTER TABLE ONLY "public"."social_posts"
    ADD CONSTRAINT "social_posts_canonical_url_key" UNIQUE ("canonical_url");



ALTER TABLE ONLY "public"."social_posts"
    ADD CONSTRAINT "social_posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_pkey" PRIMARY KEY ("tag_id");



ALTER TABLE ONLY "public"."user_location_actions"
    ADD CONSTRAINT "unique_user_location_action_type" UNIQUE ("user_id", "location_id", "action");



ALTER TABLE ONLY "public"."user_chat_state"
    ADD CONSTRAINT "user_chat_state_pkey" PRIMARY KEY ("user_id", "bubble_id");



ALTER TABLE ONLY "public"."user_friends"
    ADD CONSTRAINT "user_friends_pkey" PRIMARY KEY ("followee_id", "follower_id");



ALTER TABLE ONLY "public"."user_location_actions"
    ADD CONSTRAINT "user_location_actions_pkey" PRIMARY KEY ("action_id");



ALTER TABLE ONLY "public"."user_recommendations"
    ADD CONSTRAINT "user_recommendations_pkey" PRIMARY KEY ("user_id", "location_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("supabase_id");



ALTER TABLE ONLY "public"."video_insights"
    ADD CONSTRAINT "video_insights_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."video_insights"
    ADD CONSTRAINT "video_insights_unique_url_location" UNIQUE ("source_video_url", "location_id");



ALTER TABLE ONLY "public"."waitlist"
    ADD CONSTRAINT "waitlist_pkey" PRIMARY KEY ("email");



ALTER TABLE ONLY "public"."worldcup_notification_drafts"
    ADD CONSTRAINT "worldcup_notification_drafts_fixture_type_key" UNIQUE ("fixture_id", "notif_type");



ALTER TABLE ONLY "public"."worldcup_notification_drafts"
    ADD CONSTRAINT "worldcup_notification_drafts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."worldcup_notification_recipients"
    ADD CONSTRAINT "worldcup_notification_recipients_draft_user_key" UNIQUE ("draft_id", "user_id");



ALTER TABLE ONLY "public"."worldcup_notification_recipients"
    ADD CONSTRAINT "worldcup_notification_recipients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rewards"."promo_code_vouchers"
    ADD CONSTRAINT "promo_code_vouchers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rewards"."promo_code_vouchers"
    ADD CONSTRAINT "promo_code_vouchers_referral_code_id_campaign_key_key" UNIQUE ("referral_code_id", "campaign_key");



ALTER TABLE ONLY "rewards"."referral_codes"
    ADD CONSTRAINT "referral_codes_id_owner_user_id_key" UNIQUE ("id", "owner_user_id");



ALTER TABLE ONLY "rewards"."referral_codes"
    ADD CONSTRAINT "referral_codes_normalized_code_key" UNIQUE ("normalized_code");



ALTER TABLE ONLY "rewards"."referral_codes"
    ADD CONSTRAINT "referral_codes_owner_user_id_key" UNIQUE ("owner_user_id");



ALTER TABLE ONLY "rewards"."referral_codes"
    ADD CONSTRAINT "referral_codes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rewards"."referrals"
    ADD CONSTRAINT "referrals_invitee_user_id_key" UNIQUE ("invitee_user_id");



ALTER TABLE ONLY "rewards"."referrals"
    ADD CONSTRAINT "referrals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rewards"."voucher_source_type_rules"
    ADD CONSTRAINT "voucher_source_type_rules_pkey" PRIMARY KEY ("source_type");



ALTER TABLE ONLY "rewards"."vouchers"
    ADD CONSTRAINT "vouchers_pkey" PRIMARY KEY ("id");



CREATE INDEX "collection_saves_collection_id_idx" ON "public"."collection_saves" USING "btree" ("collection_id");



CREATE INDEX "collections_curated_city_idx" ON "public"."collections" USING "btree" ("curated_city") WHERE ("is_curated" = true);



CREATE INDEX "idx_app_analytics_events_event_name_occurred_at" ON "public"."app_analytics_events" USING "btree" ("event_name", "occurred_at" DESC);



CREATE INDEX "idx_app_analytics_events_occurred_at_desc" ON "public"."app_analytics_events" USING "btree" ("occurred_at" DESC);



CREATE INDEX "idx_loc_sim_a" ON "public"."location_similarities" USING "btree" ("location_id_a");



CREATE INDEX "idx_loc_sim_b" ON "public"."location_similarities" USING "btree" ("location_id_b");



CREATE INDEX "idx_locations_cuisine_primary_null_locid" ON "public"."locations" USING "btree" ("location_id") WHERE ("cuisine_primary" IS NULL);



CREATE INDEX "idx_locations_cuisine_trgm" ON "public"."locations" USING "gin" ("cuisine" "public"."gin_trgm_ops");



CREATE INDEX "idx_locations_geog" ON "public"."locations" USING "gist" ("geog");



CREATE INDEX "idx_locations_google_details_fetched_at" ON "public"."locations" USING "btree" ("google_details_fetched_at");



CREATE UNIQUE INDEX "idx_locations_google_place_id" ON "public"."locations" USING "btree" ("google_place_id");



CREATE INDEX "idx_locations_name_trgm" ON "public"."locations" USING "gin" ("name" "public"."gin_trgm_ops");



CREATE INDEX "idx_locations_processing_claimed_at" ON "public"."locations" USING "btree" ("location_processing_claimed_at") WHERE ("location_processing_claimed_at" IS NOT NULL);



CREATE INDEX "idx_locations_processing_queued_at" ON "public"."locations" USING "btree" ("location_processing_queued_at") WHERE ("location_processing_queued_at" IS NOT NULL);



CREATE INDEX "idx_locations_vibe_processing_started_at" ON "public"."locations" USING "btree" ("vibe_processing_started_at") WHERE ("vibe_processing_started_at" IS NOT NULL);



CREATE INDEX "idx_locations_vicinity_trgm" ON "public"."locations" USING "gin" ("vicinity" "public"."gin_trgm_ops");



CREATE INDEX "idx_lpa_geog" ON "public"."location_popularity_app" USING "gist" ("geog");



CREATE INDEX "idx_lpa_share_count" ON "public"."location_popularity_app" USING "btree" ("share_count" DESC);



CREATE INDEX "idx_messages_bubble_created" ON "public"."messages" USING "btree" ("bubble_id", "created_at" DESC);



CREATE INDEX "idx_messages_created" ON "public"."messages" USING "btree" ("created_at");



CREATE INDEX "idx_messages_location_id" ON "public"."messages" USING "btree" ("location_id") WHERE ("location_id" IS NOT NULL);



CREATE INDEX "idx_messages_replied_to" ON "public"."messages" USING "btree" ("replied_to_message_id") WHERE ("replied_to_message_id" IS NOT NULL);



CREATE INDEX "idx_messages_sender" ON "public"."messages" USING "btree" ("sender_id");



CREATE INDEX "idx_notifications_metadata" ON "public"."notifications" USING "gin" ("metadata");



CREATE INDEX "idx_notifications_user_unread_recent" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC) WHERE ("is_read" = false);



CREATE INDEX "idx_user_chat_state_bubble" ON "public"."user_chat_state" USING "btree" ("bubble_id");



CREATE INDEX "idx_user_chat_state_user" ON "public"."user_chat_state" USING "btree" ("user_id");



CREATE INDEX "idx_user_location_actions_user_count" ON "public"."user_location_actions" USING "btree" ("user_id");



CREATE INDEX "idx_video_insights_location" ON "public"."video_insights" USING "btree" ("location_id");



CREATE INDEX "idx_video_insights_url" ON "public"."video_insights" USING "btree" ("source_video_url");



CREATE INDEX "lpa_location_id_quality" ON "public"."location_popularity_app" USING "btree" ("location_id") INCLUDE ("quality_score");



CREATE INDEX "notifications_user_visible_recent_idx" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC) WHERE ("dismissed_at" IS NULL);



CREATE UNIQUE INDEX "social_post_actions_normalized_url_key" ON "public"."social_post_actions" USING "btree" ("normalized_url");



CREATE INDEX "social_post_actions_platform_idx" ON "public"."social_post_actions" USING "btree" ("platform");



CREATE INDEX "social_post_place_reviews_corrected_location_idx" ON "public"."social_post_place_reviews" USING "btree" ("corrected_location_id") WHERE ("corrected_location_id" IS NOT NULL);



CREATE INDEX "social_post_place_reviews_location_idx" ON "public"."social_post_place_reviews" USING "btree" ("location_id") WHERE ("location_id" IS NOT NULL);



CREATE INDEX "social_post_place_reviews_place_idx" ON "public"."social_post_place_reviews" USING "btree" ("social_post_place_id");



CREATE INDEX "social_post_place_reviews_user_idx" ON "public"."social_post_place_reviews" USING "btree" ("user_id");



CREATE INDEX "social_post_places_added_by_idx" ON "public"."social_post_places" USING "btree" ("added_by") WHERE ("added_by" IS NOT NULL);



CREATE INDEX "social_post_places_location_idx" ON "public"."social_post_places" USING "btree" ("location_id") WHERE ("location_id" IS NOT NULL);



CREATE INDEX "social_post_places_post_idx" ON "public"."social_post_places" USING "btree" ("social_post_id");



CREATE UNIQUE INDEX "social_post_places_post_place_key" ON "public"."social_post_places" USING "btree" ("social_post_id", "google_place_id") WHERE ("google_place_id" IS NOT NULL);



CREATE INDEX "social_post_reviews_post_idx" ON "public"."social_post_reviews" USING "btree" ("social_post_id");



CREATE INDEX "social_post_reviews_user_status_idx" ON "public"."social_post_reviews" USING "btree" ("user_id", "status");



CREATE INDEX "worldcup_notification_drafts_match_utc_idx" ON "public"."worldcup_notification_drafts" USING "btree" ("match_utc");



CREATE INDEX "worldcup_notification_drafts_status_idx" ON "public"."worldcup_notification_drafts" USING "btree" ("status");



CREATE INDEX "worldcup_notification_recipients_draft_idx" ON "public"."worldcup_notification_recipients" USING "btree" ("draft_id");



CREATE UNIQUE INDEX "vouchers_source_referral_user_type_unique_idx" ON "rewards"."vouchers" USING "btree" ("source_referral_id", "user_id", "source_type", "campaign_key") WHERE ("source_referral_id" IS NOT NULL);



CREATE UNIQUE INDEX "vouchers_user_campaign_type_available_unique_idx" ON "rewards"."vouchers" USING "btree" ("user_id", "campaign_key", "source_type") WHERE ("status" = 'available'::"text");



CREATE OR REPLACE TRIGGER "locations_propagate_geog_trg" AFTER UPDATE OF "geog" ON "public"."locations" FOR EACH ROW EXECUTE FUNCTION "public"."trg_locations_propagate_geog"();



CREATE OR REPLACE TRIGGER "locations_set_geog_trg" BEFORE INSERT OR UPDATE OF "lat", "lng", "geog" ON "public"."locations" FOR EACH ROW EXECUTE FUNCTION "public"."trg_locations_set_geog"();



CREATE OR REPLACE TRIGGER "lpa_fill_geog_trg" BEFORE INSERT OR UPDATE OF "location_id" ON "public"."location_popularity_app" FOR EACH ROW EXECUTE FUNCTION "public"."trg_lpa_fill_geog"();



CREATE OR REPLACE TRIGGER "on_bubble_member_added" AFTER INSERT ON "public"."bubble_members" FOR EACH ROW EXECUTE FUNCTION "public"."initialize_chat_state_for_new_member"();



CREATE OR REPLACE TRIGGER "on_message_created" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."notify_new_message"();



CREATE OR REPLACE TRIGGER "social_post_place_reviews_updated_at_trigger" BEFORE UPDATE ON "public"."social_post_place_reviews" FOR EACH ROW EXECUTE FUNCTION "public"."touch_social_review_updated_at"();



CREATE OR REPLACE TRIGGER "social_post_reviews_updated_at_trigger" BEFORE UPDATE ON "public"."social_post_reviews" FOR EACH ROW EXECUTE FUNCTION "public"."touch_social_review_updated_at"();



CREATE OR REPLACE TRIGGER "social_posts_updated_at_trigger" BEFORE UPDATE ON "public"."social_posts" FOR EACH ROW EXECUTE FUNCTION "public"."touch_social_review_updated_at"();



CREATE OR REPLACE TRIGGER "trg_notify_no_recommendations_in_area_internal" AFTER INSERT ON "public"."app_analytics_events" FOR EACH ROW EXECUTE FUNCTION "public"."notify_no_recommendations_in_area_internal"();



CREATE OR REPLACE TRIGGER "user_location_actions_share_count_trg" AFTER INSERT OR DELETE OR UPDATE ON "public"."user_location_actions" FOR EACH ROW EXECUTE FUNCTION "public"."trg_user_location_actions_share_count"();



CREATE OR REPLACE TRIGGER "referral_codes_set_updated_at" BEFORE UPDATE ON "rewards"."referral_codes" FOR EACH ROW EXECUTE FUNCTION "rewards"."set_updated_at"();



CREATE OR REPLACE TRIGGER "voucher_source_type_rules_set_updated_at" BEFORE UPDATE ON "rewards"."voucher_source_type_rules" FOR EACH ROW EXECUTE FUNCTION "rewards"."set_updated_at"();



ALTER TABLE ONLY "public"."app_analytics_events"
    ADD CONSTRAINT "app_analytics_events_v2_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bubble_locations"
    ADD CONSTRAINT "bubble_locations_added_by_fkey" FOREIGN KEY ("added_by") REFERENCES "public"."users"("supabase_id");



ALTER TABLE ONLY "public"."bubble_locations"
    ADD CONSTRAINT "bubble_locations_bubble_id_fkey" FOREIGN KEY ("bubble_id") REFERENCES "public"."bubbles"("bubble_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bubble_locations"
    ADD CONSTRAINT "bubble_locations_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bubble_members"
    ADD CONSTRAINT "bubble_members_bubble_id_fkey" FOREIGN KEY ("bubble_id") REFERENCES "public"."bubbles"("bubble_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bubble_members"
    ADD CONSTRAINT "bubble_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bubbles"
    ADD CONSTRAINT "bubbles_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("supabase_id");



ALTER TABLE ONLY "public"."collection_locations"
    ADD CONSTRAINT "collection_locations_added_by_fkey" FOREIGN KEY ("added_by") REFERENCES "public"."users"("supabase_id");



ALTER TABLE ONLY "public"."collection_locations"
    ADD CONSTRAINT "collection_locations_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "public"."collections"("collection_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."collection_locations"
    ADD CONSTRAINT "collection_locations_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id");



ALTER TABLE ONLY "public"."collection_saves"
    ADD CONSTRAINT "collection_saves_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "public"."collections"("collection_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."collection_saves"
    ADD CONSTRAINT "collection_saves_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "collections_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("supabase_id");



ALTER TABLE ONLY "public"."internal_alert_recipients"
    ADD CONSTRAINT "internal_alert_recipients_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."location_popularity_app"
    ADD CONSTRAINT "location_popularity_app_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id");



ALTER TABLE ONLY "public"."location_reviews"
    ADD CONSTRAINT "location_reviews_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."location_reviews"
    ADD CONSTRAINT "location_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id");



ALTER TABLE ONLY "public"."location_similarities"
    ADD CONSTRAINT "location_similarities_location_id_a_fkey" FOREIGN KEY ("location_id_a") REFERENCES "public"."locations"("location_id");



ALTER TABLE ONLY "public"."location_similarities"
    ADD CONSTRAINT "location_similarities_location_id_b_fkey" FOREIGN KEY ("location_id_b") REFERENCES "public"."locations"("location_id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_bubble_id_fkey" FOREIGN KEY ("bubble_id") REFERENCES "public"."bubbles"("bubble_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_replied_to_message_id_fkey" FOREIGN KEY ("replied_to_message_id") REFERENCES "public"."messages"("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."users"("supabase_id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."social_post_actions"
    ADD CONSTRAINT "social_post_actions_eat_list_collection_id_fkey" FOREIGN KEY ("eat_list_collection_id") REFERENCES "public"."collections"("collection_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."social_post_place_reviews"
    ADD CONSTRAINT "social_post_place_reviews_corrected_location_fkey" FOREIGN KEY ("corrected_location_id") REFERENCES "public"."locations"("location_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."social_post_place_reviews"
    ADD CONSTRAINT "social_post_place_reviews_location_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."social_post_place_reviews"
    ADD CONSTRAINT "social_post_place_reviews_place_fkey" FOREIGN KEY ("social_post_place_id") REFERENCES "public"."social_post_places"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."social_post_place_reviews"
    ADD CONSTRAINT "social_post_place_reviews_user_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."social_post_places"
    ADD CONSTRAINT "social_post_places_added_by_fkey" FOREIGN KEY ("added_by") REFERENCES "public"."users"("supabase_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."social_post_places"
    ADD CONSTRAINT "social_post_places_location_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."social_post_places"
    ADD CONSTRAINT "social_post_places_post_fkey" FOREIGN KEY ("social_post_id") REFERENCES "public"."social_posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."social_post_reviews"
    ADD CONSTRAINT "social_post_reviews_post_fkey" FOREIGN KEY ("social_post_id") REFERENCES "public"."social_posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."social_post_reviews"
    ADD CONSTRAINT "social_post_reviews_user_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_chat_state"
    ADD CONSTRAINT "user_chat_state_bubble_id_fkey" FOREIGN KEY ("bubble_id") REFERENCES "public"."bubbles"("bubble_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_chat_state"
    ADD CONSTRAINT "user_chat_state_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_friends"
    ADD CONSTRAINT "user_friends_followee_id_fkey" FOREIGN KEY ("followee_id") REFERENCES "public"."users"("supabase_id");



ALTER TABLE ONLY "public"."user_friends"
    ADD CONSTRAINT "user_friends_follower_id_fkey" FOREIGN KEY ("follower_id") REFERENCES "public"."users"("supabase_id");



ALTER TABLE ONLY "public"."user_location_actions"
    ADD CONSTRAINT "user_location_actions_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id");



ALTER TABLE ONLY "public"."user_location_actions"
    ADD CONSTRAINT "user_location_actions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_recommendations"
    ADD CONSTRAINT "user_recommendations_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id");



ALTER TABLE ONLY "public"."user_recommendations"
    ADD CONSTRAINT "user_recommendations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id");



ALTER TABLE ONLY "public"."video_insights"
    ADD CONSTRAINT "video_insights_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id");



ALTER TABLE ONLY "public"."worldcup_notification_recipients"
    ADD CONSTRAINT "worldcup_notification_recipients_draft_id_fkey" FOREIGN KEY ("draft_id") REFERENCES "public"."worldcup_notification_drafts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rewards"."promo_code_vouchers"
    ADD CONSTRAINT "promo_code_vouchers_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id") ON DELETE SET NULL;



ALTER TABLE ONLY "rewards"."promo_code_vouchers"
    ADD CONSTRAINT "promo_code_vouchers_referral_code_id_fkey" FOREIGN KEY ("referral_code_id") REFERENCES "rewards"."referral_codes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rewards"."referral_codes"
    ADD CONSTRAINT "referral_codes_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "rewards"."referrals"
    ADD CONSTRAINT "referrals_invitee_user_id_fkey" FOREIGN KEY ("invitee_user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "rewards"."referrals"
    ADD CONSTRAINT "referrals_inviter_user_id_fkey" FOREIGN KEY ("inviter_user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



ALTER TABLE ONLY "rewards"."referrals"
    ADD CONSTRAINT "referrals_referral_code_id_fkey" FOREIGN KEY ("referral_code_id") REFERENCES "rewards"."referral_codes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "rewards"."referrals"
    ADD CONSTRAINT "referrals_referral_code_id_inviter_user_id_fkey" FOREIGN KEY ("referral_code_id", "inviter_user_id") REFERENCES "rewards"."referral_codes"("id", "owner_user_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "rewards"."vouchers"
    ADD CONSTRAINT "vouchers_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("location_id") ON DELETE SET NULL;



ALTER TABLE ONLY "rewards"."vouchers"
    ADD CONSTRAINT "vouchers_source_referral_id_fkey" FOREIGN KEY ("source_referral_id") REFERENCES "rewards"."referrals"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "rewards"."vouchers"
    ADD CONSTRAINT "vouchers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("supabase_id") ON DELETE CASCADE;



CREATE POLICY "Anyone can view app popularity" ON "public"."location_popularity_app" FOR SELECT USING (true);



CREATE POLICY "Anyone can view friend relationships" ON "public"."user_friends" FOR SELECT USING (true);



CREATE POLICY "Anyone can view locations" ON "public"."locations" FOR SELECT USING (true);



CREATE POLICY "Anyone can view public bubble locations" ON "public"."bubble_locations" FOR SELECT USING (("bubble_id" IN ( SELECT "bubbles"."bubble_id"
   FROM "public"."bubbles"
  WHERE ("bubbles"."is_private" = false))));



CREATE POLICY "Anyone can view public bubbles" ON "public"."bubbles" FOR SELECT USING (("is_private" = false));



CREATE POLICY "Anyone can view tags" ON "public"."tags" FOR SELECT USING (true);



CREATE POLICY "Anyone can view user profiles" ON "public"."users" FOR SELECT USING (true);



CREATE POLICY "Authenticated users can create bubbles" ON "public"."bubbles" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "created_by"));



CREATE POLICY "Bubble creators can add members" ON "public"."bubble_members" FOR INSERT TO "authenticated" WITH CHECK (("bubble_id" IN ( SELECT "bubbles"."bubble_id"
   FROM "public"."bubbles"
  WHERE ("bubbles"."created_by" = "auth"."uid"()))));



CREATE POLICY "Bubble creators can remove members" ON "public"."bubble_members" FOR DELETE TO "authenticated" USING (("bubble_id" IN ( SELECT "bubbles"."bubble_id"
   FROM "public"."bubbles"
  WHERE ("bubbles"."created_by" = "auth"."uid"()))));



CREATE POLICY "Creators can delete their bubbles" ON "public"."bubbles" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "created_by"));



CREATE POLICY "Creators can update their bubbles" ON "public"."bubbles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "created_by")) WITH CHECK (("auth"."uid"() = "created_by"));



CREATE POLICY "Members can add locations to their bubbles" ON "public"."bubble_locations" FOR INSERT TO "authenticated" WITH CHECK ((("bubble_id" IN ( SELECT "bubble_members"."bubble_id"
   FROM "public"."bubble_members"
  WHERE ("bubble_members"."user_id" = "auth"."uid"()))) AND ("auth"."uid"() = "added_by")));



CREATE POLICY "Members can view private bubble locations" ON "public"."bubble_locations" FOR SELECT TO "authenticated" USING (("bubble_id" IN ( SELECT "bubble_members"."bubble_id"
   FROM "public"."bubble_members"
  WHERE ("bubble_members"."user_id" = "auth"."uid"()))));



CREATE POLICY "Members can view their private bubbles" ON "public"."bubbles" FOR SELECT TO "authenticated" USING (("bubble_id" IN ( SELECT "bubble_members"."bubble_id"
   FROM "public"."bubble_members"
  WHERE ("bubble_members"."user_id" = "auth"."uid"()))));



CREATE POLICY "System can create messages" ON "public"."messages" FOR INSERT WITH CHECK (false);



CREATE POLICY "System can insert recommendations" ON "public"."user_recommendations" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "System can manage chat state" ON "public"."user_chat_state" USING (false);



CREATE POLICY "System can update messages" ON "public"."messages" FOR UPDATE USING (false);



CREATE POLICY "Users can add places to posts they shared" ON "public"."social_post_places" FOR INSERT TO "authenticated" WITH CHECK ((("added_by" = ( SELECT "auth"."uid"() AS "uid")) AND (EXISTS ( SELECT 1
   FROM "public"."social_post_reviews" "review"
  WHERE (("review"."social_post_id" = "social_post_places"."social_post_id") AND ("review"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Users can create friendships" ON "public"."user_friends" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "follower_id"));



CREATE POLICY "Users can delete locations they added" ON "public"."bubble_locations" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "added_by"));



CREATE POLICY "Users can delete own actions" ON "public"."user_location_actions" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own recommendations" ON "public"."user_recommendations" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their friendships" ON "public"."user_friends" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "follower_id"));



CREATE POLICY "Users can insert own actions" ON "public"."user_location_actions" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile during signup" ON "public"."users" FOR INSERT WITH CHECK (("auth"."uid"() = "supabase_id"));



CREATE POLICY "Users can insert their own place reviews" ON "public"."social_post_place_reviews" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can read places for posts they shared" ON "public"."social_post_places" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."social_post_reviews" "review"
  WHERE (("review"."social_post_id" = "social_post_places"."social_post_id") AND ("review"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Users can read posts they shared" ON "public"."social_posts" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."social_post_reviews" "review"
  WHERE (("review"."social_post_id" = "social_posts"."id") AND ("review"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Users can read their own place reviews" ON "public"."social_post_place_reviews" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can read their own post reviews" ON "public"."social_post_reviews" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can save collections" ON "public"."collection_saves" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() IS NOT NULL) AND ("auth"."uid"() = "user_id")));



CREATE POLICY "Users can unsave collections" ON "public"."collection_saves" FOR DELETE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND ("auth"."uid"() = "user_id")));



CREATE POLICY "Users can update own actions" ON "public"."user_location_actions" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile" ON "public"."users" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "supabase_id")) WITH CHECK (("auth"."uid"() = "supabase_id"));



CREATE POLICY "Users can update their friendships" ON "public"."user_friends" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() = "follower_id") OR ("auth"."uid"() = "followee_id"))) WITH CHECK ((("auth"."uid"() = "follower_id") OR ("auth"."uid"() = "followee_id")));



CREATE POLICY "Users can update their own place reviews" ON "public"."social_post_place_reviews" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own post reviews" ON "public"."social_post_reviews" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view messages in their bubbles" ON "public"."messages" FOR SELECT USING (("bubble_id" IN ( SELECT "bubble_members"."bubble_id"
   FROM "public"."bubble_members"
  WHERE ("bubble_members"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view own actions" ON "public"."user_location_actions" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own recommendations" ON "public"."user_recommendations" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own saved collections" ON "public"."collection_saves" FOR SELECT TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND ("auth"."uid"() = "user_id")));



CREATE POLICY "Users can view their own chat state" ON "public"."user_chat_state" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view their own membership" ON "public"."bubble_members" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "allow insert" ON "public"."location_popularity_app" FOR INSERT WITH CHECK (true);



ALTER TABLE "public"."app_analytics_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "app_analytics_events_no_delete_anon" ON "public"."app_analytics_events" FOR DELETE TO "anon" USING (false);



CREATE POLICY "app_analytics_events_no_delete_authenticated" ON "public"."app_analytics_events" FOR DELETE TO "authenticated" USING (false);



CREATE POLICY "app_analytics_events_no_insert_anon" ON "public"."app_analytics_events" FOR INSERT TO "anon" WITH CHECK (false);



CREATE POLICY "app_analytics_events_no_insert_authenticated" ON "public"."app_analytics_events" FOR INSERT TO "authenticated" WITH CHECK (false);



CREATE POLICY "app_analytics_events_no_read_anon" ON "public"."app_analytics_events" FOR SELECT TO "anon" USING (false);



CREATE POLICY "app_analytics_events_no_read_authenticated" ON "public"."app_analytics_events" FOR SELECT TO "authenticated" USING (false);



CREATE POLICY "app_analytics_events_no_update_anon" ON "public"."app_analytics_events" FOR UPDATE TO "anon" USING (false) WITH CHECK (false);



CREATE POLICY "app_analytics_events_no_update_authenticated" ON "public"."app_analytics_events" FOR UPDATE TO "authenticated" USING (false) WITH CHECK (false);



ALTER TABLE "public"."bubble_locations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bubble_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bubbles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."collection_locations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "collection_locations_select" ON "public"."collection_locations" FOR SELECT TO "authenticated" USING ((("added_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."collections" "c"
  WHERE (("c"."collection_id" = "collection_locations"."collection_id") AND (("c"."created_by" = "auth"."uid"()) OR "c"."is_public" OR "c"."is_curated"))))));



CREATE POLICY "collection_locations_write_own_collection" ON "public"."collection_locations" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."collections" "c"
  WHERE (("c"."collection_id" = "collection_locations"."collection_id") AND ("c"."created_by" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."collections" "c"
  WHERE (("c"."collection_id" = "collection_locations"."collection_id") AND ("c"."created_by" = "auth"."uid"())))));



ALTER TABLE "public"."collection_saves" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."collections" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "collections_delete_own" ON "public"."collections" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "collections_insert_own" ON "public"."collections" FOR INSERT TO "authenticated" WITH CHECK (("created_by" = "auth"."uid"()));



CREATE POLICY "collections_select_own_or_public" ON "public"."collections" FOR SELECT TO "authenticated" USING ((("created_by" = "auth"."uid"()) OR "is_public" OR "is_curated"));



CREATE POLICY "collections_update_own" ON "public"."collections" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"())) WITH CHECK (("created_by" = "auth"."uid"()));



ALTER TABLE "public"."location_popularity_app" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."location_reviews" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "location_reviews_delete" ON "public"."location_reviews" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "location_reviews_insert" ON "public"."location_reviews" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "location_reviews_select" ON "public"."location_reviews" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR ("private" = false)));



CREATE POLICY "location_reviews_update" ON "public"."location_reviews" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."location_similarities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."locations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_delete_own" ON "public"."notifications" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "notifications_insert_own" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "notifications_select_own" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "notifications_update_own" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."social_post_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."social_post_place_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."social_post_places" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."social_post_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."social_posts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_chat_state" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_friends" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_location_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_recommendations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v_action_exists" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."video_insights" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "video_insights_select_all" ON "public"."video_insights" FOR SELECT USING (true);



ALTER TABLE "public"."waitlist" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."worldcup_notification_drafts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."worldcup_notification_recipients" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Users can read their own referral activity" ON "rewards"."referrals" FOR SELECT TO "authenticated" USING ((("inviter_user_id" = "auth"."uid"()) OR ("invitee_user_id" = "auth"."uid"())));



CREATE POLICY "Users can read their own referral codes" ON "rewards"."referral_codes" FOR SELECT TO "authenticated" USING (("owner_user_id" = "auth"."uid"()));



CREATE POLICY "Users can read their own vouchers" ON "rewards"."vouchers" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "rewards"."promo_code_vouchers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "rewards"."referral_codes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "rewards"."referrals" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "rewards"."voucher_source_type_rules" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "rewards"."vouchers" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."bubble_members";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."locations";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."messages";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."notifications";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."social_post_reviews";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."user_chat_state";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."user_location_actions";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






GRANT USAGE ON SCHEMA "rewards" TO "authenticated";
GRANT USAGE ON SCHEMA "rewards" TO "service_role";















GRANT ALL ON FUNCTION "public"."box2d_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2d_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."box2d_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2d_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2d_out"("public"."box2d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2d_out"("public"."box2d") TO "anon";
GRANT ALL ON FUNCTION "public"."box2d_out"("public"."box2d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2d_out"("public"."box2d") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2df_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2df_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."box2df_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2df_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2df_out"("public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2df_out"("public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."box2df_out"("public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2df_out"("public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."box3d_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3d_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."box3d_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3d_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."box3d_out"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3d_out"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."box3d_out"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3d_out"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_analyze"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_analyze"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_analyze"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_analyze"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_out"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_out"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_out"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_out"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_send"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_send"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_send"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_send"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_typmod_out"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_typmod_out"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_typmod_out"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_typmod_out"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_analyze"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_analyze"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_analyze"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_analyze"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_out"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_out"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_out"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_out"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_recv"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_recv"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_recv"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_recv"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_send"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_send"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_send"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_send"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_typmod_out"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_typmod_out"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_typmod_out"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_typmod_out"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."gidx_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gidx_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gidx_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gidx_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gidx_out"("public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."gidx_out"("public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."gidx_out"("public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gidx_out"("public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "service_role";



GRANT ALL ON FUNCTION "public"."spheroid_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."spheroid_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."spheroid_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spheroid_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."spheroid_out"("public"."spheroid") TO "postgres";
GRANT ALL ON FUNCTION "public"."spheroid_out"("public"."spheroid") TO "anon";
GRANT ALL ON FUNCTION "public"."spheroid_out"("public"."spheroid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spheroid_out"("public"."spheroid") TO "service_role";



GRANT ALL ON FUNCTION "public"."box3d"("public"."box2d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3d"("public"."box2d") TO "anon";
GRANT ALL ON FUNCTION "public"."box3d"("public"."box2d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3d"("public"."box2d") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("public"."box2d") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box2d") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box2d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box2d") TO "service_role";



GRANT ALL ON FUNCTION "public"."box"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."box"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2d"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2d"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."box2d"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2d"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."geography"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."bytea"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography"("public"."geography", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography"("public"."geography", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."geography"("public"."geography", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography"("public"."geography", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."box"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."box"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."box"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."box2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."box3d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."box3d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."bytea"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geography"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("public"."geometry", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geometry", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geometry", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geometry", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."json"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."json"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."json"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."json"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."jsonb"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."jsonb"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."jsonb"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."jsonb"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."path"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."path"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."path"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."path"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."point"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."point"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."point"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."point"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."polygon"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."polygon"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."polygon"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."polygon"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."text"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."text"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."text"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."text"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("path") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("path") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("path") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("path") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("point") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("point") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("point") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("point") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("polygon") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("polygon") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("polygon") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("polygon") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("text") TO "service_role";




































































































































































































































































































































GRANT ALL ON FUNCTION "public"."_postgis_deprecate"("oldname" "text", "newname" "text", "version" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_deprecate"("oldname" "text", "newname" "text", "version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_deprecate"("oldname" "text", "newname" "text", "version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_deprecate"("oldname" "text", "newname" "text", "version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_index_extent"("tbl" "regclass", "col" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_index_extent"("tbl" "regclass", "col" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_index_extent"("tbl" "regclass", "col" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_index_extent"("tbl" "regclass", "col" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_join_selectivity"("regclass", "text", "regclass", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_join_selectivity"("regclass", "text", "regclass", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_join_selectivity"("regclass", "text", "regclass", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_join_selectivity"("regclass", "text", "regclass", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_pgsql_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_pgsql_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_pgsql_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_pgsql_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_scripts_pgsql_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_scripts_pgsql_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_scripts_pgsql_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_scripts_pgsql_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_selectivity"("tbl" "regclass", "att_name" "text", "geom" "public"."geometry", "mode" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_selectivity"("tbl" "regclass", "att_name" "text", "geom" "public"."geometry", "mode" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_selectivity"("tbl" "regclass", "att_name" "text", "geom" "public"."geometry", "mode" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_selectivity"("tbl" "regclass", "att_name" "text", "geom" "public"."geometry", "mode" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_stats"("tbl" "regclass", "att_name" "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_stats"("tbl" "regclass", "att_name" "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_stats"("tbl" "regclass", "att_name" "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_stats"("tbl" "regclass", "att_name" "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_asgml"(integer, "public"."geometry", integer, integer, "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_asgml"(integer, "public"."geometry", integer, integer, "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_asgml"(integer, "public"."geometry", integer, integer, "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_asgml"(integer, "public"."geometry", integer, integer, "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_asx3d"(integer, "public"."geometry", integer, integer, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_asx3d"(integer, "public"."geometry", integer, integer, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_asx3d"(integer, "public"."geometry", integer, integer, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_asx3d"(integer, "public"."geometry", integer, integer, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography", double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography", double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography", double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography", double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_expand"("public"."geography", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_expand"("public"."geography", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_expand"("public"."geography", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_expand"("public"."geography", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_geomfromgml"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_geomfromgml"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_geomfromgml"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_geomfromgml"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_pointoutside"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_pointoutside"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_pointoutside"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_pointoutside"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_sortablehash"("geom" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_sortablehash"("geom" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_sortablehash"("geom" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_sortablehash"("geom" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_voronoi"("g1" "public"."geometry", "clip" "public"."geometry", "tolerance" double precision, "return_polygons" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_voronoi"("g1" "public"."geometry", "clip" "public"."geometry", "tolerance" double precision, "return_polygons" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_voronoi"("g1" "public"."geometry", "clip" "public"."geometry", "tolerance" double precision, "return_polygons" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_voronoi"("g1" "public"."geometry", "clip" "public"."geometry", "tolerance" double precision, "return_polygons" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."accept_friendship"("request_from_id" "uuid", "user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."accept_friendship"("request_from_id" "uuid", "user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_friendship"("request_from_id" "uuid", "user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."acknowledge_location"("p_user_id" "uuid", "p_location_id" integer, "p_acked" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."acknowledge_location"("p_user_id" "uuid", "p_location_id" integer, "p_acked" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."acknowledge_location"("p_user_id" "uuid", "p_location_id" integer, "p_acked" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."add_bubble_location"("p_bubble_id" "uuid", "p_location_id" bigint, "p_added_by" "uuid", "p_note" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_bubble_location"("p_bubble_id" "uuid", "p_location_id" bigint, "p_added_by" "uuid", "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_bubble_location"("p_bubble_id" "uuid", "p_location_id" bigint, "p_added_by" "uuid", "p_note" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_bubble_member"("p_bubble_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."add_bubble_member"("p_bubble_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_bubble_member"("p_bubble_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_location_to_collection"("p_collection_id" "uuid", "p_location_id" bigint, "p_note" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_location_to_collection"("p_collection_id" "uuid", "p_location_id" bigint, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_location_to_collection"("p_collection_id" "uuid", "p_location_id" bigint, "p_note" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_user_tags"("p_user_id" "uuid", "p_tag_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."add_user_tags"("p_user_id" "uuid", "p_tag_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_user_tags"("p_user_id" "uuid", "p_tag_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."addauth"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."addauth"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."addauth"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."addauth"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_delete_users"("p_user_ids" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_delete_users"("p_user_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."backfill_app_signal_pillars"() TO "anon";
GRANT ALL ON FUNCTION "public"."backfill_app_signal_pillars"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."backfill_app_signal_pillars"() TO "service_role";



GRANT ALL ON FUNCTION "public"."backfill_locations_geog"() TO "anon";
GRANT ALL ON FUNCTION "public"."backfill_locations_geog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."backfill_locations_geog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."backfill_lpa_geog"() TO "anon";
GRANT ALL ON FUNCTION "public"."backfill_lpa_geog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."backfill_lpa_geog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."block_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."block_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."block_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."box3dtobox"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3dtobox"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."box3dtobox"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3dtobox"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."bubble_compatibility_score"("p_bubble_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."bubble_compatibility_score"("p_bubble_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bubble_compatibility_score"("p_bubble_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_interaction_weight"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_interaction_weight"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_interaction_weight"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_tag_affinity_delta"("p_current_affinity" numeric, "p_location_tag_score" integer, "p_value" integer, "p_weight" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_tag_affinity_delta"("p_current_affinity" numeric, "p_location_tag_score" integer, "p_value" integer, "p_weight" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_tag_affinity_delta"("p_current_affinity" numeric, "p_location_tag_score" integer, "p_value" integer, "p_weight" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."centered_cosine_similarity"("vec1" integer[], "vec2" integer[]) TO "anon";
GRANT ALL ON FUNCTION "public"."centered_cosine_similarity"("vec1" integer[], "vec2" integer[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."centered_cosine_similarity"("vec1" integer[], "vec2" integer[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."checkauth"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."checkauth"("text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."checkauthtrigger"() TO "postgres";
GRANT ALL ON FUNCTION "public"."checkauthtrigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."checkauthtrigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."checkauthtrigger"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."claim_location_processing"("p_location_id" integer, "p_request_id" "text", "p_cooldown_seconds" integer, "p_claim_stale_after_seconds" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."claim_location_processing"("p_location_id" integer, "p_request_id" "text", "p_cooldown_seconds" integer, "p_claim_stale_after_seconds" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."claim_location_vibe_processing"("p_location_id" integer, "p_request_id" "text", "p_stale_after_seconds" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."claim_location_vibe_processing"("p_location_id" integer, "p_request_id" "text", "p_stale_after_seconds" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."cleanup_old_app_analytics_events"("p_retention" interval) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cleanup_old_app_analytics_events"("p_retention" interval) TO "service_role";



REVOKE ALL ON FUNCTION "public"."complete_location_processing_queue"("p_location_id" integer, "p_request_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."complete_location_processing_queue"("p_location_id" integer, "p_request_id" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."complete_signup_wizard"("p_user_id" "uuid", "p_spice_tolerance" integer, "p_dietary_tag_ids" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."complete_signup_wizard"("p_user_id" "uuid", "p_spice_tolerance" integer, "p_dietary_tag_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_signup_wizard"("p_user_id" "uuid", "p_spice_tolerance" integer, "p_dietary_tag_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_app_engagement_score"("p_saves_count" integer, "p_dislikes_count" integer, "p_been_to_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_app_engagement_score"("p_saves_count" integer, "p_dislikes_count" integer, "p_been_to_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_app_engagement_score"("p_saves_count" integer, "p_dislikes_count" integer, "p_been_to_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_google_baseline_score"("p_rating" double precision, "p_user_ratings_total" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_google_baseline_score"("p_rating" double precision, "p_user_ratings_total" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_google_baseline_score"("p_rating" double precision, "p_user_ratings_total" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_location_quality_score"("p_location_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_location_quality_score"("p_location_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_location_quality_score"("p_location_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" numeric, "saved_count" smallint) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" numeric, "saved_count" smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" numeric, "saved_count" smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" integer, "saved_count" integer, "outdoor_seating" boolean, "live_music" boolean, "serves_cocktails" boolean, "serves_brunch" boolean, "serves_wine" boolean, "serves_beer" boolean, "good_for_groups" boolean, "good_for_children" boolean, "serves_vegetarian_food" boolean, "serves_breakfast" boolean, "serves_lunch" boolean, "serves_dinner" boolean, "serves_coffee" boolean, "serves_dessert" boolean, "good_for_watching_sports" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" integer, "saved_count" integer, "outdoor_seating" boolean, "live_music" boolean, "serves_cocktails" boolean, "serves_brunch" boolean, "serves_wine" boolean, "serves_beer" boolean, "good_for_groups" boolean, "good_for_children" boolean, "serves_vegetarian_food" boolean, "serves_breakfast" boolean, "serves_lunch" boolean, "serves_dinner" boolean, "serves_coffee" boolean, "serves_dessert" boolean, "good_for_watching_sports" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_quality_score"("rating" double precision, "user_ratings_total" integer, "saved_count" integer, "outdoor_seating" boolean, "live_music" boolean, "serves_cocktails" boolean, "serves_brunch" boolean, "serves_wine" boolean, "serves_beer" boolean, "good_for_groups" boolean, "good_for_children" boolean, "serves_vegetarian_food" boolean, "serves_breakfast" boolean, "serves_lunch" boolean, "serves_dinner" boolean, "serves_coffee" boolean, "serves_dessert" boolean, "good_for_watching_sports" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_quality_score_v3"("p_rating" double precision, "p_user_ratings_total" numeric, "p_saved_count" smallint, "p_saves_count_app" integer, "p_dislikes_count_app" integer, "p_recent_reviews_90d" integer, "p_total_app_reviews" integer, "p_location_age_days" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_quality_score_v3"("p_rating" double precision, "p_user_ratings_total" numeric, "p_saved_count" smallint, "p_saves_count_app" integer, "p_dislikes_count_app" integer, "p_recent_reviews_90d" integer, "p_total_app_reviews" integer, "p_location_age_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_quality_score_v3"("p_rating" double precision, "p_user_ratings_total" numeric, "p_saved_count" smallint, "p_saves_count_app" integer, "p_dislikes_count_app" integer, "p_recent_reviews_90d" integer, "p_total_app_reviews" integer, "p_location_age_days" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_video_insight_score"("p_location_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_video_insight_score"("p_location_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_video_insight_score"("p_location_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."contains_2d"("public"."geometry", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."geometry", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."geometry", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."geometry", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_bubble_with_member"("p_name" "text", "p_created_by" "uuid", "p_is_private" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_bubble_with_member"("p_name" "text", "p_created_by" "uuid", "p_is_private" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_bubble_with_member"("p_name" "text", "p_created_by" "uuid", "p_is_private" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_collection"("p_name" "text", "p_is_public" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_collection"("p_name" "text", "p_is_public" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_collection"("p_name" "text", "p_is_public" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_collection_with_locations"("p_user_id" "uuid", "p_name" "text", "p_location_ids" bigint[], "p_description" "text", "p_emoji" "text", "p_cover_color" "text", "p_is_public" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_collection_with_locations"("p_user_id" "uuid", "p_name" "text", "p_location_ids" bigint[], "p_description" "text", "p_emoji" "text", "p_cover_color" "text", "p_is_public" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_collection_with_locations"("p_user_id" "uuid", "p_name" "text", "p_location_ids" bigint[], "p_description" "text", "p_emoji" "text", "p_cover_color" "text", "p_is_public" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_friendship"("p_follower_id" "uuid", "p_followee_id" "uuid", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_friendship"("p_follower_id" "uuid", "p_followee_id" "uuid", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_friendship"("p_follower_id" "uuid", "p_followee_id" "uuid", "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_location_review"("p_location_id" bigint, "p_content" "text", "p_rating" numeric, "p_gatekeep" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_location_review"("p_location_id" bigint, "p_content" "text", "p_rating" numeric, "p_gatekeep" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_location_review"("p_location_id" bigint, "p_content" "text", "p_rating" numeric, "p_gatekeep" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_new_collection"("p_name" "text", "p_description" "text", "p_emoji" "text", "p_cover_color" "text", "p_user_id" "uuid", "p_is_public" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_new_collection"("p_name" "text", "p_description" "text", "p_emoji" "text", "p_cover_color" "text", "p_user_id" "uuid", "p_is_public" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_new_collection"("p_name" "text", "p_description" "text", "p_emoji" "text", "p_cover_color" "text", "p_user_id" "uuid", "p_is_public" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_location_action"("p_user_id" "uuid", "p_location_id" bigint, "p_action" "text", "p_saved_method" "text", "p_preference" "text", "p_source_video_url" "text", "p_acked" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_location_action"("p_user_id" "uuid", "p_location_id" bigint, "p_action" "text", "p_saved_method" "text", "p_preference" "text", "p_source_video_url" "text", "p_acked" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_location_action"("p_user_id" "uuid", "p_location_id" bigint, "p_action" "text", "p_saved_method" "text", "p_preference" "text", "p_source_video_url" "text", "p_acked" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_profile"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_profile"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_profile"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_recommendation"("p_user_id" "uuid", "p_location_id" bigint, "p_score" real, "p_reason" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_recommendation"("p_user_id" "uuid", "p_location_id" bigint, "p_score" real, "p_reason" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_recommendation"("p_user_id" "uuid", "p_location_id" bigint, "p_score" real, "p_reason" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_saves_count"("loc_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_saves_count"("loc_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_saves_count"("loc_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_collection"("p_collection_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_collection"("p_collection_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_collection"("p_collection_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."disablelongtransactions"() TO "postgres";
GRANT ALL ON FUNCTION "public"."disablelongtransactions"() TO "anon";
GRANT ALL ON FUNCTION "public"."disablelongtransactions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."disablelongtransactions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."dislike_location_with_tags"("p_user_id" "uuid", "p_location_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."dislike_location_with_tags"("p_user_id" "uuid", "p_location_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dislike_location_with_tags"("p_user_id" "uuid", "p_location_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("table_name" character varying, "column_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("table_name" character varying, "column_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("table_name" character varying, "column_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("table_name" character varying, "column_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrytable"("table_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("table_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("table_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("table_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrytable"("schema_name" character varying, "table_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("schema_name" character varying, "table_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("schema_name" character varying, "table_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("schema_name" character varying, "table_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrytable"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."enablelongtransactions"() TO "postgres";
GRANT ALL ON FUNCTION "public"."enablelongtransactions"() TO "anon";
GRANT ALL ON FUNCTION "public"."enablelongtransactions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enablelongtransactions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_user_record_exists"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_user_record_exists"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_user_record_exists"("p_supabase_id" "uuid", "p_email" "text", "p_name" "text", "p_username" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."find_srid"(character varying, character varying, character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."find_srid"(character varying, character varying, character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."find_srid"(character varying, character varying, character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_srid"(character varying, character varying, character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."geog_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geog_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geog_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geog_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_cmp"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_cmp"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_cmp"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_cmp"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_distance_knn"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_distance_knn"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_distance_knn"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_distance_knn"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_eq"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_eq"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_eq"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_eq"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_ge"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_ge"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_ge"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_ge"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_consistent"("internal", "public"."geography", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_consistent"("internal", "public"."geography", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_consistent"("internal", "public"."geography", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_consistent"("internal", "public"."geography", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_distance"("internal", "public"."geography", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_distance"("internal", "public"."geography", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_distance"("internal", "public"."geography", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_distance"("internal", "public"."geography", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_same"("public"."box2d", "public"."box2d", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_same"("public"."box2d", "public"."box2d", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_same"("public"."box2d", "public"."box2d", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_same"("public"."box2d", "public"."box2d", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_union"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_union"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_union"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_union"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gt"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gt"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gt"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gt"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_le"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_le"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_le"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_le"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_lt"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_lt"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_lt"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_lt"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_overlaps"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_overlaps"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_overlaps"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_overlaps"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_choose_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_choose_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_choose_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_choose_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_compress_nd"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_compress_nd"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_compress_nd"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_compress_nd"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_config_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_config_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_config_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_config_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_inner_consistent_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_inner_consistent_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_inner_consistent_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_inner_consistent_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_leaf_consistent_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_leaf_consistent_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_leaf_consistent_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_leaf_consistent_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_picksplit_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_picksplit_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_picksplit_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_picksplit_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geom2d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geom2d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geom2d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geom2d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geom3d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geom3d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geom3d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geom3d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geom4d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geom4d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geom4d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geom4d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_above"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_above"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_above"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_above"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_below"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_below"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_below"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_below"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_cmp"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_cmp"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_cmp"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_cmp"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_contained_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_contained_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_contained_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_contained_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_contains_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_contains_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_contains_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_contains_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_contains_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_contains_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_contains_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_contains_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_distance_box"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_distance_box"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_distance_box"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_distance_box"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_distance_centroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_distance_centroid_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_distance_cpa"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_distance_cpa"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_distance_cpa"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_distance_cpa"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_eq"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_eq"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_eq"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_eq"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_ge"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_ge"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_ge"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_ge"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_compress_2d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_2d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_2d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_2d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_compress_nd"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_nd"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_nd"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_nd"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_2d"("internal", "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_2d"("internal", "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_2d"("internal", "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_2d"("internal", "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_nd"("internal", "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_nd"("internal", "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_nd"("internal", "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_nd"("internal", "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_2d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_2d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_2d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_2d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_nd"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_nd"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_nd"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_nd"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_distance_2d"("internal", "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_2d"("internal", "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_2d"("internal", "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_2d"("internal", "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_distance_nd"("internal", "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_nd"("internal", "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_nd"("internal", "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_nd"("internal", "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_2d"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_2d"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_2d"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_2d"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_nd"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_nd"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_nd"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_nd"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_same_2d"("geom1" "public"."geometry", "geom2" "public"."geometry", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_2d"("geom1" "public"."geometry", "geom2" "public"."geometry", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_2d"("geom1" "public"."geometry", "geom2" "public"."geometry", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_2d"("geom1" "public"."geometry", "geom2" "public"."geometry", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_same_nd"("public"."geometry", "public"."geometry", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_nd"("public"."geometry", "public"."geometry", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_nd"("public"."geometry", "public"."geometry", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_nd"("public"."geometry", "public"."geometry", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_sortsupport_2d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_sortsupport_2d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_sortsupport_2d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_sortsupport_2d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_union_2d"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_2d"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_2d"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_2d"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_union_nd"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_nd"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_nd"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_nd"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_hash"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_hash"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_hash"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_hash"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_le"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_le"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_le"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_le"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_left"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_left"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_left"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_left"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_lt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_lt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_lt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_lt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overabove"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overabove"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overabove"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overabove"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overbelow"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overbelow"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overbelow"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overbelow"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overlaps_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overlaps_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overleft"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overleft"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overleft"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overleft"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overright"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overright"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overright"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overright"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_right"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_right"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_right"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_right"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_same"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_same"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_same"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_same"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_same_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_same_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_same_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_same_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_same_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_same_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_same_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_same_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_sortsupport"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_sortsupport"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_sortsupport"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_sortsupport"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_2d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_2d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_2d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_2d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_3d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_3d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_3d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_3d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_nd"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_nd"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_nd"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_nd"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_config_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_config_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_config_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_within_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_within_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_within_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_within_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geomfromewkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."geomfromewkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."geomfromewkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geomfromewkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."geomfromewkt"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."geomfromewkt"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."geomfromewkt"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geomfromewkt"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_bubble_activity"("p_bubble_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_bubble_activity"("p_bubble_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_bubble_activity"("p_bubble_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_bubble_member_ids_excluding_user"("p_bubble_id" "uuid", "p_excluded_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_bubble_member_ids_excluding_user"("p_bubble_id" "uuid", "p_excluded_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_bubble_member_ids_excluding_user"("p_bubble_id" "uuid", "p_excluded_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_bubble_members"("p_bubble_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_bubble_members"("p_bubble_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_bubble_members"("p_bubble_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_bubble_messages"("p_bubble_id" "uuid", "p_limit" integer, "p_before_timestamp" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."get_bubble_messages"("p_bubble_id" "uuid", "p_limit" integer, "p_before_timestamp" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_bubble_messages"("p_bubble_id" "uuid", "p_limit" integer, "p_before_timestamp" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_collections_by_ids"("p_collection_ids" "uuid"[], "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_collections_by_ids"("p_collection_ids" "uuid"[], "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_collections_by_ids"("p_collection_ids" "uuid"[], "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_curated_collections"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_curated_collections"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_curated_collections"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_fill_locations"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_fill_locations"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_fill_locations"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_followers"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_followers"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_followers"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_following"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_following"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_following"("p_user_id" "uuid") TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER ON TABLE "public"."locations" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER ON TABLE "public"."locations" TO "authenticated";
GRANT ALL ON TABLE "public"."locations" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_hottest_shared_places"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_hottest_shared_places"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_hottest_shared_places"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_incoming_follow_requests"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_incoming_follow_requests"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_incoming_follow_requests"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_latest_shared_video_url"("p_location_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_latest_shared_video_url"("p_location_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_latest_shared_video_url"("p_location_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_location_collection_ids"("p_location_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_location_collection_ids"("p_location_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_location_collection_ids"("p_location_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_locations_in_collection"("p_collection_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_locations_in_collection"("p_collection_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_locations_in_collection"("p_collection_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_locations_with_pillars"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_locations_with_pillars"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_locations_with_pillars"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "result_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_other_collections"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_other_collections"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_other_collections"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_popular_locations"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_popular_locations"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_popular_locations"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_popular_locations"("p_limit" integer, "p_lat" double precision, "p_lng" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."get_popular_locations"("p_limit" integer, "p_lat" double precision, "p_lng" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_popular_locations"("p_limit" integer, "p_lat" double precision, "p_lng" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_proj4_from_srid"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."get_proj4_from_srid"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_proj4_from_srid"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_proj4_from_srid"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_ranked_proximal_recommendations"("p_supabase_id" "uuid", "center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "quality_weight" double precision, "vibe_weight" double precision, "dietary_weight" double precision, "result_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_ranked_proximal_recommendations"("p_supabase_id" "uuid", "center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "quality_weight" double precision, "vibe_weight" double precision, "dietary_weight" double precision, "result_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_ranked_proximal_recommendations"("p_supabase_id" "uuid", "center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "quality_weight" double precision, "vibe_weight" double precision, "dietary_weight" double precision, "result_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_saved_locations_not_in_collections"("p_user_id" "uuid", "p_collection_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_saved_locations_not_in_collections"("p_user_id" "uuid", "p_collection_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_saved_locations_not_in_collections"("p_user_id" "uuid", "p_collection_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_shared_video_summaries"("p_location_ids" bigint[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_shared_video_summaries"("p_location_ids" bigint[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_shared_video_summaries"("p_location_ids" bigint[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_suggested_users"("p_supabase_id" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_suggested_users"("p_supabase_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_suggested_users"("p_supabase_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_actions"("p_user_id" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_actions"("p_user_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_actions"("p_user_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_been_to_count"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_been_to_count"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_been_to_count"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_been_to_reviews"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_been_to_reviews"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_been_to_reviews"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_chats"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_chats"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_chats"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_collection_library"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_collection_library"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_collection_library"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_collections"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_collections"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_collections"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_public_collections"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_public_collections"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_public_collections"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_tag_scores"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_tag_scores"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_tag_scores"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_top_vibes"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_top_vibes"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_top_vibes"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."gettransactionid"() TO "postgres";
GRANT ALL ON FUNCTION "public"."gettransactionid"() TO "anon";
GRANT ALL ON FUNCTION "public"."gettransactionid"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."gettransactionid"() TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_2d"("internal", "oid", "internal", smallint) TO "postgres";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_2d"("internal", "oid", "internal", smallint) TO "anon";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_2d"("internal", "oid", "internal", smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_2d"("internal", "oid", "internal", smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_nd"("internal", "oid", "internal", smallint) TO "postgres";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_nd"("internal", "oid", "internal", smallint) TO "anon";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_nd"("internal", "oid", "internal", smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_nd"("internal", "oid", "internal", smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_2d"("internal", "oid", "internal", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_2d"("internal", "oid", "internal", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_2d"("internal", "oid", "internal", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_2d"("internal", "oid", "internal", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_nd"("internal", "oid", "internal", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_nd"("internal", "oid", "internal", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_nd"("internal", "oid", "internal", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_nd"("internal", "oid", "internal", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_dislikes_count"("loc_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."increment_dislikes_count"("loc_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_dislikes_count"("loc_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_saves_count"("loc_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."increment_saves_count"("loc_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_saves_count"("loc_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."initialize_bubble_chat"("p_bubble_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."initialize_bubble_chat"("p_bubble_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."initialize_bubble_chat"("p_bubble_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."initialize_chat_state_for_new_member"() TO "anon";
GRANT ALL ON FUNCTION "public"."initialize_chat_state_for_new_member"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."initialize_chat_state_for_new_member"() TO "service_role";



GRANT ALL ON FUNCTION "public"."initialize_vibe_tags_for_user"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."initialize_vibe_tags_for_user"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."initialize_vibe_tags_for_user"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."geometry", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."geometry", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."geometry", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."geometry", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."leave_bubble"("p_bubble_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."leave_bubble"("p_bubble_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."leave_bubble"("p_bubble_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."locations_within_radius"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "max_results" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."locations_within_radius"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "max_results" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."locations_within_radius"("center_lat" double precision, "center_lng" double precision, "radius_meters" double precision, "max_results" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", timestamp without time zone) TO "postgres";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", timestamp without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", timestamp without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", timestamp without time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text", timestamp without time zone) TO "postgres";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text", timestamp without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text", timestamp without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text", timestamp without time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."longtransactionsenabled"() TO "postgres";
GRANT ALL ON FUNCTION "public"."longtransactionsenabled"() TO "anon";
GRANT ALL ON FUNCTION "public"."longtransactionsenabled"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."longtransactionsenabled"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_bubble_read"("p_bubble_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_bubble_read"("p_bubble_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_bubble_read"("p_bubble_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_location_extra_photos_stored"("p_location_id" bigint, "p_count" smallint) TO "anon";
GRANT ALL ON FUNCTION "public"."mark_location_extra_photos_stored"("p_location_id" bigint, "p_count" smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_location_extra_photos_stored"("p_location_id" bigint, "p_count" smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_location_image_unavailable"("p_location_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."mark_location_image_unavailable"("p_location_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_location_image_unavailable"("p_location_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_location_image_uploaded"("p_location_id" bigint, "p_photos" "jsonb", "p_photo_reference" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_location_image_uploaded"("p_location_id" bigint, "p_photos" "jsonb", "p_photo_reference" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_location_image_uploaded"("p_location_id" bigint, "p_photos" "jsonb", "p_photo_reference" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."normalized_dot_product"("vec1" integer[], "vec2" integer[]) TO "anon";
GRANT ALL ON FUNCTION "public"."normalized_dot_product"("vec1" integer[], "vec2" integer[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."normalized_dot_product"("vec1" integer[], "vec2" integer[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_new_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_new_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_new_message"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_no_recommendations_in_area_internal"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_no_recommendations_in_area_internal"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_no_recommendations_in_area_internal"() TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."geometry", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."geometry", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."geometry", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."geometry", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."geography", "public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."geography", "public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."geography", "public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."geography", "public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."geometry", "public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."geometry", "public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."geometry", "public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."geometry", "public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_combinefn"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_combinefn"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_combinefn"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_combinefn"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_deserialfn"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_deserialfn"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_deserialfn"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_deserialfn"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_serialfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_serialfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_serialfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_serialfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterintersecting_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterintersecting_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterintersecting_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterintersecting_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterwithin_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterwithin_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterwithin_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterwithin_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_collect_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_collect_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_collect_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_collect_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_makeline_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_makeline_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_makeline_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_makeline_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_polygonize_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_polygonize_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_polygonize_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_polygonize_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_combinefn"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_combinefn"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_combinefn"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_combinefn"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_deserialfn"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_deserialfn"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_deserialfn"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_deserialfn"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_serialfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_serialfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_serialfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_serialfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."photos_name_array"("p" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."photos_name_array"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."photos_name_array"("p" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("use_typmod" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("tbl_oid" "oid", "use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("tbl_oid" "oid", "use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("tbl_oid" "oid", "use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("tbl_oid" "oid", "use_typmod" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_addbbox"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_addbbox"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_addbbox"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_addbbox"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_cache_bbox"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_cache_bbox"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_cache_bbox"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_cache_bbox"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_constraint_dims"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_constraint_dims"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_constraint_dims"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_constraint_dims"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_constraint_srid"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_constraint_srid"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_constraint_srid"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_constraint_srid"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_constraint_type"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_constraint_type"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_constraint_type"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_constraint_type"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_dropbbox"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_dropbbox"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_dropbbox"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_dropbbox"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_extensions_upgrade"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_extensions_upgrade"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_extensions_upgrade"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_extensions_upgrade"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_full_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_full_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_full_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_full_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_geos_noop"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_geos_noop"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_geos_noop"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_geos_noop"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_geos_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_geos_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_geos_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_geos_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_getbbox"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_getbbox"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_getbbox"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_getbbox"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_hasbbox"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_hasbbox"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_hasbbox"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_hasbbox"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_index_supportfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_index_supportfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_index_supportfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_index_supportfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_lib_build_date"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_lib_build_date"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_lib_build_date"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_lib_build_date"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_lib_revision"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_lib_revision"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_lib_revision"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_lib_revision"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_lib_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_lib_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_lib_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_lib_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_libjson_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_libjson_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_libjson_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_libjson_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_liblwgeom_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_liblwgeom_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_liblwgeom_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_liblwgeom_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_libprotobuf_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_libprotobuf_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_libprotobuf_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_libprotobuf_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_libxml_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_libxml_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_libxml_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_libxml_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_noop"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_noop"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_noop"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_noop"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_proj_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_proj_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_proj_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_proj_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_scripts_build_date"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_scripts_build_date"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_scripts_build_date"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_scripts_build_date"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_scripts_installed"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_scripts_installed"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_scripts_installed"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_scripts_installed"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_scripts_released"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_scripts_released"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_scripts_released"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_scripts_released"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_svn_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_svn_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_svn_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_svn_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_transform_geometry"("geom" "public"."geometry", "text", "text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_transform_geometry"("geom" "public"."geometry", "text", "text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_transform_geometry"("geom" "public"."geometry", "text", "text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_transform_geometry"("geom" "public"."geometry", "text", "text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_type_name"("geomname" character varying, "coord_dimension" integer, "use_new_name" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_type_name"("geomname" character varying, "coord_dimension" integer, "use_new_name" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_type_name"("geomname" character varying, "coord_dimension" integer, "use_new_name" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_type_name"("geomname" character varying, "coord_dimension" integer, "use_new_name" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_typmod_dims"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_typmod_dims"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_typmod_dims"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_typmod_dims"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_typmod_srid"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_typmod_srid"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_typmod_srid"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_typmod_srid"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_typmod_type"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_typmod_type"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_typmod_type"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_typmod_type"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_wagyu_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_wagyu_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_wagyu_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_wagyu_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_location_share_count"("p_location_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_location_share_count"("p_location_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_location_share_count"("p_location_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_location_quality_scores"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_location_quality_scores"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_location_quality_scores"() TO "service_role";



GRANT ALL ON FUNCTION "public"."reject_friendship"("request_from_id" "uuid", "user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reject_friendship"("request_from_id" "uuid", "user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reject_friendship"("request_from_id" "uuid", "user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."release_location_processing_claim"("p_location_id" integer, "p_request_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."release_location_processing_claim"("p_location_id" integer, "p_request_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_location_from_bubble"("p_bubble_id" "uuid", "p_location_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."remove_location_from_bubble"("p_bubble_id" "uuid", "p_location_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_location_from_bubble"("p_bubble_id" "uuid", "p_location_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_location_from_collection"("p_collection_id" "uuid", "p_location_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."remove_location_from_collection"("p_collection_id" "uuid", "p_location_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_location_from_collection"("p_collection_id" "uuid", "p_location_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."save_collection"("p_collection_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."save_collection"("p_collection_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_collection"("p_collection_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."save_location_with_tags"("p_user_id" "uuid", "p_location_id" integer, "p_saved_method" "text", "p_acked" boolean, "p_source_video_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."save_location_with_tags"("p_user_id" "uuid", "p_location_id" integer, "p_saved_method" "text", "p_acked" boolean, "p_source_video_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_location_with_tags"("p_user_id" "uuid", "p_location_id" integer, "p_saved_method" "text", "p_acked" boolean, "p_source_video_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."search_locations"("p_query" "text", "p_limit" integer, "p_lat" double precision, "p_lng" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."search_locations"("p_query" "text", "p_limit" integer, "p_lat" double precision, "p_lng" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_locations"("p_query" "text", "p_limit" integer, "p_lat" double precision, "p_lng" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."search_users"("p_query" "text", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."search_users"("p_query" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_users"("p_query" "text", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."send_message"("p_bubble_id" "uuid", "p_content" "text", "p_message_type" "text", "p_metadata" "jsonb", "p_replied_to" "uuid", "p_location_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."send_message"("p_bubble_id" "uuid", "p_content" "text", "p_message_type" "text", "p_metadata" "jsonb", "p_replied_to" "uuid", "p_location_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_message"("p_bubble_id" "uuid", "p_content" "text", "p_message_type" "text", "p_metadata" "jsonb", "p_replied_to" "uuid", "p_location_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "postgres";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "anon";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_message_liked"("p_message_id" "uuid", "p_liked" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_message_liked"("p_message_id" "uuid", "p_liked" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_message_liked"("p_message_id" "uuid", "p_liked" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."show_limit"() TO "postgres";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dclosestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dclosestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dclosestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dclosestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3ddistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3ddistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3ddistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3ddistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dlength"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dlength"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dlength"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dlength"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dlineinterpolatepoint"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dlineinterpolatepoint"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dlineinterpolatepoint"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dlineinterpolatepoint"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dlongestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dlongestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dlongestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dlongestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dmakebox"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dmakebox"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dmakebox"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dmakebox"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dmaxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dmaxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dmaxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dmaxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dperimeter"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dperimeter"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dperimeter"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dperimeter"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dshortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dshortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dshortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dshortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_addmeasure"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_addmeasure"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_addmeasure"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_addmeasure"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_angle"("line1" "public"."geometry", "line2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_angle"("line1" "public"."geometry", "line2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_angle"("line1" "public"."geometry", "line2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_angle"("line1" "public"."geometry", "line2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_angle"("pt1" "public"."geometry", "pt2" "public"."geometry", "pt3" "public"."geometry", "pt4" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_angle"("pt1" "public"."geometry", "pt2" "public"."geometry", "pt3" "public"."geometry", "pt4" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_angle"("pt1" "public"."geometry", "pt2" "public"."geometry", "pt3" "public"."geometry", "pt4" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_angle"("pt1" "public"."geometry", "pt2" "public"."geometry", "pt3" "public"."geometry", "pt4" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_area"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_area"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_area"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_area"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_area"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_area"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_area"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_area"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_area"("geog" "public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_area"("geog" "public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_area"("geog" "public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_area"("geog" "public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_area2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_area2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_area2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_area2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asencodedpolyline"("geom" "public"."geometry", "nprecision" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asencodedpolyline"("geom" "public"."geometry", "nprecision" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asencodedpolyline"("geom" "public"."geometry", "nprecision" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asencodedpolyline"("geom" "public"."geometry", "nprecision" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeojson"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeojson"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeojson"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeojson"("r" "record", "geom_column" "text", "maxdecimaldigits" integer, "pretty_bool" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("r" "record", "geom_column" "text", "maxdecimaldigits" integer, "pretty_bool" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("r" "record", "geom_column" "text", "maxdecimaldigits" integer, "pretty_bool" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("r" "record", "geom_column" "text", "maxdecimaldigits" integer, "pretty_bool" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_askml"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_askml"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_askml"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_askml"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_askml"("geog" "public"."geography", "maxdecimaldigits" integer, "nprefix" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_askml"("geog" "public"."geography", "maxdecimaldigits" integer, "nprefix" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_askml"("geog" "public"."geography", "maxdecimaldigits" integer, "nprefix" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_askml"("geog" "public"."geography", "maxdecimaldigits" integer, "nprefix" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_askml"("geom" "public"."geometry", "maxdecimaldigits" integer, "nprefix" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_askml"("geom" "public"."geometry", "maxdecimaldigits" integer, "nprefix" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_askml"("geom" "public"."geometry", "maxdecimaldigits" integer, "nprefix" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_askml"("geom" "public"."geometry", "maxdecimaldigits" integer, "nprefix" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_aslatlontext"("geom" "public"."geometry", "tmpl" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_aslatlontext"("geom" "public"."geometry", "tmpl" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_aslatlontext"("geom" "public"."geometry", "tmpl" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_aslatlontext"("geom" "public"."geometry", "tmpl" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmarc21"("geom" "public"."geometry", "format" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmarc21"("geom" "public"."geometry", "format" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmarc21"("geom" "public"."geometry", "format" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmarc21"("geom" "public"."geometry", "format" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvtgeom"("geom" "public"."geometry", "bounds" "public"."box2d", "extent" integer, "buffer" integer, "clip_geom" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvtgeom"("geom" "public"."geometry", "bounds" "public"."box2d", "extent" integer, "buffer" integer, "clip_geom" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvtgeom"("geom" "public"."geometry", "bounds" "public"."box2d", "extent" integer, "buffer" integer, "clip_geom" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvtgeom"("geom" "public"."geometry", "bounds" "public"."box2d", "extent" integer, "buffer" integer, "clip_geom" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_assvg"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_assvg"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_assvg"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_assvg"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_assvg"("geog" "public"."geography", "rel" integer, "maxdecimaldigits" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_assvg"("geog" "public"."geography", "rel" integer, "maxdecimaldigits" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_assvg"("geog" "public"."geography", "rel" integer, "maxdecimaldigits" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_assvg"("geog" "public"."geography", "rel" integer, "maxdecimaldigits" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_assvg"("geom" "public"."geometry", "rel" integer, "maxdecimaldigits" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_assvg"("geom" "public"."geometry", "rel" integer, "maxdecimaldigits" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_assvg"("geom" "public"."geometry", "rel" integer, "maxdecimaldigits" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_assvg"("geom" "public"."geometry", "rel" integer, "maxdecimaldigits" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry", "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry", "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry", "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry", "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry"[], "ids" bigint[], "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry"[], "ids" bigint[], "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry"[], "ids" bigint[], "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry"[], "ids" bigint[], "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asx3d"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asx3d"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asx3d"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asx3d"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_azimuth"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_azimuth"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_bdmpolyfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_bdmpolyfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_bdmpolyfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_bdmpolyfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_bdpolyfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_bdpolyfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_bdpolyfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_bdpolyfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_boundary"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_boundary"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_boundary"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_boundary"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_boundingdiagonal"("geom" "public"."geometry", "fits" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_boundingdiagonal"("geom" "public"."geometry", "fits" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_boundingdiagonal"("geom" "public"."geometry", "fits" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_boundingdiagonal"("geom" "public"."geometry", "fits" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_box2dfromgeohash"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_box2dfromgeohash"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_box2dfromgeohash"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_box2dfromgeohash"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "quadsegs" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "quadsegs" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "quadsegs" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "quadsegs" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "options" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "options" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "options" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "options" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buildarea"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buildarea"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_buildarea"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buildarea"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_centroid"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_centroid"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_centroid"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_centroid"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_chaikinsmoothing"("public"."geometry", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_chaikinsmoothing"("public"."geometry", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_chaikinsmoothing"("public"."geometry", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_chaikinsmoothing"("public"."geometry", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_cleangeometry"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_cleangeometry"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_cleangeometry"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_cleangeometry"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clipbybox2d"("geom" "public"."geometry", "box" "public"."box2d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clipbybox2d"("geom" "public"."geometry", "box" "public"."box2d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_clipbybox2d"("geom" "public"."geometry", "box" "public"."box2d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clipbybox2d"("geom" "public"."geometry", "box" "public"."box2d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_closestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_closestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_closestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_closestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_closestpointofapproach"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_closestpointofapproach"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_closestpointofapproach"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_closestpointofapproach"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterdbscan"("public"."geometry", "eps" double precision, "minpoints" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterdbscan"("public"."geometry", "eps" double precision, "minpoints" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterdbscan"("public"."geometry", "eps" double precision, "minpoints" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterdbscan"("public"."geometry", "eps" double precision, "minpoints" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterkmeans"("geom" "public"."geometry", "k" integer, "max_radius" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterkmeans"("geom" "public"."geometry", "k" integer, "max_radius" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterkmeans"("geom" "public"."geometry", "k" integer, "max_radius" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterkmeans"("geom" "public"."geometry", "k" integer, "max_radius" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry"[], double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry"[], double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry"[], double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry"[], double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collect"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collect"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_collect"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collect"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collectionhomogenize"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collectionhomogenize"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_collectionhomogenize"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collectionhomogenize"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box2d", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box2d", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box2d", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box2d", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_concavehull"("param_geom" "public"."geometry", "param_pctconvex" double precision, "param_allow_holes" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_concavehull"("param_geom" "public"."geometry", "param_pctconvex" double precision, "param_allow_holes" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_concavehull"("param_geom" "public"."geometry", "param_pctconvex" double precision, "param_allow_holes" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_concavehull"("param_geom" "public"."geometry", "param_pctconvex" double precision, "param_allow_holes" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_convexhull"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_convexhull"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_convexhull"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_convexhull"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_coorddim"("geometry" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_coorddim"("geometry" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_coorddim"("geometry" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_coorddim"("geometry" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_coveredby"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_coveredby"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_coveredby"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_coveredby"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_covers"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_covers"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_covers"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_covers"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_cpawithin"("public"."geometry", "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_cpawithin"("public"."geometry", "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_cpawithin"("public"."geometry", "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_cpawithin"("public"."geometry", "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_curvetoline"("geom" "public"."geometry", "tol" double precision, "toltype" integer, "flags" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_curvetoline"("geom" "public"."geometry", "tol" double precision, "toltype" integer, "flags" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_curvetoline"("geom" "public"."geometry", "tol" double precision, "toltype" integer, "flags" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_curvetoline"("geom" "public"."geometry", "tol" double precision, "toltype" integer, "flags" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_delaunaytriangles"("g1" "public"."geometry", "tolerance" double precision, "flags" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_delaunaytriangles"("g1" "public"."geometry", "tolerance" double precision, "flags" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_delaunaytriangles"("g1" "public"."geometry", "tolerance" double precision, "flags" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_delaunaytriangles"("g1" "public"."geometry", "tolerance" double precision, "flags" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_difference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_difference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_difference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_difference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dimension"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dimension"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dimension"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dimension"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_disjoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_disjoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_disjoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_disjoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distance"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distance"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distance"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distance"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distance"("geog1" "public"."geography", "geog2" "public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distance"("geog1" "public"."geography", "geog2" "public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_distance"("geog1" "public"."geography", "geog2" "public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distance"("geog1" "public"."geography", "geog2" "public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancecpa"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancecpa"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancecpa"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancecpa"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry", "radius" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry", "radius" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry", "radius" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry", "radius" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry", "public"."spheroid") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry", "public"."spheroid") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry", "public"."spheroid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry", "public"."spheroid") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dump"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dump"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dump"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dump"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dumppoints"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dumppoints"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dumppoints"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dumppoints"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dumprings"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dumprings"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dumprings"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dumprings"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dumpsegments"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dumpsegments"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dumpsegments"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dumpsegments"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dwithin"("text", "text", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dwithin"("text", "text", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_dwithin"("text", "text", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dwithin"("text", "text", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_endpoint"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_endpoint"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_endpoint"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_endpoint"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_envelope"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_envelope"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_envelope"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_envelope"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("public"."box2d", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box2d", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box2d", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box2d", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("public"."box3d", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box3d", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box3d", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box3d", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box2d", "dx" double precision, "dy" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box2d", "dx" double precision, "dy" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box2d", "dx" double precision, "dy" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box2d", "dx" double precision, "dy" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box3d", "dx" double precision, "dy" double precision, "dz" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box3d", "dx" double precision, "dy" double precision, "dz" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box3d", "dx" double precision, "dy" double precision, "dz" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box3d", "dx" double precision, "dy" double precision, "dz" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("geom" "public"."geometry", "dx" double precision, "dy" double precision, "dz" double precision, "dm" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("geom" "public"."geometry", "dx" double precision, "dy" double precision, "dz" double precision, "dm" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("geom" "public"."geometry", "dx" double precision, "dy" double precision, "dz" double precision, "dm" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("geom" "public"."geometry", "dx" double precision, "dy" double precision, "dz" double precision, "dm" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_exteriorring"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_exteriorring"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_exteriorring"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_exteriorring"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_filterbym"("public"."geometry", double precision, double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_filterbym"("public"."geometry", double precision, double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_filterbym"("public"."geometry", double precision, double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_filterbym"("public"."geometry", double precision, double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_flipcoordinates"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_flipcoordinates"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_flipcoordinates"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_flipcoordinates"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_force2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force3d"("geom" "public"."geometry", "zvalue" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force3d"("geom" "public"."geometry", "zvalue" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_force3d"("geom" "public"."geometry", "zvalue" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force3d"("geom" "public"."geometry", "zvalue" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force3dm"("geom" "public"."geometry", "mvalue" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force3dm"("geom" "public"."geometry", "mvalue" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_force3dm"("geom" "public"."geometry", "mvalue" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force3dm"("geom" "public"."geometry", "mvalue" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force3dz"("geom" "public"."geometry", "zvalue" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force3dz"("geom" "public"."geometry", "zvalue" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_force3dz"("geom" "public"."geometry", "zvalue" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force3dz"("geom" "public"."geometry", "zvalue" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force4d"("geom" "public"."geometry", "zvalue" double precision, "mvalue" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force4d"("geom" "public"."geometry", "zvalue" double precision, "mvalue" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_force4d"("geom" "public"."geometry", "zvalue" double precision, "mvalue" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force4d"("geom" "public"."geometry", "zvalue" double precision, "mvalue" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcecollection"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcecollection"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcecollection"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcecollection"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcecurve"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcecurve"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcecurve"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcecurve"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcepolygonccw"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcepolygonccw"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcepolygonccw"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcepolygonccw"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcepolygoncw"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcepolygoncw"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcepolygoncw"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcepolygoncw"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcerhr"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcerhr"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcerhr"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcerhr"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry", "version" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry", "version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry", "version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry", "version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_frechetdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_frechetdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_frechetdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_frechetdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_fromflatgeobuf"("anyelement", "bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuf"("anyelement", "bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuf"("anyelement", "bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuf"("anyelement", "bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_fromflatgeobuftotable"("text", "text", "bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuftotable"("text", "text", "bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuftotable"("text", "text", "bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuftotable"("text", "text", "bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer, "seed" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer, "seed" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer, "seed" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer, "seed" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geogfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geogfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geogfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geogfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geogfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geogfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geogfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geogfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geographyfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geographyfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geographyfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geographyfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geohash"("geog" "public"."geography", "maxchars" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geohash"("geog" "public"."geography", "maxchars" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geohash"("geog" "public"."geography", "maxchars" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geohash"("geog" "public"."geography", "maxchars" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geohash"("geom" "public"."geometry", "maxchars" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geohash"("geom" "public"."geometry", "maxchars" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geohash"("geom" "public"."geometry", "maxchars" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geohash"("geom" "public"."geometry", "maxchars" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometricmedian"("g" "public"."geometry", "tolerance" double precision, "max_iter" integer, "fail_if_not_converged" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometricmedian"("g" "public"."geometry", "tolerance" double precision, "max_iter" integer, "fail_if_not_converged" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometricmedian"("g" "public"."geometry", "tolerance" double precision, "max_iter" integer, "fail_if_not_converged" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometricmedian"("g" "public"."geometry", "tolerance" double precision, "max_iter" integer, "fail_if_not_converged" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometryn"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometryn"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometryn"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometryn"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometrytype"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometrytype"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometrytype"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometrytype"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromewkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromewkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromewkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromewkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromewkt"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromewkt"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromewkt"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromewkt"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgeohash"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgeohash"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgeohash"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgeohash"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("json") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("json") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("json") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("json") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("jsonb") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromkml"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromkml"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromkml"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromkml"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfrommarc21"("marc21xml" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfrommarc21"("marc21xml" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfrommarc21"("marc21xml" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfrommarc21"("marc21xml" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromtwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromtwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromtwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromtwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_gmltosql"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_gmltosql"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hasarc"("geometry" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hasarc"("geometry" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_hasarc"("geometry" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hasarc"("geometry" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hexagon"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hexagon"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_hexagon"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hexagon"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hexagongrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hexagongrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_hexagongrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hexagongrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_interiorringn"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_interiorringn"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_interiorringn"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_interiorringn"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_interpolatepoint"("line" "public"."geometry", "point" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_interpolatepoint"("line" "public"."geometry", "point" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_interpolatepoint"("line" "public"."geometry", "point" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_interpolatepoint"("line" "public"."geometry", "point" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersection"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersection"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersection"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersection"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersection"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersection"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersection"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersection"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersection"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersection"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersection"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersection"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersects"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersects"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersects"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersects"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersects"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersects"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersects"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersects"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isclosed"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isclosed"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isclosed"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isclosed"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_iscollection"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_iscollection"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_iscollection"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_iscollection"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isempty"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isempty"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isempty"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isempty"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ispolygonccw"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ispolygonccw"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ispolygonccw"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ispolygonccw"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ispolygoncw"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ispolygoncw"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ispolygoncw"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ispolygoncw"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isring"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isring"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isring"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isring"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_issimple"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_issimple"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_issimple"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_issimple"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvaliddetail"("geom" "public"."geometry", "flags" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvaliddetail"("geom" "public"."geometry", "flags" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvaliddetail"("geom" "public"."geometry", "flags" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvaliddetail"("geom" "public"."geometry", "flags" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalidtrajectory"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalidtrajectory"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalidtrajectory"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalidtrajectory"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_length"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_length"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length"("geog" "public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length"("geog" "public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_length"("geog" "public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length"("geog" "public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_length2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length2dspheroid"("public"."geometry", "public"."spheroid") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length2dspheroid"("public"."geometry", "public"."spheroid") TO "anon";
GRANT ALL ON FUNCTION "public"."st_length2dspheroid"("public"."geometry", "public"."spheroid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length2dspheroid"("public"."geometry", "public"."spheroid") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_lengthspheroid"("public"."geometry", "public"."spheroid") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_lengthspheroid"("public"."geometry", "public"."spheroid") TO "anon";
GRANT ALL ON FUNCTION "public"."st_lengthspheroid"("public"."geometry", "public"."spheroid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_lengthspheroid"("public"."geometry", "public"."spheroid") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_letters"("letters" "text", "font" "json") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_letters"("letters" "text", "font" "json") TO "anon";
GRANT ALL ON FUNCTION "public"."st_letters"("letters" "text", "font" "json") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_letters"("letters" "text", "font" "json") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromencodedpolyline"("txtin" "text", "nprecision" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromencodedpolyline"("txtin" "text", "nprecision" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromencodedpolyline"("txtin" "text", "nprecision" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromencodedpolyline"("txtin" "text", "nprecision" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefrommultipoint"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefrommultipoint"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefrommultipoint"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefrommultipoint"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoint"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoint"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoint"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoint"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoints"("public"."geometry", double precision, "repeat" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoints"("public"."geometry", double precision, "repeat" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoints"("public"."geometry", double precision, "repeat" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoints"("public"."geometry", double precision, "repeat" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linelocatepoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linelocatepoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linelocatepoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linelocatepoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linesubstring"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linesubstring"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linesubstring"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linesubstring"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linetocurve"("geometry" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linetocurve"("geometry" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linetocurve"("geometry" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linetocurve"("geometry" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_locatealong"("geometry" "public"."geometry", "measure" double precision, "leftrightoffset" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_locatealong"("geometry" "public"."geometry", "measure" double precision, "leftrightoffset" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_locatealong"("geometry" "public"."geometry", "measure" double precision, "leftrightoffset" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_locatealong"("geometry" "public"."geometry", "measure" double precision, "leftrightoffset" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_locatebetween"("geometry" "public"."geometry", "frommeasure" double precision, "tomeasure" double precision, "leftrightoffset" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_locatebetween"("geometry" "public"."geometry", "frommeasure" double precision, "tomeasure" double precision, "leftrightoffset" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_locatebetween"("geometry" "public"."geometry", "frommeasure" double precision, "tomeasure" double precision, "leftrightoffset" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_locatebetween"("geometry" "public"."geometry", "frommeasure" double precision, "tomeasure" double precision, "leftrightoffset" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_locatebetweenelevations"("geometry" "public"."geometry", "fromelevation" double precision, "toelevation" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_locatebetweenelevations"("geometry" "public"."geometry", "fromelevation" double precision, "toelevation" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_locatebetweenelevations"("geometry" "public"."geometry", "fromelevation" double precision, "toelevation" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_locatebetweenelevations"("geometry" "public"."geometry", "fromelevation" double precision, "toelevation" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_m"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_m"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_m"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_m"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makebox2d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makebox2d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makebox2d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makebox2d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makeenvelope"(double precision, double precision, double precision, double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makeenvelope"(double precision, double precision, double precision, double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makeenvelope"(double precision, double precision, double precision, double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makeenvelope"(double precision, double precision, double precision, double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makeline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makeline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makeline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makeline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepointm"(double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepointm"(double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepointm"(double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepointm"(double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry", "public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry", "public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry", "public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry", "public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makevalid"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makevalid"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makevalid"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makevalid"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makevalid"("geom" "public"."geometry", "params" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makevalid"("geom" "public"."geometry", "params" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makevalid"("geom" "public"."geometry", "params" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makevalid"("geom" "public"."geometry", "params" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_maximuminscribedcircle"("public"."geometry", OUT "center" "public"."geometry", OUT "nearest" "public"."geometry", OUT "radius" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_maximuminscribedcircle"("public"."geometry", OUT "center" "public"."geometry", OUT "nearest" "public"."geometry", OUT "radius" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_maximuminscribedcircle"("public"."geometry", OUT "center" "public"."geometry", OUT "nearest" "public"."geometry", OUT "radius" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_maximuminscribedcircle"("public"."geometry", OUT "center" "public"."geometry", OUT "nearest" "public"."geometry", OUT "radius" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_memsize"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_memsize"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_memsize"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_memsize"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_minimumboundingcircle"("inputgeom" "public"."geometry", "segs_per_quarter" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_minimumboundingcircle"("inputgeom" "public"."geometry", "segs_per_quarter" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_minimumboundingcircle"("inputgeom" "public"."geometry", "segs_per_quarter" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_minimumboundingcircle"("inputgeom" "public"."geometry", "segs_per_quarter" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_minimumboundingradius"("public"."geometry", OUT "center" "public"."geometry", OUT "radius" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_minimumboundingradius"("public"."geometry", OUT "center" "public"."geometry", OUT "radius" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_minimumboundingradius"("public"."geometry", OUT "center" "public"."geometry", OUT "radius" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_minimumboundingradius"("public"."geometry", OUT "center" "public"."geometry", OUT "radius" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_minimumclearance"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_minimumclearance"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_minimumclearance"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_minimumclearance"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_minimumclearanceline"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_minimumclearanceline"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_minimumclearanceline"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_minimumclearanceline"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multi"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multi"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multi"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multi"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multilinefromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multilinefromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multilinefromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multilinefromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipointfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipointfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipointfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipointfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ndims"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ndims"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ndims"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ndims"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_node"("g" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_node"("g" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_node"("g" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_node"("g" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_normalize"("geom" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_normalize"("geom" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_normalize"("geom" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_normalize"("geom" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_npoints"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_npoints"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_npoints"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_npoints"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_nrings"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_nrings"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_nrings"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_nrings"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numgeometries"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numgeometries"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numgeometries"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numgeometries"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numinteriorring"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numinteriorring"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numinteriorring"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numinteriorring"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numinteriorrings"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numinteriorrings"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numinteriorrings"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numinteriorrings"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numpatches"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numpatches"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numpatches"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numpatches"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numpoints"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numpoints"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numpoints"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numpoints"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_offsetcurve"("line" "public"."geometry", "distance" double precision, "params" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_offsetcurve"("line" "public"."geometry", "distance" double precision, "params" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_offsetcurve"("line" "public"."geometry", "distance" double precision, "params" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_offsetcurve"("line" "public"."geometry", "distance" double precision, "params" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_orientedenvelope"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_orientedenvelope"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_orientedenvelope"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_orientedenvelope"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_patchn"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_patchn"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_patchn"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_patchn"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_perimeter"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_perimeter"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_perimeter"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_perimeter"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_perimeter"("geog" "public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_perimeter"("geog" "public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_perimeter"("geog" "public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_perimeter"("geog" "public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_perimeter2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_perimeter2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_perimeter2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_perimeter2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision, "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision, "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision, "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision, "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromgeohash"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromgeohash"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromgeohash"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromgeohash"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointinsidecircle"("public"."geometry", double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointinsidecircle"("public"."geometry", double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointinsidecircle"("public"."geometry", double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointinsidecircle"("public"."geometry", double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointm"("xcoordinate" double precision, "ycoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointm"("xcoordinate" double precision, "ycoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointm"("xcoordinate" double precision, "ycoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointm"("xcoordinate" double precision, "ycoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointn"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointn"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointn"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointn"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointonsurface"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointonsurface"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointonsurface"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointonsurface"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_points"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_points"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_points"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_points"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointz"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointz"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointz"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointz"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointzm"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointzm"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointzm"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointzm"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygon"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygon"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygon"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygon"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_project"("geog" "public"."geography", "distance" double precision, "azimuth" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_project"("geog" "public"."geography", "distance" double precision, "azimuth" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_project"("geog" "public"."geography", "distance" double precision, "azimuth" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_project"("geog" "public"."geography", "distance" double precision, "azimuth" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_quantizecoordinates"("g" "public"."geometry", "prec_x" integer, "prec_y" integer, "prec_z" integer, "prec_m" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_quantizecoordinates"("g" "public"."geometry", "prec_x" integer, "prec_y" integer, "prec_z" integer, "prec_m" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_quantizecoordinates"("g" "public"."geometry", "prec_x" integer, "prec_y" integer, "prec_z" integer, "prec_m" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_quantizecoordinates"("g" "public"."geometry", "prec_x" integer, "prec_y" integer, "prec_z" integer, "prec_m" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_reduceprecision"("geom" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_reduceprecision"("geom" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_reduceprecision"("geom" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_reduceprecision"("geom" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_relatematch"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_relatematch"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_relatematch"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_relatematch"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_removepoint"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_removepoint"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_removepoint"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_removepoint"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_removerepeatedpoints"("geom" "public"."geometry", "tolerance" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_removerepeatedpoints"("geom" "public"."geometry", "tolerance" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_removerepeatedpoints"("geom" "public"."geometry", "tolerance" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_removerepeatedpoints"("geom" "public"."geometry", "tolerance" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_reverse"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_reverse"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_reverse"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_reverse"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotatex"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotatex"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotatex"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotatex"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotatey"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotatey"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotatey"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotatey"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotatez"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotatez"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotatez"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotatez"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry", "origin" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry", "origin" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry", "origin" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry", "origin" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scroll"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scroll"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_scroll"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scroll"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_segmentize"("geog" "public"."geography", "max_segment_length" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_segmentize"("geog" "public"."geography", "max_segment_length" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_segmentize"("geog" "public"."geography", "max_segment_length" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_segmentize"("geog" "public"."geography", "max_segment_length" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_segmentize"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_segmentize"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_segmentize"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_segmentize"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_seteffectivearea"("public"."geometry", double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_seteffectivearea"("public"."geometry", double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_seteffectivearea"("public"."geometry", double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_seteffectivearea"("public"."geometry", double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_setpoint"("public"."geometry", integer, "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_setpoint"("public"."geometry", integer, "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_setpoint"("public"."geometry", integer, "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_setpoint"("public"."geometry", integer, "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_setsrid"("geog" "public"."geography", "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geog" "public"."geography", "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geog" "public"."geography", "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geog" "public"."geography", "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_setsrid"("geom" "public"."geometry", "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geom" "public"."geometry", "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geom" "public"."geometry", "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geom" "public"."geometry", "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_sharedpaths"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_sharedpaths"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_sharedpaths"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_sharedpaths"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_shiftlongitude"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_shiftlongitude"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_shiftlongitude"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_shiftlongitude"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_shortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_shortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_shortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_shortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplifypolygonhull"("geom" "public"."geometry", "vertex_fraction" double precision, "is_outer" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplifypolygonhull"("geom" "public"."geometry", "vertex_fraction" double precision, "is_outer" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplifypolygonhull"("geom" "public"."geometry", "vertex_fraction" double precision, "is_outer" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplifypolygonhull"("geom" "public"."geometry", "vertex_fraction" double precision, "is_outer" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplifypreservetopology"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplifypreservetopology"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplifypreservetopology"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplifypreservetopology"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplifyvw"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplifyvw"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplifyvw"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplifyvw"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snap"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snap"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snap"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snap"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snaptogrid"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_split"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_split"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_split"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_split"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_square"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_square"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_square"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_square"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_squaregrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_squaregrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_squaregrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_squaregrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_srid"("geog" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_srid"("geog" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_srid"("geog" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_srid"("geog" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_srid"("geom" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_srid"("geom" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_srid"("geom" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_srid"("geom" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_startpoint"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_startpoint"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_startpoint"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_startpoint"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_subdivide"("geom" "public"."geometry", "maxvertices" integer, "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_subdivide"("geom" "public"."geometry", "maxvertices" integer, "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_subdivide"("geom" "public"."geometry", "maxvertices" integer, "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_subdivide"("geom" "public"."geometry", "maxvertices" integer, "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_summary"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_summary"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_swapordinates"("geom" "public"."geometry", "ords" "cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_swapordinates"("geom" "public"."geometry", "ords" "cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."st_swapordinates"("geom" "public"."geometry", "ords" "cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_swapordinates"("geom" "public"."geometry", "ords" "cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_symdifference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_symdifference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_symdifference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_symdifference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_symmetricdifference"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_symmetricdifference"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_symmetricdifference"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_symmetricdifference"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_tileenvelope"("zoom" integer, "x" integer, "y" integer, "bounds" "public"."geometry", "margin" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_tileenvelope"("zoom" integer, "x" integer, "y" integer, "bounds" "public"."geometry", "margin" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_tileenvelope"("zoom" integer, "x" integer, "y" integer, "bounds" "public"."geometry", "margin" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_tileenvelope"("zoom" integer, "x" integer, "y" integer, "bounds" "public"."geometry", "margin" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transform"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transform"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_transform"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transform"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "to_proj" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "to_proj" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "to_proj" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "to_proj" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_proj" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_proj" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_proj" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_proj" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transscale"("public"."geometry", double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transscale"("public"."geometry", double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_transscale"("public"."geometry", double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transscale"("public"."geometry", double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_triangulatepolygon"("g1" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_triangulatepolygon"("g1" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_triangulatepolygon"("g1" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_triangulatepolygon"("g1" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_unaryunion"("public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_unaryunion"("public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_unaryunion"("public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_unaryunion"("public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_voronoilines"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_voronoilines"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_voronoilines"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_voronoilines"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_voronoipolygons"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_voronoipolygons"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_voronoipolygons"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_voronoipolygons"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_wkbtosql"("wkb" "bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_wkbtosql"("wkb" "bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_wkbtosql"("wkb" "bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_wkbtosql"("wkb" "bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_wkttosql"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_wkttosql"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_wkttosql"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_wkttosql"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_wrapx"("geom" "public"."geometry", "wrap" double precision, "move" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_wrapx"("geom" "public"."geometry", "wrap" double precision, "move" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_wrapx"("geom" "public"."geometry", "wrap" double precision, "move" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_wrapx"("geom" "public"."geometry", "wrap" double precision, "move" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_x"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_x"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_x"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_x"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_xmax"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_xmax"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_xmax"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_xmax"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_xmin"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_xmin"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_xmin"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_xmin"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_y"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_y"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_y"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_y"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ymax"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ymax"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ymax"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ymax"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ymin"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ymin"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ymin"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ymin"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_z"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_z"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_z"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_z"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_zmax"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_zmax"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_zmax"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_zmax"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_zmflag"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_zmflag"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_zmflag"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_zmflag"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_zmin"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_zmin"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_zmin"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_zmin"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."touch_social_review_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."touch_social_review_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."touch_social_review_updated_at"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."track_app_event"("p_event_name" "text", "p_event_category" "text", "p_session_id" "text", "p_anon_id" "uuid", "p_screen_name" "text", "p_feature_name" "text", "p_duration_ms" integer, "p_occurred_at" timestamp with time zone, "p_app_version" "text", "p_build_number" "text", "p_platform" "text", "p_os_version" "text", "p_locale" "text", "p_timezone" "text", "p_properties" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."track_app_event"("p_event_name" "text", "p_event_category" "text", "p_session_id" "text", "p_anon_id" "uuid", "p_screen_name" "text", "p_feature_name" "text", "p_duration_ms" integer, "p_occurred_at" timestamp with time zone, "p_app_version" "text", "p_build_number" "text", "p_platform" "text", "p_os_version" "text", "p_locale" "text", "p_timezone" "text", "p_properties" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."track_app_event"("p_event_name" "text", "p_event_category" "text", "p_session_id" "text", "p_anon_id" "uuid", "p_screen_name" "text", "p_feature_name" "text", "p_duration_ms" integer, "p_occurred_at" timestamp with time zone, "p_app_version" "text", "p_build_number" "text", "p_platform" "text", "p_os_version" "text", "p_locale" "text", "p_timezone" "text", "p_properties" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."track_app_event"("p_event_name" "text", "p_event_category" "text", "p_session_id" "text", "p_anon_id" "uuid", "p_screen_name" "text", "p_feature_name" "text", "p_duration_ms" integer, "p_occurred_at" timestamp with time zone, "p_app_version" "text", "p_build_number" "text", "p_platform" "text", "p_os_version" "text", "p_locale" "text", "p_timezone" "text", "p_properties" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_locations_propagate_geog"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_locations_propagate_geog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_locations_propagate_geog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_locations_set_geog"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_locations_set_geog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_locations_set_geog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_lpa_fill_geog"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_lpa_fill_geog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_lpa_fill_geog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_user_location_actions_share_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_user_location_actions_share_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_user_location_actions_share_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."unblock_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."unblock_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unblock_user"("p_blocker_id" "uuid", "p_blocked_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."unfollow_user"("p_follower_id" "uuid", "p_followee_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."unfollow_user"("p_follower_id" "uuid", "p_followee_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unfollow_user"("p_follower_id" "uuid", "p_followee_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."unlockrows"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."unlockrows"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."unlockrows"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unlockrows"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."unsave_collection"("p_collection_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."unsave_collection"("p_collection_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unsave_collection"("p_collection_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."unsave_location"("p_user_id" "uuid", "p_location_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."unsave_location"("p_user_id" "uuid", "p_location_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."unsave_location"("p_user_id" "uuid", "p_location_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text", "p_is_public" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text", "p_is_public" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_collection"("p_collection_id" "uuid", "p_name" "text", "p_cover_color" "text", "p_is_public" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_fcm_token"("p_user_id" "uuid", "p_fcm_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_fcm_token"("p_user_id" "uuid", "p_fcm_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_fcm_token"("p_user_id" "uuid", "p_fcm_token" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_location_image_url"("p_location_id" bigint, "p_image_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_location_image_url"("p_location_id" bigint, "p_image_url" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_location_photo_reference"("p_location_id" bigint, "p_photo_reference" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_location_photo_reference"("p_location_id" bigint, "p_photo_reference" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_location_photos"("p_location_id" bigint, "p_photos" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_location_photos"("p_location_id" bigint, "p_photos" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_location_photos"("p_location_id" bigint, "p_photos" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_location_popularity"("p_location_id" integer, "p_saves_delta" integer, "p_likes_delta" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_location_popularity"("p_location_id" integer, "p_saves_delta" integer, "p_likes_delta" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_location_popularity"("p_location_id" integer, "p_saves_delta" integer, "p_likes_delta" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_location_review"("p_location_id" bigint, "p_content" "text", "p_rating" numeric, "p_gatekeep" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_location_review"("p_location_id" bigint, "p_content" "text", "p_rating" numeric, "p_gatekeep" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_location_review"("p_location_id" bigint, "p_content" "text", "p_rating" numeric, "p_gatekeep" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_user_location"("p_user_id" "uuid", "p_lat" double precision, "p_lng" double precision) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_user_location"("p_user_id" "uuid", "p_lat" double precision, "p_lng" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_location"("p_user_id" "uuid", "p_lat" double precision, "p_lng" double precision) TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_profile"("p_user_id" "uuid", "p_name" "text", "p_username" "text", "p_bio" "text", "p_profile_image_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_profile"("p_user_id" "uuid", "p_name" "text", "p_username" "text", "p_bio" "text", "p_profile_image_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_profile"("p_user_id" "uuid", "p_name" "text", "p_username" "text", "p_bio" "text", "p_profile_image_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, character varying, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, character varying, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, character varying, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, character varying, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."updategeometrysrid"("catalogn_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"("catalogn_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"("catalogn_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"("catalogn_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "rewards"."referrals" TO "authenticated";
GRANT ALL ON TABLE "rewards"."referrals" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "rewards"."referrals" TO "anon";



REVOKE ALL ON FUNCTION "rewards"."accept_pending_referral_for_user"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "rewards"."accept_pending_referral_for_user"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "rewards"."accept_pending_referral_for_user"("p_user_id" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "rewards"."accept_pending_referral_for_user"("p_user_id" "uuid") TO "anon";



REVOKE ALL ON FUNCTION "rewards"."admin_accept_pending_referral_for_user"("p_user_id" "uuid", "p_acceptance_trigger" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "rewards"."admin_accept_pending_referral_for_user"("p_user_id" "uuid", "p_acceptance_trigger" "text") TO "service_role";



REVOKE ALL ON FUNCTION "rewards"."apply_referral_code"("p_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "rewards"."apply_referral_code"("p_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "rewards"."apply_referral_code"("p_code" "text") TO "service_role";
GRANT ALL ON FUNCTION "rewards"."apply_referral_code"("p_code" "text") TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "rewards"."referral_codes" TO "authenticated";
GRANT ALL ON TABLE "rewards"."referral_codes" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "rewards"."referral_codes" TO "anon";



REVOKE ALL ON FUNCTION "rewards"."ensure_referral_code"() FROM PUBLIC;
GRANT ALL ON FUNCTION "rewards"."ensure_referral_code"() TO "service_role";



REVOKE ALL ON FUNCTION "rewards"."generate_referral_code"("p_owner_user_id" "uuid", "p_seed_text" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "rewards"."generate_referral_code"("p_owner_user_id" "uuid", "p_seed_text" "text") TO "service_role";
GRANT ALL ON FUNCTION "rewards"."generate_referral_code"("p_owner_user_id" "uuid", "p_seed_text" "text") TO "anon";
GRANT ALL ON FUNCTION "rewards"."generate_referral_code"("p_owner_user_id" "uuid", "p_seed_text" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "rewards"."get_my_referral_dashboard"() FROM PUBLIC;
GRANT ALL ON FUNCTION "rewards"."get_my_referral_dashboard"() TO "authenticated";
GRANT ALL ON FUNCTION "rewards"."get_my_referral_dashboard"() TO "service_role";
GRANT ALL ON FUNCTION "rewards"."get_my_referral_dashboard"() TO "anon";



REVOKE ALL ON FUNCTION "rewards"."issue_referral_vouchers"("p_referral" "rewards"."referrals") FROM PUBLIC;
GRANT ALL ON FUNCTION "rewards"."issue_referral_vouchers"("p_referral" "rewards"."referrals") TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "rewards"."vouchers" TO "authenticated";
GRANT ALL ON TABLE "rewards"."vouchers" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "rewards"."vouchers" TO "anon";



REVOKE ALL ON FUNCTION "rewards"."redeem_voucher"("p_voucher_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "rewards"."redeem_voucher"("p_voucher_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "rewards"."redeem_voucher"("p_voucher_id" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "rewards"."redeem_voucher"("p_voucher_id" "uuid") TO "anon";



GRANT ALL ON FUNCTION "rewards"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "rewards"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "rewards"."set_updated_at"() TO "service_role";



REVOKE ALL ON FUNCTION "rewards"."voucher_to_json"("p_voucher" "rewards"."vouchers") FROM PUBLIC;
GRANT ALL ON FUNCTION "rewards"."voucher_to_json"("p_voucher" "rewards"."vouchers") TO "service_role";












GRANT ALL ON FUNCTION "public"."st_3dextent"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dextent"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dextent"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dextent"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_extent"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_extent"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_extent"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_extent"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_memcollect"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_memcollect"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_memcollect"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_memcollect"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_memunion"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_memunion"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_memunion"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_memunion"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry", double precision) TO "service_role";















GRANT ALL ON TABLE "public"."app_analytics_events" TO "service_role";



GRANT ALL ON TABLE "public"."analytics_daily_user_activity" TO "service_role";



GRANT ALL ON TABLE "public"."analytics_feature_adoption_daily" TO "service_role";



GRANT ALL ON TABLE "public"."analytics_notification_funnel_daily" TO "service_role";



GRANT ALL ON TABLE "public"."analytics_retention_cohorts" TO "service_role";



GRANT ALL ON SEQUENCE "public"."app_analytics_events_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."bubble_locations" TO "anon";
GRANT ALL ON TABLE "public"."bubble_locations" TO "authenticated";
GRANT ALL ON TABLE "public"."bubble_locations" TO "service_role";



GRANT ALL ON TABLE "public"."bubble_members" TO "anon";
GRANT ALL ON TABLE "public"."bubble_members" TO "authenticated";
GRANT ALL ON TABLE "public"."bubble_members" TO "service_role";



GRANT ALL ON TABLE "public"."bubbles" TO "anon";
GRANT ALL ON TABLE "public"."bubbles" TO "authenticated";
GRANT ALL ON TABLE "public"."bubbles" TO "service_role";



GRANT ALL ON TABLE "public"."collection_locations" TO "authenticated";
GRANT ALL ON TABLE "public"."collection_locations" TO "service_role";



GRANT ALL ON TABLE "public"."collection_saves" TO "anon";
GRANT ALL ON TABLE "public"."collection_saves" TO "authenticated";
GRANT ALL ON TABLE "public"."collection_saves" TO "service_role";



GRANT ALL ON TABLE "public"."collections" TO "authenticated";
GRANT ALL ON TABLE "public"."collections" TO "service_role";



GRANT ALL ON TABLE "public"."internal_alert_config" TO "service_role";



GRANT ALL ON TABLE "public"."internal_alert_recipients" TO "service_role";



GRANT ALL ON TABLE "public"."location_popularity_app" TO "anon";
GRANT ALL ON TABLE "public"."location_popularity_app" TO "authenticated";
GRANT ALL ON TABLE "public"."location_popularity_app" TO "service_role";



GRANT ALL ON TABLE "public"."location_reviews" TO "anon";
GRANT ALL ON TABLE "public"."location_reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."location_reviews" TO "service_role";



GRANT ALL ON TABLE "public"."location_similarities" TO "service_role";



GRANT ALL ON SEQUENCE "public"."locations_location_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."locations_location_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."locations_location_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."social_post_actions" TO "service_role";



GRANT ALL ON SEQUENCE "public"."social_post_actions_social_post_action_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."social_post_actions_social_post_action_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."social_post_actions_social_post_action_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."social_post_place_reviews" TO "service_role";
GRANT SELECT,INSERT,UPDATE ON TABLE "public"."social_post_place_reviews" TO "authenticated";



GRANT ALL ON TABLE "public"."social_post_places" TO "service_role";
GRANT SELECT,INSERT ON TABLE "public"."social_post_places" TO "authenticated";



GRANT ALL ON TABLE "public"."social_post_reviews" TO "service_role";
GRANT SELECT,UPDATE ON TABLE "public"."social_post_reviews" TO "authenticated";



GRANT ALL ON TABLE "public"."social_posts" TO "service_role";
GRANT SELECT ON TABLE "public"."social_posts" TO "authenticated";



GRANT ALL ON TABLE "public"."tags" TO "anon";
GRANT ALL ON TABLE "public"."tags" TO "authenticated";
GRANT ALL ON TABLE "public"."tags" TO "service_role";



GRANT ALL ON TABLE "public"."user_chat_state" TO "anon";
GRANT ALL ON TABLE "public"."user_chat_state" TO "authenticated";
GRANT ALL ON TABLE "public"."user_chat_state" TO "service_role";



GRANT ALL ON TABLE "public"."user_bubble_chats" TO "authenticated";
GRANT ALL ON TABLE "public"."user_bubble_chats" TO "service_role";



GRANT ALL ON TABLE "public"."user_friends" TO "anon";
GRANT ALL ON TABLE "public"."user_friends" TO "authenticated";
GRANT ALL ON TABLE "public"."user_friends" TO "service_role";



GRANT ALL ON TABLE "public"."user_location_actions" TO "anon";
GRANT ALL ON TABLE "public"."user_location_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."user_location_actions" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_location_actions_action_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_location_actions_action_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_location_actions_action_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_recommendations" TO "anon";
GRANT ALL ON TABLE "public"."user_recommendations" TO "authenticated";
GRANT ALL ON TABLE "public"."user_recommendations" TO "service_role";



GRANT ALL ON TABLE "public"."v_action_exists" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER ON TABLE "public"."video_insights" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER ON TABLE "public"."video_insights" TO "authenticated";
GRANT ALL ON TABLE "public"."video_insights" TO "service_role";



GRANT ALL ON TABLE "public"."waitlist" TO "anon";
GRANT ALL ON TABLE "public"."waitlist" TO "authenticated";
GRANT ALL ON TABLE "public"."waitlist" TO "service_role";



GRANT ALL ON TABLE "public"."worldcup_notification_drafts" TO "anon";
GRANT ALL ON TABLE "public"."worldcup_notification_drafts" TO "authenticated";
GRANT ALL ON TABLE "public"."worldcup_notification_drafts" TO "service_role";



GRANT ALL ON TABLE "public"."worldcup_notification_recipients" TO "anon";
GRANT ALL ON TABLE "public"."worldcup_notification_recipients" TO "authenticated";
GRANT ALL ON TABLE "public"."worldcup_notification_recipients" TO "service_role";



GRANT ALL ON TABLE "rewards"."promo_code_vouchers" TO "service_role";



GRANT ALL ON TABLE "rewards"."voucher_source_type_rules" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";































-- ---------------------------------------------------------------------------
-- Storage (not included in `db dump`)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public) values
  ('profile_photos', 'profile_photos', true),
  ('location_photos', 'location_photos', true),
  ('collection_covers', 'collection_covers', true)
on conflict (id) do nothing;

create policy "Authenticated users can read 1kxk1qw_0" on storage.objects
  for select to authenticated using (bucket_id = 'profile_photos');
create policy "Users can upload own profile photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'profile_photos' and split_part(name, '/', 1) = auth.uid()::text);
create policy "Users can update own profile photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'profile_photos' and split_part(name, '/', 1) = auth.uid()::text)
  with check (bucket_id = 'profile_photos' and split_part(name, '/', 1) = auth.uid()::text);
create policy "Users can delete own profile photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'profile_photos' and split_part(name, '/', 1) = auth.uid()::text);

create policy "Allow public reads" on storage.objects
  for select using (bucket_id = 'location_photos');
create policy "Allow authenticated uploads" on storage.objects
  for insert to authenticated with check (bucket_id = 'location_photos');
create policy "Allow authenticated updates" on storage.objects
  for update to authenticated
  using (bucket_id = 'location_photos') with check (bucket_id = 'location_photos');

create policy "Collection covers are publicly readable" on storage.objects
  for select using (bucket_id = 'collection_covers');
create policy "Users can upload collection covers" on storage.objects
  for insert to authenticated with check (bucket_id = 'collection_covers');
create policy "Users can update collection covers" on storage.objects
  for update to authenticated using (bucket_id = 'collection_covers');

-- ---------------------------------------------------------------------------
-- pg_cron jobs (not included in `db dump`)
-- ---------------------------------------------------------------------------
select cron.schedule('refresh-location-quality', '0 3 * * *',
  $$SELECT refresh_location_quality_scores();$$);
select cron.schedule('cleanup_old_app_analytics_events_daily', '15 3 * * *',
  $$SELECT public.cleanup_old_app_analytics_events(INTERVAL '7 days');$$);

-- ---------------------------------------------------------------------------
-- Privileges production has revoked from the default anon/authenticated grants
-- (pg_dump cannot express these relative to ALTER DEFAULT PRIVILEGES).
-- ---------------------------------------------------------------------------
revoke delete on table "public"."app_analytics_events" from "anon";
revoke insert on table "public"."app_analytics_events" from "anon";
revoke references on table "public"."app_analytics_events" from "anon";
revoke select on table "public"."app_analytics_events" from "anon";
revoke trigger on table "public"."app_analytics_events" from "anon";
revoke truncate on table "public"."app_analytics_events" from "anon";
revoke update on table "public"."app_analytics_events" from "anon";
revoke delete on table "public"."app_analytics_events" from "authenticated";
revoke insert on table "public"."app_analytics_events" from "authenticated";
revoke references on table "public"."app_analytics_events" from "authenticated";
revoke select on table "public"."app_analytics_events" from "authenticated";
revoke trigger on table "public"."app_analytics_events" from "authenticated";
revoke truncate on table "public"."app_analytics_events" from "authenticated";
revoke update on table "public"."app_analytics_events" from "authenticated";
revoke delete on table "public"."collection_locations" from "anon";
revoke insert on table "public"."collection_locations" from "anon";
revoke references on table "public"."collection_locations" from "anon";
revoke select on table "public"."collection_locations" from "anon";
revoke trigger on table "public"."collection_locations" from "anon";
revoke truncate on table "public"."collection_locations" from "anon";
revoke update on table "public"."collection_locations" from "anon";
revoke delete on table "public"."collections" from "anon";
revoke insert on table "public"."collections" from "anon";
revoke references on table "public"."collections" from "anon";
revoke select on table "public"."collections" from "anon";
revoke trigger on table "public"."collections" from "anon";
revoke truncate on table "public"."collections" from "anon";
revoke update on table "public"."collections" from "anon";
revoke delete on table "public"."internal_alert_config" from "anon";
revoke insert on table "public"."internal_alert_config" from "anon";
revoke references on table "public"."internal_alert_config" from "anon";
revoke select on table "public"."internal_alert_config" from "anon";
revoke trigger on table "public"."internal_alert_config" from "anon";
revoke truncate on table "public"."internal_alert_config" from "anon";
revoke update on table "public"."internal_alert_config" from "anon";
revoke delete on table "public"."internal_alert_config" from "authenticated";
revoke insert on table "public"."internal_alert_config" from "authenticated";
revoke references on table "public"."internal_alert_config" from "authenticated";
revoke select on table "public"."internal_alert_config" from "authenticated";
revoke trigger on table "public"."internal_alert_config" from "authenticated";
revoke truncate on table "public"."internal_alert_config" from "authenticated";
revoke update on table "public"."internal_alert_config" from "authenticated";
revoke delete on table "public"."internal_alert_recipients" from "anon";
revoke insert on table "public"."internal_alert_recipients" from "anon";
revoke references on table "public"."internal_alert_recipients" from "anon";
revoke select on table "public"."internal_alert_recipients" from "anon";
revoke trigger on table "public"."internal_alert_recipients" from "anon";
revoke truncate on table "public"."internal_alert_recipients" from "anon";
revoke update on table "public"."internal_alert_recipients" from "anon";
revoke delete on table "public"."internal_alert_recipients" from "authenticated";
revoke insert on table "public"."internal_alert_recipients" from "authenticated";
revoke references on table "public"."internal_alert_recipients" from "authenticated";
revoke select on table "public"."internal_alert_recipients" from "authenticated";
revoke trigger on table "public"."internal_alert_recipients" from "authenticated";
revoke truncate on table "public"."internal_alert_recipients" from "authenticated";
revoke update on table "public"."internal_alert_recipients" from "authenticated";
revoke delete on table "public"."location_similarities" from "anon";
revoke insert on table "public"."location_similarities" from "anon";
revoke references on table "public"."location_similarities" from "anon";
revoke select on table "public"."location_similarities" from "anon";
revoke trigger on table "public"."location_similarities" from "anon";
revoke truncate on table "public"."location_similarities" from "anon";
revoke update on table "public"."location_similarities" from "anon";
revoke delete on table "public"."location_similarities" from "authenticated";
revoke insert on table "public"."location_similarities" from "authenticated";
revoke references on table "public"."location_similarities" from "authenticated";
revoke select on table "public"."location_similarities" from "authenticated";
revoke trigger on table "public"."location_similarities" from "authenticated";
revoke truncate on table "public"."location_similarities" from "authenticated";
revoke update on table "public"."location_similarities" from "authenticated";
revoke delete on table "public"."locations" from "anon";
revoke insert on table "public"."locations" from "anon";
revoke truncate on table "public"."locations" from "anon";
revoke update on table "public"."locations" from "anon";
revoke delete on table "public"."locations" from "authenticated";
revoke insert on table "public"."locations" from "authenticated";
revoke truncate on table "public"."locations" from "authenticated";
revoke update on table "public"."locations" from "authenticated";
revoke delete on table "public"."notifications" from "anon";
revoke insert on table "public"."notifications" from "anon";
revoke references on table "public"."notifications" from "anon";
revoke select on table "public"."notifications" from "anon";
revoke trigger on table "public"."notifications" from "anon";
revoke truncate on table "public"."notifications" from "anon";
revoke update on table "public"."notifications" from "anon";
revoke delete on table "public"."social_post_actions" from "anon";
revoke insert on table "public"."social_post_actions" from "anon";
revoke references on table "public"."social_post_actions" from "anon";
revoke select on table "public"."social_post_actions" from "anon";
revoke trigger on table "public"."social_post_actions" from "anon";
revoke truncate on table "public"."social_post_actions" from "anon";
revoke update on table "public"."social_post_actions" from "anon";
revoke delete on table "public"."social_post_actions" from "authenticated";
revoke insert on table "public"."social_post_actions" from "authenticated";
revoke references on table "public"."social_post_actions" from "authenticated";
revoke select on table "public"."social_post_actions" from "authenticated";
revoke trigger on table "public"."social_post_actions" from "authenticated";
revoke truncate on table "public"."social_post_actions" from "authenticated";
revoke update on table "public"."social_post_actions" from "authenticated";
revoke delete on table "public"."social_post_place_reviews" from "anon";
revoke insert on table "public"."social_post_place_reviews" from "anon";
revoke references on table "public"."social_post_place_reviews" from "anon";
revoke select on table "public"."social_post_place_reviews" from "anon";
revoke trigger on table "public"."social_post_place_reviews" from "anon";
revoke truncate on table "public"."social_post_place_reviews" from "anon";
revoke update on table "public"."social_post_place_reviews" from "anon";
revoke delete on table "public"."social_post_place_reviews" from "authenticated";
revoke references on table "public"."social_post_place_reviews" from "authenticated";
revoke trigger on table "public"."social_post_place_reviews" from "authenticated";
revoke truncate on table "public"."social_post_place_reviews" from "authenticated";
revoke delete on table "public"."social_post_places" from "anon";
revoke insert on table "public"."social_post_places" from "anon";
revoke references on table "public"."social_post_places" from "anon";
revoke select on table "public"."social_post_places" from "anon";
revoke trigger on table "public"."social_post_places" from "anon";
revoke truncate on table "public"."social_post_places" from "anon";
revoke update on table "public"."social_post_places" from "anon";
revoke delete on table "public"."social_post_places" from "authenticated";
revoke references on table "public"."social_post_places" from "authenticated";
revoke trigger on table "public"."social_post_places" from "authenticated";
revoke truncate on table "public"."social_post_places" from "authenticated";
revoke update on table "public"."social_post_places" from "authenticated";
revoke delete on table "public"."social_post_reviews" from "anon";
revoke insert on table "public"."social_post_reviews" from "anon";
revoke references on table "public"."social_post_reviews" from "anon";
revoke select on table "public"."social_post_reviews" from "anon";
revoke trigger on table "public"."social_post_reviews" from "anon";
revoke truncate on table "public"."social_post_reviews" from "anon";
revoke update on table "public"."social_post_reviews" from "anon";
revoke delete on table "public"."social_post_reviews" from "authenticated";
revoke insert on table "public"."social_post_reviews" from "authenticated";
revoke references on table "public"."social_post_reviews" from "authenticated";
revoke trigger on table "public"."social_post_reviews" from "authenticated";
revoke truncate on table "public"."social_post_reviews" from "authenticated";
revoke delete on table "public"."social_posts" from "anon";
revoke insert on table "public"."social_posts" from "anon";
revoke references on table "public"."social_posts" from "anon";
revoke select on table "public"."social_posts" from "anon";
revoke trigger on table "public"."social_posts" from "anon";
revoke truncate on table "public"."social_posts" from "anon";
revoke update on table "public"."social_posts" from "anon";
revoke delete on table "public"."social_posts" from "authenticated";
revoke insert on table "public"."social_posts" from "authenticated";
revoke references on table "public"."social_posts" from "authenticated";
revoke trigger on table "public"."social_posts" from "authenticated";
revoke truncate on table "public"."social_posts" from "authenticated";
revoke update on table "public"."social_posts" from "authenticated";
revoke delete on table "public"."v_action_exists" from "anon";
revoke insert on table "public"."v_action_exists" from "anon";
revoke references on table "public"."v_action_exists" from "anon";
revoke select on table "public"."v_action_exists" from "anon";
revoke trigger on table "public"."v_action_exists" from "anon";
revoke truncate on table "public"."v_action_exists" from "anon";
revoke update on table "public"."v_action_exists" from "anon";
revoke delete on table "public"."v_action_exists" from "authenticated";
revoke insert on table "public"."v_action_exists" from "authenticated";
revoke references on table "public"."v_action_exists" from "authenticated";
revoke select on table "public"."v_action_exists" from "authenticated";
revoke trigger on table "public"."v_action_exists" from "authenticated";
revoke truncate on table "public"."v_action_exists" from "authenticated";
revoke update on table "public"."v_action_exists" from "authenticated";
revoke delete on table "public"."video_insights" from "anon";
revoke insert on table "public"."video_insights" from "anon";
revoke truncate on table "public"."video_insights" from "anon";
revoke update on table "public"."video_insights" from "anon";
revoke delete on table "public"."video_insights" from "authenticated";
revoke insert on table "public"."video_insights" from "authenticated";
revoke truncate on table "public"."video_insights" from "authenticated";
revoke update on table "public"."video_insights" from "authenticated";
