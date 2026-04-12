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

  -- Remove any inverse relationship (the blocked user following the blocker)
  DELETE FROM public.user_friends
  WHERE follower_id = p_blocked_id
    AND followee_id = p_blocker_id;

  -- Upsert the block row from blocker -> blocked
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

  -- Clean up any pending notifications between the two users
  DELETE FROM public.notifications
  WHERE user_id = p_blocker_id
    AND type = 'follow_request'
    AND (metadata ->> 'userId') = p_blocked_id::text;

  DELETE FROM public.notifications
  WHERE user_id = p_blocked_id
    AND type IN ('follow_request', 'follow_accepted')
    AND (metadata ->> 'userId') = p_blocker_id::text;
END;
$function$
;
