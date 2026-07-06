-- pending_social_saves
--
-- Tracks the processing state for every social URL a user shares.
-- Stores only minimal, non-sensitive fields:
--   - source URL (what the user shared)
--   - resolved place reference once confirmed
--   - candidate metadata (name, area) derived from public post text
--   - confidence score and evidence flags (booleans only)
--   - pipeline status
--
-- Does NOT store: raw video, screenshots, audio, raw OCR text,
--                 raw captions/comment dumps, or creator media.

CREATE TABLE IF NOT EXISTS public.pending_social_saves (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    user_id             uuid        NOT NULL,
    source_url          text        NOT NULL,
    platform            text        NOT NULL,
    status              text        NOT NULL DEFAULT 'pending',
    confidence_score    real,
    resolved_place_id   text,
    candidate_name      text,
    candidate_area      text,
    -- Serialised top-N CandidateMatch objects for the confirmation UI.
    -- Shape: [{place_id, name, address, score, candidate_name, candidate_area, source}]
    candidate_matches   jsonb       NOT NULL DEFAULT '[]'::jsonb,
    -- Boolean flags indicating which extraction methods produced signal.
    -- Shape: {caption: bool, thumbnail_ocr: bool, frame_ocr: bool}
    evidence_flags      jsonb       NOT NULL DEFAULT '{}'::jsonb,
    location_id         bigint,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pending_social_saves_pkey
        PRIMARY KEY (id),

    CONSTRAINT pending_social_saves_user_id_fkey
        FOREIGN KEY (user_id)
        REFERENCES public.users (supabase_id)
        ON DELETE CASCADE,

    CONSTRAINT pending_social_saves_location_id_fkey
        FOREIGN KEY (location_id)
        REFERENCES public.locations (location_id)
        ON DELETE SET NULL,

    CONSTRAINT pending_social_saves_platform_check
        CHECK (platform IN ('tiktok', 'instagram')),

    CONSTRAINT pending_social_saves_status_check
        CHECK (status IN ('pending', 'needs_confirmation', 'resolved', 'failed'))
);

-- One pending save per (user, URL) — prevents duplicate processing
CREATE UNIQUE INDEX IF NOT EXISTS pending_social_saves_user_url_key
    ON public.pending_social_saves (user_id, source_url);

CREATE INDEX IF NOT EXISTS pending_social_saves_user_status_idx
    ON public.pending_social_saves (user_id, status);

CREATE INDEX IF NOT EXISTS pending_social_saves_created_at_idx
    ON public.pending_social_saves (created_at DESC);

-- Automatically update updated_at on any row change
CREATE OR REPLACE FUNCTION public.touch_pending_social_saves_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER pending_social_saves_updated_at_trigger
    BEFORE UPDATE ON public.pending_social_saves
    FOR EACH ROW
    EXECUTE FUNCTION public.touch_pending_social_saves_updated_at();

-- RLS: users may only see and modify their own rows
ALTER TABLE public.pending_social_saves ENABLE ROW LEVEL SECURITY;

-- Service role (backend workers) has full access
REVOKE ALL ON TABLE public.pending_social_saves FROM anon, authenticated;
GRANT ALL  ON TABLE public.pending_social_saves TO service_role;

-- Authenticated users can read their own rows (for the Flutter app)
CREATE POLICY "Users can read their own pending saves"
    ON public.pending_social_saves
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Authenticated users can update their own rows (e.g. dismiss a pending save)
CREATE POLICY "Users can update their own pending saves"
    ON public.pending_social_saves
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);
