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

    RETURN p_supabase_id;
END;
$function$
;
