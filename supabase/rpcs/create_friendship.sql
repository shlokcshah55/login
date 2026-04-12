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
