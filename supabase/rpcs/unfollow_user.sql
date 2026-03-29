CREATE OR REPLACE FUNCTION public.unfollow_user(p_follower_id uuid, p_followee_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  BEGIN
    DELETE FROM user_friends
    WHERE follower_id = p_follower_id
      AND followee_id = p_followee_id;
  END;
  $function$
;
