CREATE OR REPLACE FUNCTION public.complete_signup_wizard(
  p_user_id          uuid,
  p_spice_tolerance  integer  DEFAULT NULL::integer,
  p_dietary_tag_ids  uuid[]   DEFAULT NULL::uuid[]
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_user_id      uuid := auth.uid();
  v_request_role      text := coalesce(current_setting('request.jwt.claim.role', true), '');
  v_dietary_affinity real[] := ARRAY[0, 0, 0, 0, 0, 0]::real[];
  v_tag_names        text[];
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  IF v_request_role <> 'service_role'
     AND v_auth_user_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Authenticated user does not match p_user_id';
  END IF;

  IF p_dietary_tag_ids IS NOT NULL AND array_length(p_dietary_tag_ids, 1) > 0 THEN
    SELECT array_agg(
             replace(lower(btrim(t.text)), ' ', '-')
           )
      INTO v_tag_names
      FROM public.tags t
      WHERE t.tag_id = ANY (p_dietary_tag_ids);

    IF v_tag_names IS NOT NULL THEN
      IF 'halal'       = ANY (v_tag_names) THEN v_dietary_affinity[1] := 100; END IF;
      IF 'vegan'       = ANY (v_tag_names) THEN v_dietary_affinity[2] := 100; END IF;
      IF 'gluten-free' = ANY (v_tag_names) THEN v_dietary_affinity[3] := 100; END IF;
      IF 'vegetarian'  = ANY (v_tag_names) THEN v_dietary_affinity[4] := 100; END IF;
      IF 'dairy-free'  = ANY (v_tag_names) THEN v_dietary_affinity[5] := 100; END IF;
      IF 'nut-free'    = ANY (v_tag_names) THEN v_dietary_affinity[6] := 100; END IF;
    END IF;

    RAISE NOTICE 'complete_signup_wizard: user=% tag_ids=% resolved_names=% affinity=%',
      p_user_id, p_dietary_tag_ids, v_tag_names, v_dietary_affinity;
  END IF;

  UPDATE public.users
  SET
    wizard_completed = true,
    spice_tolerance  = COALESCE(p_spice_tolerance, spice_tolerance),
    dietary_requirement_tag_affinity = CASE
      WHEN p_dietary_tag_ids IS NOT NULL
       AND array_length(p_dietary_tag_ids, 1) > 0
        THEN v_dietary_affinity
      ELSE dietary_requirement_tag_affinity
    END
  WHERE supabase_id = p_user_id;

  PERFORM rewards.accept_pending_referral_for_user(p_user_id);
END;
$function$
;

REVOKE ALL ON FUNCTION public.complete_signup_wizard(uuid, integer, uuid[]) FROM public;
REVOKE ALL ON FUNCTION public.complete_signup_wizard(uuid, integer, uuid[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.complete_signup_wizard(uuid, integer, uuid[]) TO authenticated, service_role;
