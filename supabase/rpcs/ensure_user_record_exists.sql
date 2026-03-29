CREATE OR REPLACE FUNCTION public.ensure_user_record_exists(p_supabase_id uuid, p_email text, p_name text, p_username text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.users (
    supabase_id, 
    email, 
    name, 
    username, -- Column that was causing the error
    created_at, 
    wizard_completed
  )
  VALUES (
    p_supabase_id, 
    p_email, 
    p_name, 
    p_username, 
    NOW(), 
    false
  )
  ON CONFLICT (supabase_id) DO NOTHING;

  RETURN p_supabase_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.ensure_user_record_exists(p_supabase_id uuid, p_email text, p_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$BEGIN
       INSERT INTO users (supabase_id, email, name, created_at, wizard_completed)
       VALUES (p_supabase_id, p_email, p_name, NOW(), false)
       ON CONFLICT (supabase_id) DO NOTHING;

       RETURN p_supabase_id;
     END;$function$
;
