-- ─────────────────────────────────────────────────────────────
-- 0. Drop old function signature with integer rating
-- ─────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.create_location_review(bigint, text, integer, boolean);


-- ─────────────────────────────────────────────────────────────
-- 1. Extend action_type enum
-- ─────────────────────────────────────────────────────────────
ALTER TYPE public.action_type ADD VALUE IF NOT EXISTS 'been_to';


-- ─────────────────────────────────────────────────────────────
-- 2. Schema changes to location_reviews
-- ─────────────────────────────────────────────────────────────

-- Change rating from integer to numeric(3,1) for 0.1 increments (1.0-10.0)
ALTER TABLE public.location_reviews
  ALTER COLUMN rating TYPE numeric(3,1) USING rating::numeric(3,1);
