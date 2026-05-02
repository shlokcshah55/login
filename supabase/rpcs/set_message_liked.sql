DROP FUNCTION IF EXISTS public.set_message_liked(uuid, boolean);

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
