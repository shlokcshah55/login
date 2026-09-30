DROP FUNCTION IF EXISTS public.get_hottest_shared_places(integer);

CREATE OR REPLACE FUNCTION public.get_hottest_shared_places(
    p_limit integer DEFAULT 10
)
RETURNS SETOF public.locations
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path TO 'public'
AS $function$
    SELECT l.*
    FROM public.locations l
    INNER JOIN public.location_popularity_app lpa
        ON l.location_id = lpa.location_id
    WHERE EXISTS (
        SELECT 1
        FROM public.user_location_actions ula
        WHERE ula.location_id = l.location_id
          AND ula.action = 'save'
          AND ula.source_video_url IS NOT NULL
          AND btrim(ula.source_video_url) <> ''
    )
    ORDER BY
        COALESCE(lpa.app_engagement_score, 0.0) DESC,
        COALESCE(lpa.share_count, 0) DESC,
        lpa.updated_at DESC
    LIMIT COALESCE(p_limit, 10);
$function$
;

GRANT EXECUTE ON FUNCTION public.get_hottest_shared_places(integer)
    TO anon, authenticated, service_role;
