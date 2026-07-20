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

-- Keep the ownership policies explicit and evaluate auth.uid() once per
-- statement. UPDATE policies need WITH CHECK as well as USING so an
-- authenticated user cannot reassign an owned row while updating it.
DROP POLICY IF EXISTS "Users can read posts they shared"
    ON public.social_posts;

CREATE POLICY "Users can read posts they shared"
    ON public.social_posts
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.social_post_reviews AS review
            WHERE review.social_post_id = social_posts.id
              AND review.user_id = (SELECT auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can read places for posts they shared"
    ON public.social_post_places;

CREATE POLICY "Users can read places for posts they shared"
    ON public.social_post_places
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.social_post_reviews AS review
            WHERE review.social_post_id = social_post_places.social_post_id
              AND review.user_id = (SELECT auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can add places to posts they shared"
    ON public.social_post_places;

CREATE POLICY "Users can add places to posts they shared"
    ON public.social_post_places
    FOR INSERT
    TO authenticated
    WITH CHECK (
        added_by = (SELECT auth.uid())
        AND EXISTS (
            SELECT 1
            FROM public.social_post_reviews AS review
            WHERE review.social_post_id = social_post_places.social_post_id
              AND review.user_id = (SELECT auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can read their own post reviews"
    ON public.social_post_reviews;

CREATE POLICY "Users can read their own post reviews"
    ON public.social_post_reviews
    FOR SELECT
    TO authenticated
    USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own post reviews"
    ON public.social_post_reviews;

CREATE POLICY "Users can update their own post reviews"
    ON public.social_post_reviews
    FOR UPDATE
    TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can read their own place reviews"
    ON public.social_post_place_reviews;

CREATE POLICY "Users can read their own place reviews"
    ON public.social_post_place_reviews
    FOR SELECT
    TO authenticated
    USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own place reviews"
    ON public.social_post_place_reviews;

CREATE POLICY "Users can insert their own place reviews"
    ON public.social_post_place_reviews
    FOR INSERT
    TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own place reviews"
    ON public.social_post_place_reviews;

CREATE POLICY "Users can update their own place reviews"
    ON public.social_post_place_reviews
    FOR UPDATE
    TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- Cover the foreign-key lookups used by the nested inbox query and review
-- writes. The existing user-first unique indexes do not cover reverse lookups
-- by post/place/location id.
CREATE INDEX IF NOT EXISTS social_post_reviews_post_idx
    ON public.social_post_reviews (social_post_id);

CREATE INDEX IF NOT EXISTS social_post_places_added_by_idx
    ON public.social_post_places (added_by)
    WHERE added_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS social_post_places_location_idx
    ON public.social_post_places (location_id)
    WHERE location_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS social_post_place_reviews_place_idx
    ON public.social_post_place_reviews (social_post_place_id);

CREATE INDEX IF NOT EXISTS social_post_place_reviews_location_idx
    ON public.social_post_place_reviews (location_id)
    WHERE location_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS social_post_place_reviews_corrected_location_idx
    ON public.social_post_place_reviews (corrected_location_id)
    WHERE corrected_location_id IS NOT NULL;
