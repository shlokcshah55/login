CREATE OR REPLACE FUNCTION public.compute_quality_score(rating double precision, user_ratings_total numeric, saved_count smallint DEFAULT 0)
 RETURNS double precision
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  bayesian_rating FLOAT;
  review_trust FLOAT;
  rating_score FLOAT;
  social_score FLOAT;
BEGIN
  -- Bayesian rating: shrink towards 3.8 prior with 50 pseudo-reviews
  bayesian_rating := (COALESCE(rating, 3.8) * COALESCE(user_ratings_total, 0) + 3.8 * 50)
                     / (COALESCE(user_ratings_total, 0) + 50);

  -- Review trust: log-power curve, punishes low reviews hard
  -- 0→0.0, 3→0.34, 10→0.52, 30→0.70, 100→0.83, 500→0.95
  review_trust := LEAST(
    0.95 * POWER(LN(1 + COALESCE(user_ratings_total, 0)) / LN(501), 0.6),
    1.0
  );

  -- Rating score: bayesian rating normalised to 0-1, scaled by review trust
  rating_score := (bayesian_rating / 5.0) * review_trust;

  -- Pinit social proof: log scale, ~100 saves maxes out
  social_score := LEAST(
    LN(1 + COALESCE(saved_count, 0)) / LN(100),
    1.0
  );

  -- Final score: 60% rating (includes trust), 40% social proof
  RETURN LEAST(
    (0.6 * rating_score) + (0.4 * social_score),
    1.0
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.compute_quality_score(rating double precision, user_ratings_total integer, saved_count integer, outdoor_seating boolean, live_music boolean, serves_cocktails boolean, serves_brunch boolean, serves_wine boolean, serves_beer boolean, good_for_groups boolean, good_for_children boolean, serves_vegetarian_food boolean, serves_breakfast boolean, serves_lunch boolean, serves_dinner boolean, serves_coffee boolean, serves_dessert boolean, good_for_watching_sports boolean)
 RETURNS double precision
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  bayesian_rating FLOAT;
  review_trust FLOAT;
  rating_score FLOAT;
  social_score FLOAT;
  feature_count INT;
  feature_score FLOAT;
BEGIN
  -- Bayesian rating: shrink towards 3.8 prior with 50 pseudo-reviews
  bayesian_rating := (COALESCE(rating, 3.8) * COALESCE(user_ratings_total, 0) + 3.8 * 50)
                     / (COALESCE(user_ratings_total, 0) + 50);

  -- Review trust: log-power curve, punishes low reviews hard
  -- 0→0.0, 3→0.34, 10→0.52, 30→0.70, 100→0.83, 500→0.95
  review_trust := LEAST(
    0.95 * POWER(LN(1 + COALESCE(user_ratings_total, 0)) / LN(501), 0.6),
    1.0
  );

  -- Rating score: bayesian rating normalised to 0-1, scaled by review trust
  rating_score := (bayesian_rating / 5.0) * review_trust;

  -- Pinit social proof: log scale, ~100 saves maxes out
  social_score := LEAST(
    LN(1 + COALESCE(saved_count, 0)) / LN(100),
    1.0
  );

  -- Feature richness: count of true boolean attributes, 8+ maxes out
  feature_count := (
    COALESCE(outdoor_seating, false)::INT +
    COALESCE(live_music, false)::INT +
    COALESCE(serves_cocktails, false)::INT +
    COALESCE(serves_brunch, false)::INT +
    COALESCE(serves_wine, false)::INT +
    COALESCE(serves_beer, false)::INT +
    COALESCE(good_for_groups, false)::INT +
    COALESCE(good_for_children, false)::INT +
    COALESCE(serves_vegetarian_food, false)::INT +
    COALESCE(serves_breakfast, false)::INT +
    COALESCE(serves_lunch, false)::INT +
    COALESCE(serves_dinner, false)::INT +
    COALESCE(serves_coffee, false)::INT +
    COALESCE(serves_dessert, false)::INT +
    COALESCE(good_for_watching_sports, false)::INT
  );
  feature_score := LEAST(feature_count / 8.0, 1.0);

  -- Final score: 35% rating, 25% review trust, 25% social, 15% features
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
