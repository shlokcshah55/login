REVOKE ALL ON FUNCTION rewards.ensure_referral_code() FROM public;
REVOKE ALL ON FUNCTION rewards.ensure_referral_code() FROM authenticated;
GRANT EXECUTE ON FUNCTION rewards.ensure_referral_code() TO service_role;
