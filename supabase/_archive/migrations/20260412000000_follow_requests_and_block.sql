-- Follow request notifications, accept/reject/block flow, and list getters.

-- create_friendship: writes the user_friends row only. The notification row + FCM
-- push are handled by the send-push-notifications Cloud Function, called from the
-- Flutter client after this RPC succeeds.
CREATE OR REPLACE FUNCTION public.create_friendship(p_follower_id uuid, p_followee_id uuid, p_status text DEFAULT 'requested'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

-- accept_friendship: corrects the WHERE direction and clears the inbound follow_request
-- notification. The follow_accepted notification + FCM push are sent by the Cloud
-- Function from the Flutter client after this RPC succeeds.
CREATE OR REPLACE FUNCTION public.accept_friendship(request_from_id uuid, user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.reject_friendship(request_from_id uuid, user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.block_user(p_blocker_id uuid, p_blocked_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.unblock_user(p_blocker_id uuid, p_blocked_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  DELETE FROM public.user_friends
  WHERE follower_id = p_blocker_id
    AND followee_id = p_blocked_id
    AND status = 'blocked'::relationship_status;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_incoming_follow_requests(p_user_id uuid)
 RETURNS SETOF public.users
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT u.*
  FROM public.user_friends f
  JOIN public.users u ON u.supabase_id = f.follower_id
  WHERE f.followee_id = p_user_id
    AND f.status = 'requested'::relationship_status
  ORDER BY f.created_at DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.get_followers(p_user_id uuid)
 RETURNS SETOF public.users
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT u.*
  FROM public.user_friends f
  JOIN public.users u ON u.supabase_id = f.follower_id
  WHERE f.followee_id = p_user_id
    AND f.status = 'accepted'::relationship_status
  ORDER BY f.created_at DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.get_following(p_user_id uuid)
 RETURNS SETOF public.users
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT u.*
  FROM public.user_friends f
  JOIN public.users u ON u.supabase_id = f.followee_id
  WHERE f.follower_id = p_user_id
    AND f.status = 'accepted'::relationship_status
  ORDER BY f.created_at DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.get_blocked_users(p_user_id uuid)
 RETURNS SETOF public.users
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT u.*
  FROM public.user_friends f
  JOIN public.users u ON u.supabase_id = f.followee_id
  WHERE f.follower_id = p_user_id
    AND f.status = 'blocked'::relationship_status
  ORDER BY f.created_at DESC;
$function$
;

GRANT ALL ON FUNCTION public.reject_friendship(uuid, uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.block_user(uuid, uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.unblock_user(uuid, uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.get_incoming_follow_requests(uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.get_followers(uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.get_following(uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.get_blocked_users(uuid) TO anon, authenticated, service_role;
