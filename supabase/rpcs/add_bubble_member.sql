CREATE OR REPLACE FUNCTION public.add_bubble_member(p_bubble_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$BEGIN
  INSERT INTO public.bubble_members (
    bubble_id,
    user_id,
    added_at
  ) VALUES (
    p_bubble_id,
    p_user_id,
    NOW()
  )
  ON CONFLICT DO NOTHING;
END;$function$
;
