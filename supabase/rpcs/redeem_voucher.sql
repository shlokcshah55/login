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

  PERFORM 1
  FROM rewards.vouchers locked
  WHERE locked.user_id = v_user_id
    AND locked.campaign_key = v_voucher.campaign_key
  FOR UPDATE;

  IF (
    SELECT count(*)
    FROM rewards.vouchers redeemed
    WHERE redeemed.user_id = v_user_id
      AND redeemed.campaign_key = v_voucher.campaign_key
      AND redeemed.status = 'redeemed'
  ) > 0 THEN
    RAISE EXCEPTION 'Voucher redemption limit reached for this campaign';
  END IF;

  UPDATE rewards.vouchers
  SET
    status = 'redeemed',
    redeemed_at = now()
  WHERE id = p_voucher_id
  RETURNING *
  INTO v_voucher;

  IF (
    SELECT count(*)
    FROM rewards.vouchers redeemed
    WHERE redeemed.user_id = v_user_id
      AND redeemed.campaign_key = v_voucher.campaign_key
      AND redeemed.status = 'redeemed'
  ) > 0 THEN
    UPDATE rewards.vouchers
    SET status = 'voided'
    WHERE user_id = v_user_id
      AND campaign_key = v_voucher.campaign_key
      AND status = 'available'
      AND id <> v_voucher.id;
  END IF;

  RETURN v_voucher;
END;
$function$;

REVOKE ALL ON FUNCTION rewards.redeem_voucher(uuid) FROM public;
GRANT EXECUTE ON FUNCTION rewards.redeem_voucher(uuid) TO authenticated, service_role;
