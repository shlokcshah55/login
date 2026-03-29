CREATE OR REPLACE FUNCTION public.increment_saves_count(loc_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$BEGIN
    -- Update the location_popularity_app table
    UPDATE location_popularity_app
    SET saves_count = saves_count + 1,
        updated_at = NOW()
    WHERE location_id = loc_id;

    -- If no row exists yet, insert one
    IF NOT FOUND THEN
      INSERT INTO location_popularity_app (location_id, saves_count, dislikes_count, updated_at)
      VALUES (loc_id, 1, 0, NOW());
    END IF;
  END;$function$
;
