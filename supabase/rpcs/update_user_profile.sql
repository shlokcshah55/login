CREATE OR REPLACE FUNCTION public.update_user_profile(p_user_id uuid, p_name text DEFAULT NULL::text, p_username text DEFAULT NULL::text, p_bio text DEFAULT NULL::text, p_profile_image_url text DEFAULT NULL::text)
 RETURNS SETOF users
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  UPDATE public.users AS u  -- Use an alias 'u'
  SET
    name = COALESCE(p_name, u.name),
    username = COALESCE(p_username, u.username),
    bio = COALESCE(p_bio, u.bio),
    profile_image_url = COALESCE(p_profile_image_url, u.profile_image_url)
  WHERE u.supabase_id = p_user_id -- Explicitly reference the table alias
  RETURNING u.*;
END;
$function$
;
