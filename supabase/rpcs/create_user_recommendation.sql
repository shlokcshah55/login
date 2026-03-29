CREATE OR REPLACE FUNCTION public.create_user_recommendation(p_user_id uuid, p_location_id bigint, p_score real, p_reason jsonb DEFAULT NULL::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.user_recommendations (
    user_id,
    location_id,
    score,
    reason,
    generated_at
  ) VALUES (
    p_user_id,
    p_location_id,
    p_score,
    p_reason,
    NOW()
  )
  ON CONFLICT (user_id, location_id) DO UPDATE SET
    score = EXCLUDED.score,
    reason = EXCLUDED.reason,
    generated_at = EXCLUDED.generated_at;
END;
$function$
;
