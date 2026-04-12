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
