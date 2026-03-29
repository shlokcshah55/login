CREATE OR REPLACE FUNCTION public.compute_location_quality_score(p_location_id bigint)
 RETURNS double precision
 LANGUAGE plpgsql
AS $function$
DECLARE
  loc RECORD;
  bayesian_rating FLOAT;
  review_trust FLOAT;
  rating_score FLOAT;
  social_score FLOAT;
  feature_count INT;
  feature_score FLOAT;
BEGIN
  SELECT
    l.rating,
    l.user_ratings_total,
    l.saved_count,
    l.outdoor_seating,
    l.live_music,
    l.serves_cocktails,
    l.serves_brunch,
    l.serves_wine,
    l.serves_beer,
    l.good_for_groups,
    l.good_for_children,
    l.serves_vegetarian_food,
    l.serves_breakfast,
    l.serves_lunch,
    l.serves_dinner,
    l.serves_coffee,
    l.serves_dessert,
    l.good_for_watching_sports
  INTO loc
  FROM locations l
  WHERE l.location_id = p_location_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Bayesian rating: shrink towards 3.8 prior with 50 pseudo-reviews
  bayesian_rating := (COALESCE(loc.rating, 3.8) * COALESCE(loc.user_ratings_total, 0) + 3.8 * 50)
                     / (COALESCE(loc.user_ratings_total, 0) + 50);

  -- Review trust: log-power curve
  review_trust := LEAST(
    0.95 * POWER(LN(1 + COALESCE(loc.user_ratings_total, 0)) / LN(501), 0.6),
    1.0
  );

  -- Rating score
  rating_score := (bayesian_rating / 5.0) * review_trust;

  -- Social proof from saves
  social_score := LEAST(
    LN(1 + COALESCE(loc.saved_count, 0)) / LN(100),
    1.0
  );

  -- Feature richness
  feature_count := (
    COALESCE(loc.outdoor_seating, false)::INT +
    COALESCE(loc.live_music, false)::INT +
    COALESCE(loc.serves_cocktails, false)::INT +
    COALESCE(loc.serves_brunch, false)::INT +
    COALESCE(loc.serves_wine, false)::INT +
    COALESCE(loc.serves_beer, false)::INT +
    COALESCE(loc.good_for_groups, false)::INT +
    COALESCE(loc.good_for_children, false)::INT +
    COALESCE(loc.serves_vegetarian_food, false)::INT +
    COALESCE(loc.serves_breakfast, false)::INT +
    COALESCE(loc.serves_lunch, false)::INT +
    COALESCE(loc.serves_dinner, false)::INT +
    COALESCE(loc.serves_coffee, false)::INT +
    COALESCE(loc.serves_dessert, false)::INT +
    COALESCE(loc.good_for_watching_sports, false)::INT
  );
  feature_score := LEAST(feature_count / 8.0, 1.0);

  -- Final: 35% rating, 25% review trust, 25% social, 15% features
  RETURN LEAST(
    (0.35 * rating_score) +
    (0.25 * review_trust) +
    (0.25 * social_score) +
    (0.15 * feature_score),
    1.0
  );
END;
$function$
;
