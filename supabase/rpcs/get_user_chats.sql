CREATE OR REPLACE FUNCTION public.get_user_chats()
 RETURNS TABLE(bubble_id uuid, bubble_name text, last_message_at timestamp with time zone, unread_count bigint, last_message jsonb, muted boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        ubc.bubble_id,
        ubc.bubble_name,
        ubc.last_message_at,
        ubc.unread_count,
        ubc.last_message,
        ubc.muted
    FROM user_bubble_chats ubc
    WHERE ubc.user_id = auth.uid()
    ORDER BY ubc.last_message_at DESC NULLS LAST;
END;
$function$
;
