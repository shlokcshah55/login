CREATE TABLE IF NOT EXISTS rewards.voucher_source_type_rules (
  source_type text primary key check (source_type in ('inviter_reward', 'invitee_reward')),
  max_applications_per_user_per_campaign integer not null check (max_applications_per_user_per_campaign > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

DROP TRIGGER IF EXISTS voucher_source_type_rules_set_updated_at
ON rewards.voucher_source_type_rules;

CREATE TRIGGER voucher_source_type_rules_set_updated_at
BEFORE UPDATE ON rewards.voucher_source_type_rules
FOR EACH ROW
EXECUTE FUNCTION rewards.set_updated_at();

INSERT INTO rewards.voucher_source_type_rules (
  source_type,
  max_applications_per_user_per_campaign
)
VALUES
  ('invitee_reward', 1),
  ('inviter_reward', 1)
ON CONFLICT (source_type) DO UPDATE
SET max_applications_per_user_per_campaign =
  EXCLUDED.max_applications_per_user_per_campaign;

REVOKE ALL ON rewards.voucher_source_type_rules FROM public;
REVOKE ALL ON rewards.voucher_source_type_rules FROM anon;
REVOKE ALL ON rewards.voucher_source_type_rules FROM authenticated;
GRANT ALL ON rewards.voucher_source_type_rules TO service_role;

ALTER TABLE rewards.voucher_source_type_rules ENABLE ROW LEVEL SECURITY;

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
  v_constraint_name text;
  v_campaign_key text := 'imperial_farmers_market_10pct_selected_stores';
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
    BEGIN
      INSERT INTO rewards.vouchers (
        user_id,
        source_referral_id,
        source_type,
        campaign_key,
        title,
        description,
        merchant_name,
        terms_text,
        metadata
      )
      SELECT
        v_referral.invitee_user_id,
        v_referral.id,
        'invitee_reward',
        v_campaign_key,
        'Imperial Farmers Market 10% Off',
        'Reward for completing signup with a referral code.',
        'Imperial Farmers Market',
        'Valid for 10% off at selected Imperial Farmers Market stores. Single use.',
        jsonb_build_object(
          'reward_role', 'invitee',
          'acceptance_trigger', v_referral.acceptance_trigger
        )
      WHERE NOT EXISTS (
        SELECT 1
        FROM rewards.vouchers existing
        WHERE existing.user_id = v_referral.invitee_user_id
          AND existing.campaign_key = v_campaign_key
          AND existing.source_type = 'invitee_reward'
          AND existing.status IN ('available', 'redeemed')
        GROUP BY existing.user_id, existing.campaign_key, existing.source_type
        HAVING count(*) >= coalesce(
          (
            SELECT r.max_applications_per_user_per_campaign
            FROM rewards.voucher_source_type_rules r
            WHERE r.source_type = 'invitee_reward'
          ),
          2147483647
        )
      )
      ON CONFLICT (user_id, campaign_key, source_type)
      WHERE status = 'available'
      DO NOTHING;
    EXCEPTION WHEN unique_violation THEN
      GET STACKED DIAGNOSTICS v_constraint_name = CONSTRAINT_NAME;

      IF v_constraint_name NOT IN (
        'vouchers_user_campaign_type_available_unique_idx',
        'vouchers_source_referral_user_type_unique_idx'
      ) THEN
        RAISE;
      END IF;
    END;

    BEGIN
      INSERT INTO rewards.vouchers (
        user_id,
        source_referral_id,
        source_type,
        campaign_key,
        title,
        description,
        merchant_name,
        terms_text,
        metadata
      )
      SELECT
        v_referral.inviter_user_id,
        v_referral.id,
        'inviter_reward',
        v_campaign_key,
        'Imperial Farmers Market 10% Off',
        'Reward for a successful referral signup completion.',
        'Imperial Farmers Market',
        'Valid for 10% off at selected Imperial Farmers Market stores. Single use.',
        jsonb_build_object(
          'reward_role', 'inviter',
          'acceptance_trigger', v_referral.acceptance_trigger
        )
      WHERE NOT EXISTS (
        SELECT 1
        FROM rewards.vouchers existing
        WHERE existing.user_id = v_referral.inviter_user_id
          AND existing.campaign_key = v_campaign_key
          AND existing.source_type = 'inviter_reward'
          AND existing.status IN ('available', 'redeemed')
        GROUP BY existing.user_id, existing.campaign_key, existing.source_type
        HAVING count(*) >= coalesce(
          (
            SELECT r.max_applications_per_user_per_campaign
            FROM rewards.voucher_source_type_rules r
            WHERE r.source_type = 'inviter_reward'
          ),
          2147483647
        )
      )
      ON CONFLICT (user_id, campaign_key, source_type)
      WHERE status = 'available'
      DO NOTHING;
    EXCEPTION WHEN unique_violation THEN
      GET STACKED DIAGNOSTICS v_constraint_name = CONSTRAINT_NAME;

      IF v_constraint_name NOT IN (
        'vouchers_user_campaign_type_available_unique_idx',
        'vouchers_source_referral_user_type_unique_idx'
      ) THEN
        RAISE;
      END IF;
    END;
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
          AND (
            SELECT count(*)
            FROM rewards.vouchers redeemed
            WHERE redeemed.user_id = v.user_id
              AND redeemed.campaign_key = v.campaign_key
              AND redeemed.source_type = v.source_type
              AND redeemed.status = 'redeemed'
          ) < coalesce(
            (
              SELECT r.max_applications_per_user_per_campaign
              FROM rewards.voucher_source_type_rules r
              WHERE r.source_type = v.source_type
            ),
            2147483647
          )
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
  v_application_limit integer;
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

  SELECT r.max_applications_per_user_per_campaign
  INTO v_application_limit
  FROM rewards.voucher_source_type_rules r
  WHERE r.source_type = v_voucher.source_type;

  v_application_limit := coalesce(v_application_limit, 2147483647);

  PERFORM 1
  FROM rewards.vouchers locked
  WHERE locked.user_id = v_user_id
    AND locked.campaign_key = v_voucher.campaign_key
    AND locked.source_type = v_voucher.source_type
  FOR UPDATE;

  IF (
    SELECT count(*)
    FROM rewards.vouchers redeemed
    WHERE redeemed.user_id = v_user_id
      AND redeemed.campaign_key = v_voucher.campaign_key
      AND redeemed.source_type = v_voucher.source_type
      AND redeemed.status = 'redeemed'
  ) >= v_application_limit THEN
    RAISE EXCEPTION 'Voucher redemption limit reached for this reward type';
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
      AND redeemed.source_type = v_voucher.source_type
      AND redeemed.status = 'redeemed'
  ) >= v_application_limit THEN
    UPDATE rewards.vouchers
    SET status = 'voided'
    WHERE user_id = v_user_id
      AND campaign_key = v_voucher.campaign_key
      AND source_type = v_voucher.source_type
      AND status = 'available'
      AND id <> v_voucher.id;
  END IF;

  RETURN v_voucher;
END;
$function$;

REVOKE ALL ON FUNCTION rewards.accept_pending_referral_for_user(uuid) FROM public;
GRANT EXECUTE ON FUNCTION rewards.accept_pending_referral_for_user(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION rewards.get_my_referral_dashboard() FROM public;
GRANT EXECUTE ON FUNCTION rewards.get_my_referral_dashboard() TO authenticated, service_role;

REVOKE ALL ON FUNCTION rewards.redeem_voucher(uuid) FROM public;
GRANT EXECUTE ON FUNCTION rewards.redeem_voucher(uuid) TO authenticated, service_role;
