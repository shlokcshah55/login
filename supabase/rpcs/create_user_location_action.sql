CREATE OR REPLACE FUNCTION public.create_user_location_action(p_user_id uuid, p_location_id bigint, p_action text, p_saved_method text DEFAULT NULL::text, p_preference text DEFAULT NULL::text, p_source_video_url text DEFAULT NULL::text, p_acked boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO public.user_location_actions (
    user_id,
    location_id,
    action,
    saved_method,
    preference,
    source_video_url,
    acked,
    created_at
  ) VALUES (
    p_user_id,
    p_location_id,
    p_action::action_type,           -- Cast to Enum
    p_saved_method::saved_method,   -- Cast to Enum
    p_preference::saved_method,     -- Cast to Enum
    p_source_video_url,
    p_acked,
    NOW()
  )
  -- The conflict target must match the UNIQUE constraint exactly
  ON CONFLICT (user_id, location_id, action) 
  DO UPDATE SET
    saved_method = EXCLUDED.saved_method,
    preference = EXCLUDED.preference,
    source_video_url = EXCLUDED.source_video_url,
    acked = EXCLUDED.acked,
    created_at = NOW();
END;
$function$
;
