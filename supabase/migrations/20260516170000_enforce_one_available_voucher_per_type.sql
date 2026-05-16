-- Prevent a user accumulating multiple available vouchers of the same type
-- within the same campaign (e.g. by referring several people before redeeming).
-- The partial index only covers status = 'available', so a redeemed voucher
-- vacates the slot and lets a future referral award a new one.
CREATE UNIQUE INDEX vouchers_user_campaign_type_available_unique_idx
  ON rewards.vouchers (user_id, campaign_key, source_type)
  WHERE status = 'available';
