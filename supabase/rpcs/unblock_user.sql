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
