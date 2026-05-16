CREATE OR REPLACE FUNCTION rewards.apply_referral_code(p_code text)
RETURNS rewards.referrals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = rewards, public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_normalized_code text;
  v_referral_code rewards.referral_codes;
  v_referral rewards.referrals;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is null';
  END IF;

  v_normalized_code := upper(
    regexp_replace(
      coalesce(btrim(p_code), ''),
      '[^a-zA-Z0-9]+',
      '',
      'g'
    )
  );

  IF v_normalized_code = '' THEN
    RAISE EXCEPTION 'Referral code is required';
  END IF;

  SELECT *
  INTO v_referral_code
  FROM rewards.referral_codes
  WHERE normalized_code = v_normalized_code
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Referral code is invalid or inactive';
  END IF;

  IF v_referral_code.owner_user_id = v_user_id THEN
    RAISE EXCEPTION 'You cannot apply your own referral code';
  END IF;

  INSERT INTO rewards.referrals (
    referral_code_id,
    inviter_user_id,
    invitee_user_id,
    entered_code
  )
  VALUES (
    v_referral_code.id,
    v_referral_code.owner_user_id,
    v_user_id,
    btrim(p_code)
  )
  ON CONFLICT (invitee_user_id) DO UPDATE
  SET
    referral_code_id = EXCLUDED.referral_code_id,
    inviter_user_id = EXCLUDED.inviter_user_id,
    entered_code = EXCLUDED.entered_code,
    entered_at = now(),
    accepted_at = NULL,
    voided_at = NULL,
    acceptance_trigger = NULL,
    status = 'pending'
  WHERE rewards.referrals.status = 'pending'
  RETURNING *
  INTO v_referral;

  IF NOT FOUND THEN
    SELECT *
    INTO v_referral
    FROM rewards.referrals
    WHERE invitee_user_id = v_user_id;

    IF FOUND AND v_referral.status <> 'pending' THEN
      RAISE EXCEPTION 'Referral is already locked for this user';
    END IF;

    RAISE EXCEPTION 'Referral could not be applied';
  END IF;

  UPDATE public.users
  SET referral_code = v_referral_code.code
  WHERE supabase_id = v_user_id;

  RETURN v_referral;
END;
$function$;

CREATE OR REPLACE FUNCTION rewards.accept_pending_referral_for_user(p_user_id uuid)
RETURNS rewards.referrals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = rewards, public
AS $function$
DECLARE
  v_auth_user_id uuid := auth.uid();
  v_request_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
  v_referral rewards.referrals;
  v_wizard_completed boolean;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  IF v_request_role <> 'service_role'
     AND v_auth_user_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Authenticated user does not match p_user_id';
  END IF;

  SELECT u.wizard_completed
  INTO v_wizard_completed
  FROM public.users u
  WHERE u.supabase_id = p_user_id;

  IF coalesce(v_request_role, '') <> 'service_role'
     AND coalesce(v_wizard_completed, false) = false THEN
    RAISE EXCEPTION 'Signup wizard must be completed before referral acceptance';
  END IF;

  SELECT *
  INTO v_referral
  FROM rewards.referrals
  WHERE invitee_user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_referral.status = 'pending' THEN
    UPDATE rewards.referrals
    SET
      status = 'accepted',
      accepted_at = now(),
      acceptance_trigger = 'wizard_completion'
    WHERE id = v_referral.id
    RETURNING *
    INTO v_referral;
  END IF;

  IF v_referral.status = 'accepted' THEN
    INSERT INTO rewards.vouchers (
      user_id,
      source_referral_id,
      source_type,
      title,
      description,
      merchant_name,
      terms_text,
      metadata
    )
    VALUES (
      v_referral.invitee_user_id,
      v_referral.id,
      'invitee_reward',
      'Imperial Farmers Market 10% Off',
      'Reward for completing signup with a referral code.',
      'Imperial Farmers Market',
      'Valid for 10% off at selected Imperial Farmers Market stores. Single use.',
      jsonb_build_object(
        'reward_role', 'invitee',
        'acceptance_trigger', v_referral.acceptance_trigger
      )
    )
    ON CONFLICT (user_id, campaign_key, source_type)
    WHERE status = 'available'
    DO NOTHING;

    INSERT INTO rewards.vouchers (
      user_id,
      source_referral_id,
      source_type,
      title,
      description,
      merchant_name,
      terms_text,
      metadata
    )
    VALUES (
      v_referral.inviter_user_id,
      v_referral.id,
      'inviter_reward',
      'Imperial Farmers Market 10% Off',
      'Reward for a successful referral signup completion.',
      'Imperial Farmers Market',
      'Valid for 10% off at selected Imperial Farmers Market stores. Single use.',
      jsonb_build_object(
        'reward_role', 'inviter',
        'acceptance_trigger', v_referral.acceptance_trigger
      )
    )
    ON CONFLICT (user_id, campaign_key, source_type)
    WHERE status = 'available'
    DO NOTHING;
  END IF;

  RETURN v_referral;
END;
$function$;

CREATE OR REPLACE FUNCTION rewards.get_my_referral_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = rewards, public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_referral_code rewards.referral_codes;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is null';
  END IF;

  SELECT *
  INTO v_referral_code
  FROM rewards.referral_codes
  WHERE owner_user_id = v_user_id;

  IF v_referral_code.id IS NULL THEN
    v_referral_code := rewards.ensure_referral_code();
  END IF;

  RETURN jsonb_build_object(
    'referral_code',
    v_referral_code.code,
    'accepted_referral_count',
    (
      SELECT count(*)::integer
      FROM rewards.referrals r
      WHERE r.inviter_user_id = v_user_id
        AND r.status = 'accepted'
    ),
    'has_entered_referral_code',
    EXISTS (
      SELECT 1
      FROM rewards.referrals r
      WHERE r.invitee_user_id = v_user_id
    ),
    'available_vouchers',
    coalesce(
      (
        SELECT jsonb_agg(
                 jsonb_build_object(
                   'id', v.id,
                   'source_type', v.source_type,
                   'campaign_key', v.campaign_key,
                   'title', v.title,
                   'description', v.description,
                   'merchant_name', v.merchant_name,
                   'terms_text', v.terms_text,
                   'discount_percent', v.discount_percent,
                   'status', v.status,
                   'issued_at', v.issued_at,
                   'redeemed_at', v.redeemed_at,
                   'expires_at', v.expires_at
                 )
                 ORDER BY v.issued_at DESC, v.id DESC
               )
        FROM rewards.vouchers v
        WHERE v.user_id = v_user_id
          AND v.status = 'available'
      ),
      '[]'::jsonb
    ),
    'used_vouchers',
    coalesce(
      (
        SELECT jsonb_agg(
                 jsonb_build_object(
                   'id', v.id,
                   'source_type', v.source_type,
                   'campaign_key', v.campaign_key,
                   'title', v.title,
                   'description', v.description,
                   'merchant_name', v.merchant_name,
                   'terms_text', v.terms_text,
                   'discount_percent', v.discount_percent,
                   'status', v.status,
                   'issued_at', v.issued_at,
                   'redeemed_at', v.redeemed_at,
                   'expires_at', v.expires_at
                 )
                 ORDER BY v.redeemed_at DESC NULLS LAST, v.issued_at DESC, v.id DESC
               )
        FROM rewards.vouchers v
        WHERE v.user_id = v_user_id
          AND v.status = 'redeemed'
      ),
      '[]'::jsonb
    )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION rewards.redeem_voucher(p_voucher_id uuid)
RETURNS rewards.vouchers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = rewards, public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_voucher rewards.vouchers;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is null';
  END IF;

  SELECT *
  INTO v_voucher
  FROM rewards.vouchers
  WHERE id = p_voucher_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voucher not found';
  END IF;

  IF v_voucher.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Voucher does not belong to the authenticated user';
  END IF;

  IF v_voucher.status <> 'available' THEN
    RAISE EXCEPTION 'Voucher is not available for redemption';
  END IF;

  UPDATE rewards.vouchers
  SET
    status = 'redeemed',
    redeemed_at = now()
  WHERE id = p_voucher_id
  RETURNING *
  INTO v_voucher;

  RETURN v_voucher;
END;
$function$;

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
$function$;

REVOKE ALL ON FUNCTION public.complete_signup_wizard(uuid, integer, uuid[]) FROM public;
REVOKE ALL ON FUNCTION public.complete_signup_wizard(uuid, integer, uuid[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.complete_signup_wizard(uuid, integer, uuid[]) TO authenticated, service_role;

REVOKE ALL ON FUNCTION rewards.apply_referral_code(text) FROM public;
GRANT EXECUTE ON FUNCTION rewards.apply_referral_code(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION rewards.accept_pending_referral_for_user(uuid) FROM public;
GRANT EXECUTE ON FUNCTION rewards.accept_pending_referral_for_user(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION rewards.get_my_referral_dashboard() FROM public;
GRANT EXECUTE ON FUNCTION rewards.get_my_referral_dashboard() TO authenticated, service_role;

REVOKE ALL ON FUNCTION rewards.redeem_voucher(uuid) FROM public;
GRANT EXECUTE ON FUNCTION rewards.redeem_voucher(uuid) TO authenticated, service_role;
