CREATE OR REPLACE FUNCTION public.calculate_tag_affinity_delta(p_current_affinity numeric, p_location_tag_score integer, p_value integer, p_weight numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    -- Formula: delta = value * weight * ((locationAffinity - 50) / 50)
    -- This normalizes the location tag score to a -1 to +1 range:
    -- - Score 0 = -1.0 (strong negative signal)
    -- - Score 50 = 0.0 (neutral)
    -- - Score 100 = +1.0 (strong positive signal)

    RETURN p_value * p_weight * ((p_location_tag_score - 50.0) / 50.0);
END;
$function$
;
