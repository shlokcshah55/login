CREATE OR REPLACE FUNCTION public.create_collection(
    p_name      text,
    p_is_public boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id         uuid;
    new_collection_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    INSERT INTO collections (name, created_by, is_public, created_at)
    VALUES (trim(p_name), v_user_id, p_is_public, now())
    RETURNING collection_id INTO new_collection_id;

    RETURN new_collection_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_collection(text, boolean)
    TO anon, authenticated, service_role;