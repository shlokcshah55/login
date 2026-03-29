CREATE OR REPLACE FUNCTION public.acknowledge_location(p_user_id uuid, p_location_id integer, p_acked boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
     BEGIN
       UPDATE user_location_actions
       SET acked = p_acked
       WHERE user_id = p_user_id
         AND location_id = p_location_id;
     END;
     $function$
;
