CREATE OR REPLACE FUNCTION public.update_location_popularity(p_location_id integer, p_saves_delta integer DEFAULT 0, p_likes_delta integer DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
     BEGIN
       INSERT INTO location_popularity_app (location_id, saves_count, likes_count,
     updated_at)
       VALUES (p_location_id, GREATEST(p_saves_delta, 0), GREATEST(p_likes_delta, 0),
     NOW())
       ON CONFLICT (location_id) DO UPDATE SET
         saves_count = GREATEST(location_popularity_app.saves_count + p_saves_delta, 0),
         likes_count = GREATEST(location_popularity_app.likes_count + p_likes_delta, 0),
         updated_at = NOW();
     END;
     $function$
;
