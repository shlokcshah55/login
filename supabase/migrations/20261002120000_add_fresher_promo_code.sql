-- Shared promo codes (e.g. FRESHER) that award a set of vouchers to the person
-- who enters them. Unlike user referral codes they have no owner, so there is no
-- inviter and no inviter reward.

-- 1. Allow ownerless promo codes and inviter-less referrals.
ALTER TABLE rewards.referral_codes ALTER COLUMN owner_user_id DROP NOT NULL;
ALTER TABLE rewards.referrals ALTER COLUMN inviter_user_id DROP NOT NULL;

-- The composite (referral_code_id, inviter_user_id) FK is skipped when
-- inviter_user_id is null, so validate the code id on its own as well.
ALTER TABLE rewards.referrals
  ADD CONSTRAINT referrals_referral_code_id_fkey
  FOREIGN KEY (referral_code_id) REFERENCES rewards.referral_codes (id)
  ON DELETE RESTRICT;

-- 2. Loosen voucher constraints for promo rewards.
ALTER TABLE rewards.vouchers DROP CONSTRAINT vouchers_source_type_check;
ALTER TABLE rewards.vouchers
  ADD CONSTRAINT vouchers_source_type_check
  CHECK (source_type IN ('inviter_reward', 'invitee_reward', 'promo_reward'));

-- 0 means the offer is not a percentage (e.g. "£1 coffee").
ALTER TABLE rewards.vouchers DROP CONSTRAINT vouchers_discount_percent_check;
ALTER TABLE rewards.vouchers
  ADD CONSTRAINT vouchers_discount_percent_check
  CHECK (discount_percent BETWEEN 0 AND 100);

-- One promo referral issues several vouchers of the same source type, so the
-- per-referral uniqueness has to include the campaign.
DROP INDEX rewards.vouchers_source_referral_user_type_unique_idx;
CREATE UNIQUE INDEX vouchers_source_referral_user_type_unique_idx
  ON rewards.vouchers (source_referral_id, user_id, source_type, campaign_key)
  WHERE source_referral_id IS NOT NULL;

-- Optional venue the voucher is for, so the app can open its location card.
ALTER TABLE rewards.vouchers
  ADD COLUMN location_id bigint REFERENCES public.locations (location_id) ON DELETE SET NULL;

-- Reusable vouchers stay available after use; redeemed_at holds the last use.
ALTER TABLE rewards.vouchers
  ADD COLUMN is_single_use boolean NOT NULL DEFAULT true,
  ADD COLUMN redemption_count integer NOT NULL DEFAULT 0;

UPDATE rewards.vouchers SET redemption_count = 1 WHERE status = 'redeemed';

ALTER TABLE rewards.voucher_source_type_rules
  DROP CONSTRAINT voucher_source_type_rules_source_type_check;
ALTER TABLE rewards.voucher_source_type_rules
  ADD CONSTRAINT voucher_source_type_rules_source_type_check
  CHECK (source_type IN ('inviter_reward', 'invitee_reward', 'promo_reward'));

INSERT INTO rewards.voucher_source_type_rules (
  source_type,
  max_applications_per_user_per_campaign
)
VALUES ('promo_reward', 1)
ON CONFLICT (source_type) DO NOTHING;

-- 3. Voucher templates issued when a promo code is accepted.
CREATE TABLE IF NOT EXISTS rewards.promo_code_vouchers (
  id uuid primary key default gen_random_uuid(),
  referral_code_id uuid not null references rewards.referral_codes (id) on delete cascade,
  campaign_key text not null check (btrim(campaign_key) <> ''),
  title text not null check (btrim(title) <> ''),
  description text,
  merchant_name text not null check (btrim(merchant_name) <> ''),
  terms_text text,
  discount_percent integer not null default 0 check (discount_percent between 0 and 100),
  location_id bigint references public.locations (location_id) on delete set null,
  is_single_use boolean not null default true,
  expires_at timestamptz,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (referral_code_id, campaign_key)
);

REVOKE ALL ON rewards.promo_code_vouchers FROM public;
REVOKE ALL ON rewards.promo_code_vouchers FROM anon;
REVOKE ALL ON rewards.promo_code_vouchers FROM authenticated;
GRANT ALL ON rewards.promo_code_vouchers TO service_role;

ALTER TABLE rewards.promo_code_vouchers ENABLE ROW LEVEL SECURITY;

-- 4. Shared voucher issuing, used by both accept functions.
CREATE OR REPLACE FUNCTION rewards.issue_referral_vouchers(p_referral rewards.referrals)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = rewards, public
AS $function$
DECLARE
  v_constraint_name text;
  v_campaign_key text := 'imperial_farmers_market_10pct_selected_stores';
BEGIN
  IF p_referral.status IS DISTINCT FROM 'accepted' THEN
    RETURN;
  END IF;

  -- Promo codes: issue that code's vouchers to the invitee only.
  IF EXISTS (
    SELECT 1
    FROM rewards.promo_code_vouchers t
    WHERE t.referral_code_id = p_referral.referral_code_id
  ) THEN
    INSERT INTO rewards.vouchers (
      user_id,
      source_referral_id,
      source_type,
      campaign_key,
      title,
      description,
      merchant_name,
      terms_text,
      discount_percent,
      location_id,
      is_single_use,
      issued_at,
      expires_at,
      metadata
    )
    SELECT
      p_referral.invitee_user_id,
      p_referral.id,
      'promo_reward',
      t.campaign_key,
      t.title,
      t.description,
      t.merchant_name,
      t.terms_text,
      t.discount_percent,
      t.location_id,
      t.is_single_use,
      -- The dashboard sorts by issued_at desc; offset so vouchers keep sort_order.
      now() - make_interval(secs => t.sort_order),
      t.expires_at,
      jsonb_build_object(
        'reward_role', 'promo',
        'promo_code', p_referral.entered_code,
        'acceptance_trigger', p_referral.acceptance_trigger
      )
    FROM rewards.promo_code_vouchers t
    WHERE t.referral_code_id = p_referral.referral_code_id
      AND t.is_active
      AND (t.expires_at IS NULL OR t.expires_at > now())
      AND NOT EXISTS (
        SELECT 1
        FROM rewards.vouchers existing
        WHERE existing.user_id = p_referral.invitee_user_id
          AND existing.campaign_key = t.campaign_key
          AND existing.status IN ('available', 'redeemed')
      )
    ON CONFLICT DO NOTHING;

    RETURN;
  END IF;

  -- User referral codes: existing Imperial Farmers Market rewards.
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
      p_referral.invitee_user_id,
      p_referral.id,
      'invitee_reward',
      v_campaign_key,
      'Imperial Farmers Market 10% Off',
      'Reward for completing signup with a referral code.',
      'Imperial Farmers Market',
      'Valid for 10% off at selected Imperial Farmers Market stores. Single use.',
      jsonb_build_object(
        'reward_role', 'invitee',
        'acceptance_trigger', p_referral.acceptance_trigger
      )
    WHERE NOT EXISTS (
      SELECT 1
      FROM rewards.vouchers existing
      WHERE existing.user_id = p_referral.invitee_user_id
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

  IF p_referral.inviter_user_id IS NULL THEN
    RETURN;
  END IF;

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
      p_referral.inviter_user_id,
      p_referral.id,
      'inviter_reward',
      v_campaign_key,
      'Imperial Farmers Market 10% Off',
      'Reward for a successful referral signup completion.',
      'Imperial Farmers Market',
      'Valid for 10% off at selected Imperial Farmers Market stores. Single use.',
      jsonb_build_object(
        'reward_role', 'inviter',
        'acceptance_trigger', p_referral.acceptance_trigger
      )
    WHERE NOT EXISTS (
      SELECT 1
      FROM rewards.vouchers existing
      WHERE existing.user_id = p_referral.inviter_user_id
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
END;
$function$;

REVOKE ALL ON FUNCTION rewards.issue_referral_vouchers(rewards.referrals) FROM public;
GRANT EXECUTE ON FUNCTION rewards.issue_referral_vouchers(rewards.referrals) TO service_role;

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

  PERFORM rewards.issue_referral_vouchers(v_referral);

  RETURN v_referral;
END;
$function$;

REVOKE ALL ON FUNCTION rewards.accept_pending_referral_for_user(uuid) FROM public;
GRANT EXECUTE ON FUNCTION rewards.accept_pending_referral_for_user(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION rewards.admin_accept_pending_referral_for_user(
  p_user_id uuid,
  p_acceptance_trigger text DEFAULT 'admin_sql_editor'
)
RETURNS rewards.referrals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, rewards
AS $function$
DECLARE
  v_referral rewards.referrals;
  v_effective_acceptance_trigger text := coalesce(
    nullif(btrim(p_acceptance_trigger), ''),
    'admin_sql_editor'
  );
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
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
      acceptance_trigger = v_effective_acceptance_trigger
    WHERE id = v_referral.id
    RETURNING *
    INTO v_referral;
  END IF;

  PERFORM rewards.issue_referral_vouchers(v_referral);

  RETURN v_referral;
END;
$function$;

REVOKE ALL ON FUNCTION rewards.admin_accept_pending_referral_for_user(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rewards.admin_accept_pending_referral_for_user(uuid, text) TO service_role;

-- 5. Redeeming: single-use vouchers move to redeemed; reusable ones stay
-- available and just count the use.
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

  IF v_voucher.expires_at IS NOT NULL AND v_voucher.expires_at <= now() THEN
    RAISE EXCEPTION 'Voucher has expired';
  END IF;

  IF NOT v_voucher.is_single_use THEN
    UPDATE rewards.vouchers
    SET
      redemption_count = redemption_count + 1,
      redeemed_at = now()
    WHERE id = p_voucher_id
    RETURNING *
    INTO v_voucher;

    RETURN v_voucher;
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
    redemption_count = redemption_count + 1,
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

REVOKE ALL ON FUNCTION rewards.redeem_voucher(uuid) FROM public;
GRANT EXECUTE ON FUNCTION rewards.redeem_voucher(uuid) TO authenticated, service_role;

-- 6. Dashboard: expose location_id, is_single_use and redemption_count.
CREATE OR REPLACE FUNCTION rewards.voucher_to_json(p_voucher rewards.vouchers)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  SELECT jsonb_build_object(
    'id', p_voucher.id,
    'source_type', p_voucher.source_type,
    'campaign_key', p_voucher.campaign_key,
    'title', p_voucher.title,
    'description', p_voucher.description,
    'merchant_name', p_voucher.merchant_name,
    'terms_text', p_voucher.terms_text,
    'discount_percent', p_voucher.discount_percent,
    'location_id', p_voucher.location_id,
    'is_single_use', p_voucher.is_single_use,
    'redemption_count', p_voucher.redemption_count,
    'status', p_voucher.status,
    'issued_at', p_voucher.issued_at,
    'redeemed_at', p_voucher.redeemed_at,
    'expires_at', p_voucher.expires_at
  );
$function$;

REVOKE ALL ON FUNCTION rewards.voucher_to_json(rewards.vouchers) FROM public;
GRANT EXECUTE ON FUNCTION rewards.voucher_to_json(rewards.vouchers) TO service_role;

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
                 rewards.voucher_to_json(v)
                 ORDER BY v.issued_at DESC, v.id DESC
               )
        FROM rewards.vouchers v
        WHERE v.user_id = v_user_id
          AND v.status = 'available'
          AND (v.expires_at IS NULL OR v.expires_at > now())
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
                 rewards.voucher_to_json(v)
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

-- 7. The FRESHER code and its vouchers.
WITH fresher AS (
  INSERT INTO rewards.referral_codes (owner_user_id, code)
  VALUES (NULL, 'FRESHER')
  ON CONFLICT (normalized_code) DO UPDATE SET is_active = true
  RETURNING id
)
INSERT INTO rewards.promo_code_vouchers (
  referral_code_id,
  campaign_key,
  title,
  description,
  merchant_name,
  terms_text,
  discount_percent,
  location_id,
  is_single_use,
  sort_order
)
SELECT
  fresher.id,
  v.campaign_key,
  v.title,
  v.description,
  v.merchant_name,
  v.terms_text,
  v.discount_percent,
  v.location_id,
  v.is_single_use,
  v.sort_order
FROM fresher
CROSS JOIN (
  VALUES
    (
      'fresher_cafe_deco',
      '£1 coffee, £4.50 baguettes & pasta',
      '£1 coffee, and £4.50 baguettes or pasta at Cafe Deco.',
      'Cafe Deco',
      'Show this voucher at Cafe Deco. Can be used every visit.',
      0,
      118559,
      false,
      0
    ),
    (
      'fresher_old_town_97_10pct',
      'Old Town 97 10% Off',
      '10% off your meal at Old Town 97.',
      'Old Town 97',
      'Show this voucher at Old Town 97. Single use.',
      10,
      141789,
      true,
      1
    ),
    (
      'fresher_htacos_10pct',
      'HTacos 10% Off or Free Chips',
      '10% off your meal or free chips at HTacos.',
      'HTacos',
      'Show this voucher at HTacos. Choose 10% off or free chips. Can be used every visit.',
      10,
      146620,
      false,
      2
    ),
    (
      'fresher_mashwi_10pct',
      'Mashwi 10% Off',
      '10% off your meal at Mashwi.',
      'Mashwi',
      'Show this voucher at Mashwi. Can be used every visit.',
      10,
      146619,
      false,
      3
    )
) AS v(campaign_key, title, description, merchant_name, terms_text, discount_percent, location_id, is_single_use, sort_order)
ON CONFLICT (referral_code_id, campaign_key) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  merchant_name = EXCLUDED.merchant_name,
  terms_text = EXCLUDED.terms_text,
  discount_percent = EXCLUDED.discount_percent,
  location_id = EXCLUDED.location_id,
  is_single_use = EXCLUDED.is_single_use,
  sort_order = EXCLUDED.sort_order,
  is_active = true;
