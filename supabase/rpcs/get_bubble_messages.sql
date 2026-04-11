DROP FUNCTION IF EXISTS public.get_bubble_messages(uuid, integer, timestamp with time zone);

CREATE FUNCTION public.get_bubble_messages(p_bubble_id uuid, p_limit integer DEFAULT 50, p_before_timestamp timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(id uuid, sender_id uuid, sender_name text, sender_avatar_url text, content text, message_type text, metadata jsonb, created_at timestamp with time zone, updated_at timestamp with time zone, replied_to_message_id uuid, location_id bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$BEGIN
    -- Verify user is a bubble member
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;
    
    -- Return messages
    RETURN QUERY
    SELECT 
        m.id,
        m.sender_id,
        u.name as sender_name,
        u.profile_image_url as sender_avatar_url,
        m.content,
        m.message_type,
        m.metadata,
        m.created_at,
        m.updated_at,
        m.replied_to_message_id,
        m.location_id
    FROM messages m
    JOIN users u ON m.sender_id = u.supabase_id
    WHERE m.bubble_id = p_bubble_id 
    AND m.is_deleted = false
    AND (p_before_timestamp IS NULL OR m.created_at < p_before_timestamp)
    ORDER BY m.created_at DESC
    LIMIT p_limit;
END;$function$
;
