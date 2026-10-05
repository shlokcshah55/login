-- Every new account follows the Pinit founders (founder + cofounder) by default.
--
-- Accounts are created by two client-called RPCs (create_user_profile for
-- email, ensure_user_record_exists for Google/Apple). A single AFTER INSERT
-- trigger on public.users covers both without rewriting either function.
--
-- * The follow is inserted as 'accepted' so it shows in the new user's
--   following list immediately (no follow-request notification).
-- * It never blocks sign-up: a founder row that is missing (local/dev DBs) is
--   skipped, and any failure is swallowed.
-- * Existing users are not backfilled.
--
-- Impact: one new SECURITY DEFINER function + one trigger on public.users.
-- No table/column changes. Bypassing RLS is intentional: the user_friends
-- INSERT policy requires auth.uid() = follower_id, which does not hold inside
-- every account-creation path.

CREATE OR REPLACE FUNCTION public.follow_founder_on_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  -- Founder, cofounder.
  v_founders constant uuid[] := ARRAY[
    'cb9c8a52-581b-466f-9a76-588532c4b5e9',
    '4b4538bf-b0dd-4533-ae88-0762e28e8281'
  ]::uuid[];
BEGIN
  IF NEW.supabase_id IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    INSERT INTO public.user_friends (follower_id, followee_id, status, created_at)
    SELECT NEW.supabase_id, f.supabase_id, 'accepted'::public.relationship_status, NOW()
    FROM public.users f
    WHERE f.supabase_id = ANY (v_founders)
      AND f.supabase_id <> NEW.supabase_id
    ON CONFLICT (followee_id, follower_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    -- Never block account creation on this.
    RAISE WARNING 'follow_founder_on_signup failed for %: %', NEW.supabase_id, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.follow_founder_on_signup() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_follow_founder_on_signup ON public.users;
CREATE TRIGGER trg_follow_founder_on_signup
AFTER INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.follow_founder_on_signup();
