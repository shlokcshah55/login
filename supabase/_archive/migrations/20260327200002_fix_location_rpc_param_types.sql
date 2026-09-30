-- Drop old text-param overloads
DROP FUNCTION IF EXISTS public.update_location_photo_reference(text, text);
DROP FUNCTION IF EXISTS public.update_location_image_url(text, text);

-- Fix update_location_photo_reference
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

-- Fix update_location_image_url
CREATE OR REPLACE FUNCTION public.update_location_image_url(p_location_id bigint, p_image_url text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE locations
  SET image_stored = true
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$function$;
