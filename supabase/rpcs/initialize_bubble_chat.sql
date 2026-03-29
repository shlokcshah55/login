CREATE OR REPLACE FUNCTION public.initialize_bubble_chat(p_bubble_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Verify user is a bubble member
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;
    
    -- Create chat state if doesn't exist
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id) DO NOTHING;
END;
$function$
;
