CREATE OR REPLACE FUNCTION public.initialize_chat_state_for_new_member()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Initialize chat state for new member
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (NEW.user_id, NEW.bubble_id, NOW())
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$function$
;
