CREATE OR REPLACE FUNCTION public.normalized_dot_product(vec1 integer[], vec2 integer[])
 RETURNS double precision
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  dot_prod FLOAT := 0.0;
  max_len INT;
  max_possible FLOAT;
  i INT;
BEGIN
  -- Handle null/empty vectors
  IF vec1 IS NULL OR vec2 IS NULL OR array_length(vec1, 1) IS NULL OR array_length(vec2, 1) IS NULL THEN
    RETURN 0.0;
  END IF;

  -- Get max length
  max_len := GREATEST(array_length(vec1, 1), array_length(vec2, 1));

  -- Compute dot product
  FOR i IN 1..max_len LOOP
    dot_prod := dot_prod + (COALESCE(vec1[i], 0)::FLOAT * COALESCE(vec2[i], 0)::FLOAT);
  END LOOP;

  -- Normalize to [0, 1] assuming values are in 0-100 range
  max_possible := max_len * 100.0 * 100.0;

  IF max_possible = 0 THEN
    RETURN 0.0;
  END IF;

  RETURN GREATEST(0.0, LEAST(1.0, dot_prod / max_possible));
END;
$function$
;
