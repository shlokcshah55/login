CREATE OR REPLACE FUNCTION public.create_user_profile(p_supabase_id uuid, p_email text, p_name text, p_username text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$BEGIN
  INSERT INTO public.users (supabase_id, email, name, created_at, wizard_completed, username)
  VALUES (p_supabase_id, p_email, p_name, NOW(), false, p_username);
END;$function$
;
