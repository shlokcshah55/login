CREATE OR REPLACE FUNCTION public.increment_dislikes_count(loc_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$BEGIN
    -- Update the location_popularity_app table
    UPDATE location_popularity_app
    SET dislikes_count = dislikes_count + 1,
        updated_at = NOW()
    WHERE location_id = loc_id;

    -- If no row exists yet, insert one
    IF NOT FOUND THEN
      INSERT INTO location_popularity_app (location_id, saves_count, dislikes_count, updated_at)
      VALUES (loc_id, 0, 1, NOW());
    END IF;
  END;$function$
;
