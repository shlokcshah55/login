-- PostgREST RPC resolution fails when multiple overloaded functions match the
-- same set of named parameters. We previously introduced a new
-- `public.save_location_with_tags` signature that adds optional social
-- enrichment args with defaults, but the legacy 5-arg overload still exists.
-- When the client passes only the original 5 args, PostgREST sees multiple
-- viable candidates and returns PGRST203.

DO $$
DECLARE
  v_new regprocedure;
  v_new_defaults integer;
  v_new_argnames text[];
BEGIN
  -- Only drop the legacy overload if the new signature is present AND looks
  -- correct (extra args are optional via defaults).
  v_new := to_regprocedure(
    'public.save_location_with_tags(uuid,integer,text,boolean,text,real[],jsonb,smallint)'
  );

  IF v_new IS NULL THEN
    RAISE EXCEPTION
      'Expected new function public.save_location_with_tags(uuid,integer,text,boolean,text,real[],jsonb,smallint) to exist; refusing to drop legacy overload';
  END IF;

  SELECT pronargdefaults, proargnames
    INTO v_new_defaults, v_new_argnames
  FROM pg_proc
  WHERE oid = v_new;

  IF v_new_defaults IS NULL OR v_new_defaults < 3 THEN
    RAISE EXCEPTION
      'Expected new save_location_with_tags to have defaults for the last 3 args (pronargdefaults >= 3); got %',
      v_new_defaults;
  END IF;

  IF v_new_argnames IS NULL
     OR array_length(v_new_argnames, 1) <> 8
     OR v_new_argnames[1] <> 'p_user_id'
     OR v_new_argnames[2] <> 'p_location_id'
     OR v_new_argnames[3] <> 'p_saved_method'
     OR v_new_argnames[4] <> 'p_acked'
     OR v_new_argnames[5] <> 'p_source_video_url'
     OR v_new_argnames[6] <> 'p_social_vibe_vector'
     OR v_new_argnames[7] <> 'p_social_extraction'
     OR v_new_argnames[8] <> 'p_social_extraction_version' THEN
    RAISE EXCEPTION
      'Expected new save_location_with_tags arg names to match; got %',
      v_new_argnames;
  END IF;

  IF to_regprocedure('public.save_location_with_tags(uuid,integer,text,boolean,text)') IS NOT NULL THEN
    DROP FUNCTION public.save_location_with_tags(uuid,integer,text,boolean,text);
  END IF;
END $$;

-- Ensure expected roles can call the surviving signature.
GRANT EXECUTE ON FUNCTION public.save_location_with_tags(
  uuid, integer, text, boolean, text, real[], jsonb, smallint
) TO anon, authenticated, service_role;

