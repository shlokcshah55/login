-- Ensure every user starts with the two app-owned system eatlists:
--   - Been To
--   - Shared Finds, displayed in app copy as "Saved from your scroll"
--
-- Shared Finds is still populated lazily by social saves, but the collection
-- itself should exist even before the user has saved any TikToks/Reels.

CREATE OR REPLACE FUNCTION public.ensure_user_record_exists(
    p_supabase_id uuid,
    p_email       text,
    p_name        text,
    p_username    text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    INSERT INTO public.users (
        supabase_id,
        email,
        name,
        username,
        created_at,
        wizard_completed,
        vibe_tag_affinity,
        dietary_requirement_tag_affinity
    )
    VALUES (
        p_supabase_id,
        p_email,
        p_name,
        p_username,
        NOW(),
        false,
        ARRAY[50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 0, 50, 50, 50, 50],
        ARRAY[0, 0, 0, 0, 0, 0]
    )
    ON CONFLICT (supabase_id) DO NOTHING;

    INSERT INTO public.collections (name, created_by, is_public, is_curated)
    SELECT default_collection.name, p_supabase_id, true, false
    FROM (VALUES ('Been To'), ('Shared Finds')) AS default_collection(name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.collections existing_collection
        WHERE existing_collection.created_by = p_supabase_id
          AND existing_collection.name = default_collection.name
    );

    RETURN p_supabase_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.ensure_user_record_exists(uuid, text, text, text)
    TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_user_profile(
    p_supabase_id uuid,
    p_email       text,
    p_name        text,
    p_username    text
)
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    INSERT INTO public.users (supabase_id, email, name, created_at, wizard_completed, username)
    VALUES (p_supabase_id, p_email, p_name, NOW(), false, p_username);

    INSERT INTO public.collections (name, created_by, is_public, is_curated)
    SELECT default_collection.name, p_supabase_id, true, false
    FROM (VALUES ('Been To'), ('Shared Finds')) AS default_collection(name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.collections existing_collection
        WHERE existing_collection.created_by = p_supabase_id
          AND existing_collection.name = default_collection.name
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_user_profile(uuid, text, text, text)
    TO anon, authenticated, service_role;

INSERT INTO public.collections (name, created_by, is_public, is_curated)
SELECT default_collection.name, u.supabase_id, true, false
FROM public.users u
CROSS JOIN (VALUES ('Been To'), ('Shared Finds')) AS default_collection(name)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.collections existing_collection
    WHERE existing_collection.created_by = u.supabase_id
      AND existing_collection.name = default_collection.name
);
