ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS location_id bigint NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'messages_location_id_fkey'
  ) THEN
    ALTER TABLE public.messages
    ADD CONSTRAINT messages_location_id_fkey
    FOREIGN KEY (location_id)
    REFERENCES public.locations(location_id)
    ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_messages_location_id
ON public.messages (location_id)
WHERE location_id IS NOT NULL;

DROP FUNCTION IF EXISTS public.send_message(
  uuid,
  text,
  text,
  jsonb,
  uuid
);

DROP FUNCTION IF EXISTS public.send_message(
  uuid,
  text,
  text,
  jsonb,
  uuid,
  bigint
);

CREATE FUNCTION public.send_message(
  p_bubble_id uuid,
  p_content text,
  p_message_type text DEFAULT 'text'::text,
  p_metadata jsonb DEFAULT NULL::jsonb,
  p_replied_to uuid DEFAULT NULL::uuid,
  p_location_id bigint DEFAULT NULL::bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_message_id UUID;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;

    INSERT INTO messages (
        bubble_id,
        sender_id,
        content,
        message_type,
        metadata,
        replied_to_message_id,
        location_id
    )
    VALUES (
        p_bubble_id,
        auth.uid(),
        p_content,
        p_message_type,
        p_metadata,
        p_replied_to,
        p_location_id
    )
    RETURNING id INTO v_message_id;

    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id)
    DO UPDATE SET last_read_at = NOW();

    RETURN v_message_id;
END;
$function$;

DROP FUNCTION IF EXISTS public.get_bubble_messages(
  uuid,
  integer,
  timestamp with time zone
);

CREATE FUNCTION public.get_bubble_messages(
  p_bubble_id uuid,
  p_limit integer DEFAULT 50,
  p_before_timestamp timestamp with time zone DEFAULT NULL::timestamp with time zone
)
RETURNS TABLE(
  id uuid,
  sender_id uuid,
  sender_name text,
  sender_avatar_url text,
  content text,
  message_type text,
  metadata jsonb,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  replied_to_message_id uuid,
  location_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;

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
END;
$function$;
