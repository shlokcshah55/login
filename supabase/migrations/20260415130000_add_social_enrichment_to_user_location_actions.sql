-- Per-social-save enrichment captured by the tiktok/instagram processor.
-- The vibe vector is stored as 22 floats so it can be element-wise averaged
-- across all social saves for a location at home-feed read time. The rest of
-- the extraction (story, dishes, hooks, crowd/temporal signals) lives in a
-- single jsonb bucket — it's never filtered on, only surfaced.
ALTER TABLE public.user_location_actions
    ADD COLUMN IF NOT EXISTS social_vibe_vector real[],
    ADD COLUMN IF NOT EXISTS social_extraction jsonb,
    ADD COLUMN IF NOT EXISTS social_extraction_version smallint;

CREATE INDEX IF NOT EXISTS user_location_actions_social_vibe_idx
    ON public.user_location_actions (location_id)
    WHERE social_vibe_vector IS NOT NULL;

-- Bridge the type mismatch between locations.vibe_vector (integer[], 0-100)
-- and the aggregated social vector (real[], 0.0-1.0). Result is the existing
-- integer scale so downstream cosine similarity behaves unchanged.
CREATE OR REPLACE FUNCTION public.blend_vibe_vectors(
    base integer[],
    social real[],
    weight real
) RETURNS integer[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    result integer[];
    i integer;
    n integer;
    b real;
    s real;
BEGIN
    IF base IS NULL AND social IS NULL THEN
        RETURN NULL;
    END IF;

    IF social IS NULL OR weight IS NULL OR weight <= 0 THEN
        RETURN base;
    END IF;

    IF base IS NULL THEN
        n := array_length(social, 1);
        result := ARRAY[]::integer[];
        FOR i IN 1..n LOOP
            result := array_append(
                result,
                GREATEST(0, LEAST(100, ROUND(social[i] * 100)::integer))
            );
        END LOOP;
        RETURN result;
    END IF;

    n := LEAST(array_length(base, 1), array_length(social, 1));
    result := ARRAY[]::integer[];
    FOR i IN 1..n LOOP
        b := base[i]::real;
        s := social[i] * 100.0;
        result := array_append(
            result,
            GREATEST(0, LEAST(100, ROUND(((1.0 - weight) * b + weight * s))::integer))
        );
    END LOOP;

    -- Preserve any trailing base dimensions beyond the social vector length
    IF array_length(base, 1) > n THEN
        FOR i IN (n + 1)..array_length(base, 1) LOOP
            result := array_append(result, base[i]);
        END LOOP;
    END IF;

    RETURN result;
END;
$$;
