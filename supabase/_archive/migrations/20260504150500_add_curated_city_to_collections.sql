-- Add city metadata to curated collections so the app can filter curated eat-lists
-- by major city without maintaining a client-side mapping.

ALTER TABLE public.collections
ADD COLUMN IF NOT EXISTS curated_city text;

CREATE INDEX IF NOT EXISTS collections_curated_city_idx
  ON public.collections (curated_city)
  WHERE is_curated = true;

