CREATE OR REPLACE FUNCTION public.send_message(p_bubble_id uuid, p_content text, p_message_type text DEFAULT 'text'::text, p_metadata jsonb DEFAULT NULL::jsonb, p_replied_to uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_message_id UUID;
BEGIN
    -- Verify user is a bubble member
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;
    
    -- Insert message
    INSERT INTO messages (
        bubble_id, 
        sender_id, 
        content, 
        message_type, 
        metadata,
        replied_to_message_id
    )
    VALUES (
        p_bubble_id, 
        auth.uid(), 
        p_content, 
        p_message_type, 
        p_metadata,
        p_replied_to
    )
    RETURNING id INTO v_message_id;
    
    -- Update sender's last_read_at (they've seen their own message)
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id) 
    DO UPDATE SET last_read_at = NOW();
    
    RETURN v_message_id;
END;
$function$
;
