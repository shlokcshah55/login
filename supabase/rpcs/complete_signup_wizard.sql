CREATE OR REPLACE FUNCTION public.complete_signup_wizard(p_user_id uuid, p_spice_tolerance integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$BEGIN
       UPDATE users
       SET
         wizard_completed = true,
         spice_tolerance = COALESCE(p_spice_tolerance, spice_tolerance)
       WHERE supabase_id = p_user_id;
     END;$function$
;
