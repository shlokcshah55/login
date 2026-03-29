CREATE OR REPLACE FUNCTION public.update_user_tag_affinity(p_user_id uuid, p_tag_affinities jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$DECLARE
  affinity_item jsonb;
  tag_id_val uuid;
  affinity_val real;
  v_tag_name text;
  v_index integer;
  v_current_affinity real[];
  v_tag_order text[] := ARRAY['cafe', 'casual', 'cozy', 'coffee_shop', 'bar', 'elegant', 'fine_dining', 'food_truck', 'hole_in_the_wall', 'late_night', 'live_music', 'michelin_starred', 'modern', 'fast_food', 'quiet', 'romantic', 'sports_bar', 'trendy', 'takeout_friendly', 'pub', 'grocery_store', 'brunch', 'outdoor_dining', 'wavy', 'bossman'];
BEGIN
  -- Get current affinity array
  SELECT vibe_tag_affinity INTO v_current_affinity
  FROM profiles
  WHERE id = p_user_id;

  -- Loop through each tag affinity update
  FOR affinity_item IN SELECT * FROM jsonb_array_elements(p_tag_affinities)
  LOOP
    tag_id_val := (affinity_item->>'tag_id')::uuid;
    affinity_val := LEAST(100, GREATEST(0, (affinity_item->>'affinity')::real));

    -- Look up tag name from tag_id
    SELECT name INTO v_tag_name
    FROM tags
    WHERE tag_id = tag_id_val;

    -- Find the index in the ordered array (1-based for PostgreSQL arrays)
    v_index := array_position(v_tag_order, v_tag_name);

    IF v_index IS NOT NULL THEN
      v_current_affinity[v_index] := affinity_val;
    END IF;
  END LOOP;

  -- Write back the updated array
  UPDATE profiles
  SET vibe_tag_affinity = v_current_affinity,
      updated_at = NOW()
  WHERE id = p_user_id;
END;$function$
;
