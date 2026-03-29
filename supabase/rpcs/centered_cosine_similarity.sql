CREATE OR REPLACE FUNCTION public.centered_cosine_similarity(vec1 integer[], vec2 integer[])
 RETURNS double precision
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  mean1 FLOAT;
  mean2 FLOAT;
  centered1 FLOAT[];
  centered2 FLOAT[];
  dot_product FLOAT := 0.0;
  norm1 FLOAT := 0.0;
  norm2 FLOAT := 0.0;
  i INT;
  max_len INT;
BEGIN
  -- Handle null/empty vectors
  IF vec1 IS NULL OR vec2 IS NULL OR array_length(vec1, 1) IS NULL OR array_length(vec2, 1) IS NULL THEN
    RETURN 0.0;
  END IF;

  -- Get max length (handle dimension mismatch by padding with zeros conceptually)
  max_len := GREATEST(array_length(vec1, 1), array_length(vec2, 1));

  -- Calculate means
  mean1 := (SELECT AVG(v) FROM unnest(vec1) v);
  mean2 := (SELECT AVG(v) FROM unnest(vec2) v);

  -- Center vectors and compute dot product and norms
  FOR i IN 1..max_len LOOP
    DECLARE
      v1 FLOAT := COALESCE(vec1[i], 0)::FLOAT - mean1;
      v2 FLOAT := COALESCE(vec2[i], 0)::FLOAT - mean2;
    BEGIN
      dot_product := dot_product + (v1 * v2);
      norm1 := norm1 + (v1 * v1);
      norm2 := norm2 + (v2 * v2);
    END;
  END LOOP;

  -- Handle zero norm (uniform vectors) - return 0.0
  IF norm1 = 0 OR norm2 = 0 THEN
    RETURN 0.0;
  END IF;

  -- Compute centered cosine similarity
  DECLARE
    similarity FLOAT := dot_product / (SQRT(norm1) * SQRT(norm2));
  BEGIN
    -- Normalize from [-1, 1] to [0, 1]
    RETURN GREATEST(0.0, LEAST(1.0, (similarity + 1.0) / 2.0));
  END;
END;
$function$
;
