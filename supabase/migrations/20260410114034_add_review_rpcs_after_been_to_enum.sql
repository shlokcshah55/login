-- ─────────────────────────────────────────────────────────────
-- 1. RPC: create_location_review
--    Inserts into location_reviews + fires been_to action.
--    SECURITY DEFINER so it can bypass RLS for the action insert.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_location_review(
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
  v_review  public.location_reviews%ROWTYPE;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  INSERT INTO public.location_reviews (
    location_id,
    user_id,
    content,
    rating,
    private
  )
  VALUES (
    p_location_id,
    v_user_id,
    p_content,
    p_rating,
    p_gatekeep
  )
  RETURNING * INTO v_review;

  -- Record the been_to action (idempotent via ON CONFLICT UPDATE)
  PERFORM public.create_user_location_action(
    p_user_id      => v_user_id,
    p_location_id  => p_location_id,
    p_action       => 'been_to'
  );

  RETURN jsonb_build_object(
    'success', true,
    'id',      v_review.id
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_location_review(bigint, text, numeric, boolean)
  TO anon, authenticated, service_role;


-- ─────────────────────────────────────────────────────────────
-- 2. RPC: get_user_been_to_count
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_user_been_to_count(
  p_user_id uuid
)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT count(*)::integer
  FROM public.user_location_actions
  WHERE user_id = p_user_id
    AND action = 'been_to';
$$;

GRANT EXECUTE ON FUNCTION public.get_user_been_to_count(uuid)
  TO anon, authenticated, service_role;


-- ─────────────────────────────────────────────────────────────
-- 3. RPC: get_user_been_to_reviews
--    Returns reviews joined with location name + image_url
--    for use in the swipe ranker. Ordered by rating DESC.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_user_been_to_reviews(
  p_user_id uuid
)
RETURNS TABLE (
  review_id    uuid,
  location_id  bigint,
  location_name text,
  image_url    text,
  rating       numeric,
  content      text,
  private      boolean,
  created_at   timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    lr.id            AS review_id,
    lr.location_id,
    l.name           AS location_name,
    l.image_url,
    lr.rating,
    lr.content,
    lr.private,
    lr.created_at
  FROM public.location_reviews lr
  JOIN public.locations l ON l.location_id = lr.location_id
  JOIN public.user_location_actions ula
    ON ula.user_id    = lr.user_id
   AND ula.location_id = lr.location_id
   AND ula.action      = 'been_to'
  WHERE lr.user_id = p_user_id
  ORDER BY lr.rating DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_been_to_reviews(uuid)
  TO anon, authenticated, service_role;
