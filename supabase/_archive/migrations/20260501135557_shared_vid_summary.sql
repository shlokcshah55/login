DROP FUNCTION IF EXISTS public.get_shared_video_summaries(bigint[]);

CREATE OR REPLACE FUNCTION public.get_shared_video_summaries(
    p_location_ids bigint[]
)
RETURNS TABLE (
    location_id bigint,
    social_video_count integer,
    social_video_url text,
    social_video_creator_handle text,
    tiktok_recommended_dish text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path TO 'public'
AS $function$
    WITH shared_urls AS (
        SELECT
            ula.location_id,
            btrim(ula.source_video_url) AS source_video_url,
            COUNT(*) AS share_count,
            MAX(ula.created_at) AS latest_shared_at
        FROM public.user_location_actions ula
        WHERE ula.location_id = ANY(p_location_ids)
          AND ula.source_video_url IS NOT NULL
          AND btrim(ula.source_video_url) <> ''
        GROUP BY ula.location_id, btrim(ula.source_video_url)
    ),
    ranked_urls AS (
        SELECT
            shared_urls.*,
            ROW_NUMBER() OVER (
                PARTITION BY shared_urls.location_id
                ORDER BY shared_urls.share_count DESC,
                         shared_urls.latest_shared_at DESC,
                         shared_urls.source_video_url ASC
            ) AS rn
        FROM shared_urls
    ),
    url_counts AS (
        SELECT
            shared_urls.location_id,
            COUNT(*)::integer AS social_video_count
        FROM shared_urls
        GROUP BY shared_urls.location_id
    ),
    dish_candidates AS (
        SELECT
            vi.location_id,
            NULLIF(btrim(dish.value ->> 'name'), '') AS dish_name,
            ROW_NUMBER() OVER (
                PARTITION BY vi.location_id
                ORDER BY vi.extracted_at DESC, vi.id
            ) AS rn
        FROM public.video_insights vi
        CROSS JOIN LATERAL jsonb_array_elements(
            COALESCE(vi.key_dishes, '[]'::jsonb)
        ) AS dish(value)
        WHERE vi.location_id = ANY(p_location_ids)
          AND NULLIF(btrim(dish.value ->> 'name'), '') IS NOT NULL
    )
    SELECT
        ranked_urls.location_id,
        url_counts.social_video_count,
        ranked_urls.source_video_url AS social_video_url,
        vi.creator_handle AS social_video_creator_handle,
        dish_candidates.dish_name AS tiktok_recommended_dish
    FROM ranked_urls
    INNER JOIN url_counts
        ON url_counts.location_id = ranked_urls.location_id
    LEFT JOIN public.video_insights vi
        ON vi.location_id = ranked_urls.location_id
       AND vi.source_video_url = ranked_urls.source_video_url
    LEFT JOIN dish_candidates
        ON dish_candidates.location_id = ranked_urls.location_id
       AND dish_candidates.rn = 1
    WHERE ranked_urls.rn = 1;
$function$
;

GRANT EXECUTE ON FUNCTION public.get_shared_video_summaries(bigint[])
    TO anon, authenticated, service_role;
