CREATE OR REPLACE FUNCTION public.get_user_tag_scores(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(jsonb_build_object(
            'tag_id', tag_id,
            'affinity', affinity
        )),
        '[]'::jsonb
    ) INTO v_result
    FROM user_tag_affinities
    WHERE user_id = p_user_id;

    RETURN v_result;
END;
$function$
;
