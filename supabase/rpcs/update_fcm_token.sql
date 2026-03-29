CREATE OR REPLACE FUNCTION public.update_fcm_token(p_user_id uuid, p_fcm_token text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
 BEGIN
   UPDATE users
   SET
     fcm_token = p_fcm_token,
     fcm_token_updated_at = NOW()
   WHERE supabase_id = p_user_id;
 END;
 $function$
;
