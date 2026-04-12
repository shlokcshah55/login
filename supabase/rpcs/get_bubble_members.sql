DROP FUNCTION IF EXISTS public.get_bubble_members(uuid);

CREATE FUNCTION public.get_bubble_members(p_bubble_id uuid)
RETURNS TABLE(
  user_id uuid,
  supabase_id uuid,
  name text,
  profile_image_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    bm.user_id,
    u.supabase_id,
    u.name,
    u.profile_image_url
  FROM public.bubble_members bm
  INNER JOIN public.users u
    ON u.supabase_id = bm.user_id
  WHERE bm.bubble_id = p_bubble_id
  ORDER BY bm.created_at ASC;
END;
$function$;
