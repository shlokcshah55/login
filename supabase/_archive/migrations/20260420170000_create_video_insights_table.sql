-- =============================================================================
-- Create video_insights table
-- Shared extraction cache: one row per unique (source_video_url, location_id).
-- Populated once by the TikTok processor; reused by all users who save the
-- same video.  Stores GLOBAL data about what the video says about the location.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.video_insights (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  source_video_url text NOT NULL,
  location_id bigint NOT NULL,

  -- Structured extractions from the video
  key_dishes jsonb,              -- [{"name": "Truffle Pasta", "description": "Creator's top pick", "price": "£18"}]
  creator_notes text,            -- 1-2 sentence summary of what the creator said
  vibe_signals jsonb,            -- {"romantic": 0.8, "late_night": 0.6} — vibe hints from video content
  special_offers jsonb,           -- [{"offer": "20% off", "valid_until": null, "code": "TIKTOK20"}]
  sentiment text,                -- "positive", "negative", "mixed"
  creator_handle text,           -- @username of the TikTok/Reel creator
  video_description text,        -- Original video description (cached for display)

  extracted_at timestamp with time zone NOT NULL DEFAULT now(),
  extraction_model text,         -- e.g. "gpt-4o-mini" for traceability

  CONSTRAINT video_insights_pkey PRIMARY KEY (id),
  CONSTRAINT video_insights_location_id_fkey FOREIGN KEY (location_id)
      REFERENCES public.locations(location_id),
  CONSTRAINT video_insights_unique_url_location
      UNIQUE (source_video_url, location_id)
);

CREATE INDEX IF NOT EXISTS idx_video_insights_location
    ON public.video_insights(location_id);
CREATE INDEX IF NOT EXISTS idx_video_insights_url
    ON public.video_insights(source_video_url);
