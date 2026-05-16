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

REVOKE ALL ON FUNCTION rewards.accept_pending_referral_for_user(uuid) FROM public;
GRANT EXECUTE ON FUNCTION rewards.accept_pending_referral_for_user(uuid) TO authenticated, service_role;
