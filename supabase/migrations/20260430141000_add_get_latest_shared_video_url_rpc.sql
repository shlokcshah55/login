DROP FUNCTION IF EXISTS public.get_latest_shared_video_url(bigint);

CREATE OR REPLACE FUNCTION public.get_latest_shared_video_url(
    p_location_id bigint
)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path TO 'public'
AS $function$
    SELECT ula.source_video_url
    FROM public.user_location_actions ula
    WHERE ula.location_id = p_location_id
      AND ula.source_video_url IS NOT NULL
      AND btrim(ula.source_video_url) <> ''
    ORDER BY ula.created_at DESC
    LIMIT 1;
$function$
;

GRANT EXECUTE ON FUNCTION public.get_latest_shared_video_url(bigint)
    TO anon, authenticated, service_role;

