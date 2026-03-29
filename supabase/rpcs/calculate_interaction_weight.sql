CREATE OR REPLACE FUNCTION public.calculate_interaction_weight(p_user_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_interaction_count INTEGER;
    v_weight NUMERIC;
    v_decay_coefficient NUMERIC := 0.0135;
BEGIN
    -- Count total location actions for this user
    SELECT COUNT(*) INTO v_interaction_count
    FROM user_location_actions
    WHERE user_id = p_user_id;

    -- Calculate inverse-log decay weight
    -- Coefficient 0.0135 means:
    -- - First 50 interactions: weight ~0.9-1.0
    -- - 100 interactions: weight ~0.88
    -- - 500 interactions: weight ~0.73
    -- - 1000 interactions: weight ~0.66

    v_weight := 1.0 / (1.0 + v_decay_coefficient * LN(1 + v_interaction_count));

    -- Clamp to valid range [0.0, 1.0]
    v_weight := LEAST(GREATEST(v_weight, 0.0), 1.0);

    RETURN v_weight;
END;
$function$
;
