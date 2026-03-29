CREATE OR REPLACE FUNCTION public.mark_bubble_read(p_bubble_id uuid)
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
    
    -- Update last_read_at
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id) 
    DO UPDATE SET last_read_at = NOW();
END;
$function$
;
