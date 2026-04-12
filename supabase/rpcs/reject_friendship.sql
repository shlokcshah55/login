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
  WHERE user_id = reject_friendship.user_id
    AND type = 'follow_request'
    AND (metadata ->> 'userId') = request_from_id::text;
END;
$function$
;
