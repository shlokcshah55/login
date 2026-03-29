CREATE OR REPLACE FUNCTION public.notify_new_message()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Notify via pg_notify for real-time subscriptions
    PERFORM pg_notify(
        'new_message',
        json_build_object(
            'bubble_id', NEW.bubble_id,
            'message_id', NEW.id,
            'sender_id', NEW.sender_id,
            'message_type', NEW.message_type,
            'content', NEW.content
        )::text
    );
    
    RETURN NEW;
END;
$function$
;
