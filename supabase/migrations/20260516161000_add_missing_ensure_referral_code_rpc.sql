CREATE OR REPLACE FUNCTION rewards.ensure_referral_code()
RETURNS rewards.referral_codes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = rewards, public
AS $function$
DECLARE
  v_owner_user_id uuid := auth.uid();
  v_referral_code rewards.referral_codes;
BEGIN
  IF v_owner_user_id IS NULL THEN
    RAISE EXCEPTION 'auth.uid() is null';
  END IF;

  SELECT *
  INTO v_referral_code
  FROM rewards.referral_codes
  WHERE owner_user_id = v_owner_user_id;

  IF FOUND THEN
    RETURN v_referral_code;
  END IF;

  INSERT INTO rewards.referral_codes (
    owner_user_id,
    code
  )
  VALUES (
    v_owner_user_id,
    rewards.generate_referral_code(v_owner_user_id)
  )
  ON CONFLICT (owner_user_id) DO UPDATE
  SET code = rewards.referral_codes.code
  RETURNING *
  INTO v_referral_code;

  RETURN v_referral_code;
END;
$function$;

REVOKE ALL ON FUNCTION rewards.ensure_referral_code() FROM public;
REVOKE ALL ON FUNCTION rewards.ensure_referral_code() FROM authenticated;
GRANT EXECUTE ON FUNCTION rewards.ensure_referral_code() TO service_role;
