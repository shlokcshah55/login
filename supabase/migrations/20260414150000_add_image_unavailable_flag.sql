-- Add image_unavailable flag to locations.
-- When Google Places API returns no photos for a location, this is set to true
-- so the app never attempts another API call for it.
ALTER TABLE locations
  ADD COLUMN IF NOT EXISTS image_unavailable boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.mark_location_image_unavailable(p_location_id bigint)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
AS $$
BEGIN
  UPDATE locations
  SET image_unavailable = true
  WHERE location_id = p_location_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Location with id % not found', p_location_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_location_image_unavailable(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_location_image_unavailable(bigint) TO service_role;
