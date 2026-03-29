CREATE OR REPLACE FUNCTION public.update_location_image_url(p_location_id bigint, p_image_url text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$BEGIN
  UPDATE locations
  SET image_stored = true
  WHERE location_id = p_location_id;
  
  -- Optional: Raise exception if no rows were updated
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;$function$
;
