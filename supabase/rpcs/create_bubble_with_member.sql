CREATE OR REPLACE FUNCTION public.create_bubble_with_member(p_name text, p_created_by uuid, p_is_private boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bubble_id UUID;
BEGIN
  -- Create the bubble
  INSERT INTO public.bubbles (
    name,
    created_by,
    is_private,
    created_at
  ) VALUES (
    p_name,
    p_created_by,
    p_is_private,
    NOW()
  )
  RETURNING bubble_id INTO v_bubble_id;

  -- Add creator as a member
  INSERT INTO public.bubble_members (
    bubble_id,
    user_id,
    added_at
  ) VALUES (
    v_bubble_id,
    p_created_by,
    NOW()
  );

  RETURN v_bubble_id;
END;
$function$
;
