CREATE OR REPLACE FUNCTION public.get_bubble_member_ids_excluding_user(
    p_bubble_id uuid,
    p_excluded_user_id uuid
)
RETURNS TABLE(
    user_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT bm.user_id
    FROM public.bubble_members bm
    WHERE bm.bubble_id = p_bubble_id
      AND bm.user_id <> p_excluded_user_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_bubble_member_ids_excluding_user(uuid, uuid)
    TO authenticated, service_role;
