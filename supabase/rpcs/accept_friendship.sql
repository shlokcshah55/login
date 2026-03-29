CREATE OR REPLACE FUNCTION public.accept_friendship(request_from_id uuid, user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Update the relationship status to 'accepted'
  UPDATE public.user_friends
  SET status = 'accepted'::relationship_status
  WHERE followee_id = request_from_id
    AND follower_id = user_id;
  
  -- Check if the update affected any rows
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Friend request not found';
  END IF;
END;
$function$
;
