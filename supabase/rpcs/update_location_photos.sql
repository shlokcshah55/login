CREATE OR REPLACE FUNCTION public.update_location_photos(p_location_id bigint, p_photos jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE locations
  SET photos = p_photos,
      updated_at = now()
  WHERE location_id = p_location_id;
END;
$$;
