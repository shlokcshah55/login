CREATE OR REPLACE FUNCTION public.remove_location_from_bubble(p_bubble_id uuid, p_location_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
     BEGIN
       DELETE FROM bubble_locations
       WHERE bubble_id = p_bubble_id
         AND location_id = p_location_id;
     END;
     $function$
;
