CREATE OR REPLACE FUNCTION public.get_popular_locations(
    p_limit integer,
    p_lat double precision,
    p_lng double precision
)
 RETURNS TABLE("like" locations)
 LANGUAGE plpgsql
AS $function$
DECLARE
    user_geog geography := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
BEGIN
    RETURN QUERY
    SELECT l.*
    FROM locations l
    INNER JOIN location_popularity_app lpa ON l.location_id = lpa.location_id
    ORDER BY
        -- Blend popularity score with proximity: higher popularity and closer distance both rank higher.
        -- Popularity score is normalised roughly to [0, ~1000]; distance in km is added as a penalty.
        (lpa.saves_count - COALESCE(lpa.dislikes_count, 0))
        - (ST_Distance(l.geog, user_geog) / 1000.0)  -- subtract distance_km as penalty
        DESC,
        lpa.updated_at DESC
    LIMIT p_limit;
END;
$function$
;
