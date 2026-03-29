CREATE OR REPLACE FUNCTION public.add_user_tags_batch(p_user_id uuid, p_tag_ids uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  BEGIN
    INSERT INTO user_tag_affinities (user_id, tag_id, affinity, updated_at)
    SELECT p_user_id, unnest(p_tag_ids), 50.0, NOW()
    ON CONFLICT (user_id, tag_id) DO NOTHING;
  END;
  $function$
;
