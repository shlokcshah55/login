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
