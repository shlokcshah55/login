CREATE OR REPLACE FUNCTION public.initialize_vibe_tags_for_user(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$BEGIN
    UPDATE users
    SET vibe_tag_affinity = ARRAY[50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 0, 50, 50, 50, 50]
    WHERE supabase_id = p_user_id;
END;$function$
;
