DROP FUNCTION IF EXISTS public.update_location_photo_reference(text, text);

CREATE OR REPLACE FUNCTION public.update_location_photo_reference(p_location_id bigint, p_photo_reference text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE locations
  SET photo_reference = p_photo_reference
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$function$;
