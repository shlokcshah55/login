-- Social post review model
--
-- Makes a shared TikTok/Reel a first-class source object with its own review
-- surface, replacing the per-(user, url) pending_social_saves model:
--
--   social_posts              one global row per canonical URL: metadata,
--                             post-level vibes, processing status
--   social_post_places        global place candidates extracted from a post
--                             (zero, one, or many per post; reused across users)
--   social_post_reviews       per-user review state for a post
--   social_post_place_reviews per-user action on each place candidate
--                             (save / discard / correct / manual add)
--
-- Corrections are stored as per-user feedback on the review row — the global
-- candidate mapping is never mutated by a single user's correction.
-- Actual saves still go through save_location_with_tags → user_location_actions,
-- so saved places keep working with the rest of the app.

-- ── social_posts ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.social_posts (
    id              uuid        NOT NULL DEFAULT gen_random_uuid(),
    canonical_url   text        NOT NULL,
    platform        text        NOT NULL,
    creator_handle  text,
    title           text,
    status          text        NOT NULL DEFAULT 'processing',
    -- Post-level vibe signals, e.g. {"date_night": 0.8, "cheap_eats": 0.6}
    vibes           jsonb       NOT NULL DEFAULT '{}'::jsonb,
    sentiment       text,
    -- Which extraction methods produced signal:
    -- {caption, thumbnail_ocr, frame_ocr, slideshow_ocr, subtitles}
    evidence_flags  jsonb       NOT NULL DEFAULT '{}'::jsonb,
    error           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    processed_at    timestamptz,

    CONSTRAINT social_posts_pkey PRIMARY KEY (id),
    CONSTRAINT social_posts_canonical_url_key UNIQUE (canonical_url),
    CONSTRAINT social_posts_platform_check
        CHECK (platform IN ('tiktok', 'instagram')),
    CONSTRAINT social_posts_status_check
        CHECK (status IN ('processing', 'processed', 'failed'))
);

-- ── social_post_places ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.social_post_places (
    id               uuid        NOT NULL DEFAULT gen_random_uuid(),
    social_post_id   uuid        NOT NULL,
    location_id      bigint,
    google_place_id  text,
    name             text        NOT NULL,
    address          text,
    candidate_name   text,
    candidate_area   text,
    confidence_score real,
    confidence_tier  text,
    -- Extracted per-place context shown in the review UI:
    -- {key_dishes, special_offers, creator_notes, vibe_signals, sentiment,
    --  source, reasoning}
    extracted_context jsonb      NOT NULL DEFAULT '{}'::jsonb,
    -- NULL for pipeline-extracted candidates; set to the user who manually
    -- added the place on a failed / low-confidence post.
    added_by         uuid,
    created_at       timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT social_post_places_pkey PRIMARY KEY (id),
    CONSTRAINT social_post_places_post_fkey
        FOREIGN KEY (social_post_id)
        REFERENCES public.social_posts (id) ON DELETE CASCADE,
    CONSTRAINT social_post_places_location_fkey
        FOREIGN KEY (location_id)
        REFERENCES public.locations (location_id) ON DELETE SET NULL,
    CONSTRAINT social_post_places_added_by_fkey
        FOREIGN KEY (added_by)
        REFERENCES public.users (supabase_id) ON DELETE SET NULL,
    CONSTRAINT social_post_places_tier_check
        CHECK (confidence_tier IS NULL OR confidence_tier IN ('high', 'medium', 'low'))
);

-- One candidate per resolved Google place per post
CREATE UNIQUE INDEX IF NOT EXISTS social_post_places_post_place_key
    ON public.social_post_places (social_post_id, google_place_id)
    WHERE google_place_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS social_post_places_post_idx
    ON public.social_post_places (social_post_id);

-- ── social_post_reviews ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.social_post_reviews (
    id              uuid        NOT NULL DEFAULT gen_random_uuid(),
    user_id         uuid        NOT NULL,
    social_post_id  uuid        NOT NULL,
    -- The exact URL this user shared (pre-canonicalisation), for attribution.
    shared_url      text        NOT NULL,
    status          text        NOT NULL DEFAULT 'pending',
    snoozed_at      timestamptz,
    reviewed_at     timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT social_post_reviews_pkey PRIMARY KEY (id),
    CONSTRAINT social_post_reviews_user_post_key UNIQUE (user_id, social_post_id),
    CONSTRAINT social_post_reviews_user_fkey
        FOREIGN KEY (user_id)
        REFERENCES public.users (supabase_id) ON DELETE CASCADE,
    CONSTRAINT social_post_reviews_post_fkey
        FOREIGN KEY (social_post_id)
        REFERENCES public.social_posts (id) ON DELETE CASCADE,
    CONSTRAINT social_post_reviews_status_check
        CHECK (status IN ('pending', 'later', 'reviewed', 'dismissed'))
);

CREATE INDEX IF NOT EXISTS social_post_reviews_user_status_idx
    ON public.social_post_reviews (user_id, status);

-- ── social_post_place_reviews ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.social_post_place_reviews (
    id                       uuid        NOT NULL DEFAULT gen_random_uuid(),
    user_id                  uuid        NOT NULL,
    social_post_place_id     uuid        NOT NULL,
    action                   text        NOT NULL,
    -- Set when the user corrected the matched place; the global candidate row
    -- is left untouched and this acts as feedback for future re-matching.
    corrected_google_place_id text,
    corrected_location_id    bigint,
    -- The location actually saved to the user's Eat List (post-correction).
    location_id              bigint,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT social_post_place_reviews_pkey PRIMARY KEY (id),
    CONSTRAINT social_post_place_reviews_user_place_key
        UNIQUE (user_id, social_post_place_id),
    CONSTRAINT social_post_place_reviews_user_fkey
        FOREIGN KEY (user_id)
        REFERENCES public.users (supabase_id) ON DELETE CASCADE,
    CONSTRAINT social_post_place_reviews_place_fkey
        FOREIGN KEY (social_post_place_id)
        REFERENCES public.social_post_places (id) ON DELETE CASCADE,
    CONSTRAINT social_post_place_reviews_location_fkey
        FOREIGN KEY (location_id)
        REFERENCES public.locations (location_id) ON DELETE SET NULL,
    CONSTRAINT social_post_place_reviews_corrected_location_fkey
        FOREIGN KEY (corrected_location_id)
        REFERENCES public.locations (location_id) ON DELETE SET NULL,
    CONSTRAINT social_post_place_reviews_action_check
        CHECK (action IN ('saved', 'discarded', 'corrected', 'manual_added'))
);

CREATE INDEX IF NOT EXISTS social_post_place_reviews_user_idx
    ON public.social_post_place_reviews (user_id);

-- ── updated_at triggers ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.touch_social_review_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER social_posts_updated_at_trigger
    BEFORE UPDATE ON public.social_posts
    FOR EACH ROW EXECUTE FUNCTION public.touch_social_review_updated_at();

CREATE TRIGGER social_post_reviews_updated_at_trigger
    BEFORE UPDATE ON public.social_post_reviews
    FOR EACH ROW EXECUTE FUNCTION public.touch_social_review_updated_at();

CREATE TRIGGER social_post_place_reviews_updated_at_trigger
    BEFORE UPDATE ON public.social_post_place_reviews
    FOR EACH ROW EXECUTE FUNCTION public.touch_social_review_updated_at();

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE public.social_posts              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_post_places        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_post_reviews       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_post_place_reviews ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.social_posts              FROM anon, authenticated;
REVOKE ALL ON TABLE public.social_post_places        FROM anon, authenticated;
REVOKE ALL ON TABLE public.social_post_reviews       FROM anon, authenticated;
REVOKE ALL ON TABLE public.social_post_place_reviews FROM anon, authenticated;

GRANT ALL ON TABLE public.social_posts              TO service_role;
GRANT ALL ON TABLE public.social_post_places        TO service_role;
GRANT ALL ON TABLE public.social_post_reviews       TO service_role;
GRANT ALL ON TABLE public.social_post_place_reviews TO service_role;

GRANT SELECT                 ON TABLE public.social_posts              TO authenticated;
GRANT SELECT, INSERT         ON TABLE public.social_post_places        TO authenticated;
GRANT SELECT, UPDATE         ON TABLE public.social_post_reviews       TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.social_post_place_reviews TO authenticated;

-- Users can only see posts (and their candidates) they have a review for.
CREATE POLICY "Users can read posts they shared"
    ON public.social_posts FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.social_post_reviews r
        WHERE r.social_post_id = social_posts.id AND r.user_id = auth.uid()
    ));

CREATE POLICY "Users can read places for posts they shared"
    ON public.social_post_places FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.social_post_reviews r
        WHERE r.social_post_id = social_post_places.social_post_id
          AND r.user_id = auth.uid()
    ));

-- Manual place additions (failed / low-confidence posts) come from the app.
CREATE POLICY "Users can add places to posts they shared"
    ON public.social_post_places FOR INSERT TO authenticated
    WITH CHECK (
        added_by = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.social_post_reviews r
            WHERE r.social_post_id = social_post_places.social_post_id
              AND r.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can read their own post reviews"
    ON public.social_post_reviews FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own post reviews"
    ON public.social_post_reviews FOR UPDATE TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can read their own place reviews"
    ON public.social_post_place_reviews FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own place reviews"
    ON public.social_post_place_reviews FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own place reviews"
    ON public.social_post_place_reviews FOR UPDATE TO authenticated
    USING (auth.uid() = user_id);

-- Realtime: the app subscribes to its own review rows; the processor touches
-- them when processing finishes so one subscription covers post status too.
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.social_post_reviews;

-- ── Supersede pending_social_saves ───────────────────────────────────────────
-- The per-(user, url) model is replaced by the tables above. The table only
-- ever held unshipped test data, so it is dropped without backfill.

DROP TABLE IF EXISTS public.pending_social_saves;
DROP FUNCTION IF EXISTS public.touch_pending_social_saves_updated_at();
