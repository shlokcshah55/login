-- ============================================================================
-- Replace get_followers, get_following, get_incoming_follow_requests, and
-- get_blocked_users so each returns the standard users columns PLUS
-- computed followers_count / following_count.
--
-- UserModel.fromJson already reads 'followers_count' and 'following_count',
-- so the Dart client picks them up automatically.
-- ============================================================================

-- Helper: reusable return type shared by all four RPCs.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_with_counts') THEN
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
      vibe_tag_affinity               integer[],
      dietary_requirement_tag_affinity integer[],
      followers_count                 bigint,
      following_count                 bigint
    );
  END IF;
END $$;

-- ── get_followers ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_followers(uuid);

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

-- ── get_following ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_following(uuid);

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

-- ── get_incoming_follow_requests ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_incoming_follow_requests(uuid);

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

-- ── get_blocked_users ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_blocked_users(uuid);

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

-- ── search_users RPC ───────────────────────────────────────────────────────
-- New server-side search that includes counts so the client doesn't need
-- N+1 queries.
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
