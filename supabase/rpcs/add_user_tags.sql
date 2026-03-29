CREATE OR REPLACE FUNCTION public.add_user_tags(p_user_id uuid, p_tag_ids uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Insert multiple tags at once
  INSERT INTO public.user_tags (user_id, tag_id)
  SELECT p_user_id, unnest(p_tag_ids);
END;
$function$
;
