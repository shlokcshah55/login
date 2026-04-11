DROP FUNCTION IF EXISTS public.get_location_collection_ids(bigint);

CREATE FUNCTION public.get_location_collection_ids(p_location_id bigint)
RETURNS TABLE(collection_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT cl.collection_id
  FROM public.collection_locations cl
  INNER JOIN public.collections c ON c.collection_id = cl.collection_id
  WHERE cl.location_id = p_location_id
    AND c.created_by = auth.uid();
END;
$function$;
