CREATE OR REPLACE FUNCTION public.get_bubble_activity(p_bubble_id uuid)
 RETURNS TABLE(action_id bigint, location_id bigint, action text, created_at timestamp without time zone, saved_method text, preference text, user_id uuid, source_video_url text, acked boolean, user_name text, profile_image_url text, location_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NOT EXISTS (
      SELECT 1 FROM bubble_members bm
      WHERE bm.bubble_id = p_bubble_id 
      AND bm.user_id = auth.uid()
  ) THEN
      RAISE EXCEPTION 'User not a member of this bubble';
  END IF;

  RETURN QUERY
  SELECT 
    ula.action_id,
    ula.location_id,
    ula.action::text,
    ula.created_at,
    ula.saved_method::text,
    ula.preference::text,
    ula.user_id,
    ula.source_video_url,
    ula.acked,
    u.name,
    u.profile_image_url,
    l.name
  FROM user_location_actions ula
  INNER JOIN bubble_members bm ON bm.user_id = ula.user_id
  INNER JOIN users u ON u.supabase_id = ula.user_id
  INNER JOIN locations l ON l.location_id = ula.location_id
  WHERE bm.bubble_id = p_bubble_id
  ORDER BY ula.created_at DESC
  LIMIT 10;
END;
$function$
;
