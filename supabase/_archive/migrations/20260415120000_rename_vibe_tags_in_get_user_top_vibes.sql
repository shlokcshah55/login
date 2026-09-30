CREATE OR REPLACE FUNCTION public.get_user_top_vibes(p_user_id uuid)
 RETURNS TABLE(tag text, score double precision)
 LANGUAGE plpgsql
AS $function$
declare
  readable_tags text[] := ARRAY[
    'Cafe', 'Casual', 'Cozy', 'Coffee shop', 'Bar', 'Elegant',
    'Fine dining', 'Food truck', 'Hole in the wall', 'Late night',
    'Live music', 'Bougie', 'Modern', 'Fast food', 'Quiet',
    'Romantic', 'Sports bar', 'Trendy', 'Takeout friendly', 'Pub',
    'Shop', 'Brunch', 'Outdoor dining', 'Wavy', 'Bossman'
  ];

  readable_diet_tags text[] := ARRAY[
    'Halal', 'Vegan', 'Gluten free', 'Vegetarian', 'Dairy free', 'Nut free'
  ];

  scores float8[];
  dietary_scores float8[];
begin
  -- Pull the vibe affinity array
  select vibe_tag_affinity
  into scores
  from users
  where supabase_id = p_user_id;

  -- Pull dietary affinity array
  select dietary_requirement_tag_affinity
  into dietary_scores
  from users
  where supabase_id = p_user_id;

  -- Return top 3 vibe tags
  return query
    select t.tag, t.score
    from unnest(readable_tags, scores) as t(tag, score)
    order by t.score desc
    limit 3;

  -- Return dietary tags with score > 50
  return query
    select d.tag, d.score
    from unnest(readable_diet_tags, dietary_scores) as d(tag, score)
    where d.score > 50;

end;
$function$
;
