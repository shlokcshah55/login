UPDATE rewards.vouchers available
SET status = 'voided'
WHERE available.status = 'available'
  AND EXISTS (
    SELECT 1
    FROM rewards.vouchers redeemed
    WHERE redeemed.user_id = available.user_id
      AND redeemed.campaign_key = available.campaign_key
      AND redeemed.status = 'redeemed'
  );

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
          AND (
            SELECT count(*)
            FROM rewards.vouchers redeemed
            WHERE redeemed.user_id = v.user_id
              AND redeemed.campaign_key = v.campaign_key
              AND redeemed.status = 'redeemed'
          ) = 0
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

  UPDATE rewards.vouchers
  SET status = 'voided'
  WHERE user_id = v_user_id
    AND campaign_key = v_voucher.campaign_key
    AND status = 'available'
    AND id <> v_voucher.id;

  RETURN v_voucher;
END;
$function$;

REVOKE ALL ON FUNCTION rewards.get_my_referral_dashboard() FROM public;
GRANT EXECUTE ON FUNCTION rewards.get_my_referral_dashboard() TO authenticated, service_role;

REVOKE ALL ON FUNCTION rewards.redeem_voucher(uuid) FROM public;
GRANT EXECUTE ON FUNCTION rewards.redeem_voucher(uuid) TO authenticated, service_role;
