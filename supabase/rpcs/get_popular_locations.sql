CREATE OR REPLACE FUNCTION public.get_popular_locations(p_limit integer)
 RETURNS TABLE("like" locations)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT l.*
    FROM locations l
    INNER JOIN location_popularity_app lpa ON l.location_id = lpa.location_id
    ORDER BY (lpa.saves_count - COALESCE(lpa.dislikes_count, 0)) DESC, lpa.updated_at DESC
    LIMIT p_limit;
END;
$function$
;
