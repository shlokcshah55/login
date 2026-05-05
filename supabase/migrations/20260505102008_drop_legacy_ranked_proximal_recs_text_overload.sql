-- Drop legacy get_ranked_proximal_recommendations overload that keys on a
-- text user_id. The current system uses supabase_id (uuid).

-- Older deployments may have either an 8-arg or 10-arg version (later social
-- blend params were added). Drop both if present.
DROP FUNCTION IF EXISTS public.get_ranked_proximal_recommendations(
  text,
  double precision,
  double precision,
  double precision,
  double precision,
  double precision,
  double precision,
  integer
);

DROP FUNCTION IF EXISTS public.get_ranked_proximal_recommendations(
  text,
  double precision,
  double precision,
  double precision,
  double precision,
  double precision,
  double precision,
  integer,
  double precision,
  double precision
);

