-- Persist the useful post context that the processor already extracts so the
-- Flutter review flow can identify the original share without storing media.
ALTER TABLE public.social_posts
    ADD COLUMN IF NOT EXISTS caption text,
    ADD COLUMN IF NOT EXISTS thumbnail_url text;

-- Processor auto-saves and explicit user decisions were previously both
-- represented as action='saved'. Keep the action contract and record whether
-- the user actually confirmed it.
ALTER TABLE public.social_post_place_reviews
    ADD COLUMN IF NOT EXISTS confirmed_by_user boolean NOT NULL DEFAULT false;

UPDATE public.social_post_place_reviews
SET confirmed_by_user = true
WHERE action IN ('corrected', 'manual_added', 'discarded');

-- UPDATE policies need WITH CHECK as well as USING so an authenticated user
-- cannot reassign an owned row while updating it.
DROP POLICY IF EXISTS "Users can update their own post reviews"
    ON public.social_post_reviews;

CREATE POLICY "Users can update their own post reviews"
    ON public.social_post_reviews
    FOR UPDATE
    TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own place reviews"
    ON public.social_post_place_reviews;

CREATE POLICY "Users can update their own place reviews"
    ON public.social_post_place_reviews
    FOR UPDATE
    TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);
