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

REVOKE ALL ON FUNCTION rewards.apply_referral_code(text) FROM public;
GRANT EXECUTE ON FUNCTION rewards.apply_referral_code(text) TO authenticated, service_role;
