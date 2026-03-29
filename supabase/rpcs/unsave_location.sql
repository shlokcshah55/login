CREATE OR REPLACE FUNCTION public.unsave_location(p_user_id uuid, p_location_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
     BEGIN
       DELETE FROM user_location_actions
       WHERE user_id = p_user_id
         AND location_id = p_location_id
         AND action = 'save';
     END;
     $function$
;
