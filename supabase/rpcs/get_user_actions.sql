CREATE OR REPLACE FUNCTION public.get_user_actions(p_user_id uuid, p_limit integer DEFAULT 50)
 RETURNS TABLE(location_id bigint, action_type text, created_at timestamp without time zone, name text, bubble_name text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY

    -- Actions from user_location_actions
    SELECT
        l.location_id,
        ula.action::text,
        ula.created_at,
        l.name,
        ''
    FROM user_location_actions ula
    INNER JOIN locations l ON l.location_id = ula.location_id
    WHERE ula.user_id = p_user_id

    UNION ALL

    -- Bubble saves from bubble_locations
    SELECT
        l.location_id,
        'bubble_save',
        bl.added_at,
        l.name,
        b.name
    FROM bubble_locations bl
    INNER JOIN locations l ON l.location_id = bl.location_id
    INNER JOIN bubbles b ON b.bubble_id = bl.bubble_id
    WHERE b.created_by = p_user_id  -- adjust if bubble membership is used instead

    ORDER BY created_at DESC
    LIMIT p_limit;
END;
$function$
;
