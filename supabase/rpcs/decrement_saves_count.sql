CREATE OR REPLACE FUNCTION public.decrement_saves_count(loc_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
  BEGIN
    -- Update the location_popularity_app table
    UPDATE location_popularity_app
    SET saves_count = GREATEST(saves_count - 1, 0), -- Prevent negative counts
        updated_at = NOW()
    WHERE location_id = loc_id;

    -- If no row exists yet, insert one with count 0
    IF NOT FOUND THEN
      INSERT INTO location_popularity_app (location_id, saves_count, likes_count, updated_at)
      VALUES (loc_id, 0, 0, NOW());
    END IF;
  END;
  $function$
;
