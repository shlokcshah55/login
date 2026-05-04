ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS liked boolean NOT NULL DEFAULT false;

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
  location_id bigint,
  liked boolean
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
        m.location_id,
        m.liked
    FROM messages m
    JOIN users u ON m.sender_id = u.supabase_id
    WHERE m.bubble_id = p_bubble_id
    AND m.is_deleted = false
    AND (p_before_timestamp IS NULL OR m.created_at < p_before_timestamp)
    ORDER BY m.created_at DESC
    LIMIT p_limit;
END;
$function$;

DROP FUNCTION IF EXISTS public.set_message_liked(
  uuid,
  boolean
);

CREATE FUNCTION public.set_message_liked(
  p_message_id uuid,
  p_liked boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_bubble_id uuid;
  v_sender_id uuid;
  v_member_count integer;
  v_liked boolean;
BEGIN
  SELECT m.bubble_id, m.sender_id
  INTO v_bubble_id, v_sender_id
  FROM public.messages m
  WHERE m.id = p_message_id
    AND m.is_deleted = false;

  IF v_bubble_id IS NULL THEN
    RAISE EXCEPTION 'Message not found';
  END IF;

  IF v_sender_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot like your own message';
  END IF;

  IF NOT EXISTS (
      SELECT 1 FROM public.bubble_members bm
      WHERE bm.bubble_id = v_bubble_id
        AND bm.user_id = auth.uid()
  ) THEN
      RAISE EXCEPTION 'User not a member of this bubble';
  END IF;

  SELECT COUNT(*)
  INTO v_member_count
  FROM public.bubble_members bm
  WHERE bm.bubble_id = v_bubble_id;

  IF v_member_count <> 2 THEN
    RAISE EXCEPTION 'Message liking is only supported for 1:1 chats';
  END IF;

  UPDATE public.messages
  SET liked = p_liked,
      updated_at = NOW()
  WHERE id = p_message_id
  RETURNING liked INTO v_liked;

  RETURN v_liked;
END;
$function$;
