-- -- 1. Extend action_type enum
-- ALTER TYPE public.action_type ADD VALUE IF NOT EXISTS 'been_to';

-- -- 2. Schema changes to location_reviews
-- ALTER TABLE public.location_reviews
--   ADD COLUMN IF NOT EXISTS gatekeep boolean NOT NULL DEFAULT false;

-- ALTER TABLE public.location_reviews
--   ALTER COLUMN rating TYPE numeric(4,1) USING rating::numeric(4,1);

-- -- 3. RLS policies for location_reviews (currently none exist)
-- DROP POLICY IF EXISTS "location_reviews_select" ON public.location_reviews;
-- CREATE POLICY "location_reviews_select"
--   ON public.location_reviews FOR SELECT TO authenticated
--   USING (user_id = auth.uid() OR gatekeep = false);

-- DROP POLICY IF EXISTS "location_reviews_insert" ON public.location_reviews;
-- CREATE POLICY "location_reviews_insert"
--   ON public.location_reviews FOR INSERT TO authenticated
--   WITH CHECK (user_id = auth.uid());

-- DROP POLICY IF EXISTS "location_reviews_update" ON public.location_reviews;
-- CREATE POLICY "location_reviews_update"
--   ON public.location_reviews FOR UPDATE TO authenticated
--   USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- DROP POLICY IF EXISTS "location_reviews_delete" ON public.location_reviews;
-- CREATE POLICY "location_reviews_delete"
--   ON public.location_reviews FOR DELETE TO authenticated
--   USING (user_id = auth.uid());

-- -- 4. RPC: create_location_review (SECURITY DEFINER — inserts review + fires been_to action atomically)
-- CREATE OR REPLACE FUNCTION public.create_location_review(
--   p_location_id  bigint,
--   p_content      text     DEFAULT NULL,
--   p_rating       numeric  DEFAULT NULL,
--   p_gatekeep     boolean  DEFAULT false
-- )
-- RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
-- DECLARE
--   v_user_id uuid;
--   v_review  public.location_reviews%ROWTYPE;
-- BEGIN
--   v_user_id := auth.uid();
--   IF v_user_id IS NULL THEN
--     RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
--   END IF;

--   INSERT INTO public.location_reviews (location_id, user_id, content, rating, gatekeep, private)
--   VALUES (p_location_id, v_user_id, p_content, p_rating, p_gatekeep, p_gatekeep)
--   RETURNING * INTO v_review;

--   -- Idempotent via ON CONFLICT DO UPDATE in create_user_location_action
--   PERFORM public.create_user_location_action(
--     p_user_id => v_user_id, p_location_id => p_location_id, p_action => 'been_to'
--   );

--   RETURN jsonb_build_object('success', true, 'id', v_review.id);
-- EXCEPTION WHEN OTHERS THEN
--   RETURN jsonb_build_object('success', false, 'error', SQLERRM);
-- END;
-- $$;
-- GRANT EXECUTE ON FUNCTION public.create_location_review(bigint, text, numeric, boolean)
--   TO anon, authenticated, service_role;

-- -- 5. RPC: get_user_been_to_count
-- CREATE OR REPLACE FUNCTION public.get_user_been_to_count(p_user_id uuid)
-- RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER AS $$
--   SELECT count(*)::integer FROM public.user_location_actions
--   WHERE user_id = p_user_id AND action = 'been_to';
-- $$;
-- GRANT EXECUTE ON FUNCTION public.get_user_been_to_count(uuid)
--   TO anon, authenticated, service_role;

-- -- 6. RPC: get_user_been_to_reviews (for swipe ranker — returns with location name+image)
-- CREATE OR REPLACE FUNCTION public.get_user_been_to_reviews(p_user_id uuid)
-- RETURNS TABLE (
--   review_id uuid, location_id bigint, location_name text,
--   image_url text, rating numeric, content text, gatekeep boolean, created_at timestamptz
-- )
-- LANGUAGE sql STABLE SECURITY DEFINER AS $$
--   SELECT lr.id, lr.location_id, l.name, l.image_url,
--          lr.rating, lr.content, lr.gatekeep, lr.created_at
--   FROM public.location_reviews lr
--   JOIN public.locations l ON l.location_id = lr.location_id
--   JOIN public.user_location_actions ula
--     ON ula.user_id = lr.user_id AND ula.location_id = lr.location_id AND ula.action = 'been_to'
--   WHERE lr.user_id = p_user_id
--   ORDER BY lr.created_at DESC;
-- $$;
-- GRANT EXECUTE ON FUNCTION public.get_user_been_to_reviews(uuid)
--   TO anon, authenticated, service_role;
