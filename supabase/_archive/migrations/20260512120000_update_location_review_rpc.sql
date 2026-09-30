-- Update an existing location review without inserting a new row.
-- Used when editing a previously submitted been-to rating/notes.

CREATE OR REPLACE FUNCTION public.update_location_review(
  p_location_id  bigint,
  p_content      text     DEFAULT NULL,
  p_rating       numeric  DEFAULT NULL,
  p_gatekeep     boolean  DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_review_id uuid;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Update the most recent review row for this user/location.
  SELECT id
    INTO v_review_id
  FROM public.location_reviews
  WHERE user_id = v_user_id
    AND location_id = p_location_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_review_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No existing review');
  END IF;

  UPDATE public.location_reviews
  SET
    content = p_content,
    rating  = p_rating,
    private = p_gatekeep
  WHERE id = v_review_id
    AND user_id = v_user_id;

  -- Ensure the been_to action exists (idempotent).
  PERFORM public.create_user_location_action(
    p_user_id      => v_user_id,
    p_location_id  => p_location_id,
    p_action       => 'been_to'
  );

  RETURN jsonb_build_object('success', true, 'id', v_review_id);

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_location_review(bigint, text, numeric, boolean)
  TO anon, authenticated, service_role;

