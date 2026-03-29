CREATE OR REPLACE FUNCTION public.add_bubble_location(p_bubble_id uuid, p_location_id bigint, p_added_by uuid, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.bubble_locations (
    bubble_id,
    location_id,
    added_by,
    note,
    added_at
  ) VALUES (
    p_bubble_id,
    p_location_id,
    p_added_by,
    p_note,
    NOW()
  )
  ON CONFLICT DO NOTHING;
END;
$function$
;
