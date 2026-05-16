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

REVOKE ALL ON FUNCTION rewards.get_my_referral_dashboard() FROM public;
GRANT EXECUTE ON FUNCTION rewards.get_my_referral_dashboard() TO authenticated, service_role;
