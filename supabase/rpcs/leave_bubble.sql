CREATE OR REPLACE FUNCTION public.leave_bubble(p_bubble_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  BEGIN
    DELETE FROM bubble_members
    WHERE bubble_id = p_bubble_id
      AND user_id = p_user_id;
  END;
  $function$
;
