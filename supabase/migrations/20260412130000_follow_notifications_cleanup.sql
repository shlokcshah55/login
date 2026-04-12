-- Follow request / accept notifications are now sent by the send-push-notifications
-- Cloud Function (called from the Flutter client). The previous version of these
-- RPCs inserted notification rows directly, which would cause duplicates with the
-- Cloud Function path. This migration strips the inserts back out.

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
