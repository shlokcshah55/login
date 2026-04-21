-- =============================================================================
-- Add video_extras jsonb column to user_location_actions
-- Stores per-user, per-save data extracted from TikTok/Reel: special offers
-- (with dates, codes), personal notes.
-- Example value:
-- {
--   "special_offers": [
--     {"offer": "20% off if you mention this TikTok", "valid_until": "2026-05-01", "code": "TIKTOK20"}
--   ],
--   "personal_notes": "Need to try the window table"
-- }
-- =============================================================================

ALTER TABLE public.user_location_actions
  ADD COLUMN IF NOT EXISTS video_extras jsonb;
