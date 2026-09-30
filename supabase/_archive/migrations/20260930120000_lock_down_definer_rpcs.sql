-- A1 security: SECURITY DEFINER functions that were executable by anon/authenticated
-- with no caller check. Backend services use the service role and are unaffected.

-- Admin / maintenance functions: service role only.
revoke execute on function public.admin_delete_users(uuid[]) from public, anon, authenticated;
revoke execute on function public.cleanup_old_app_analytics_events(interval) from public, anon, authenticated;
revoke execute on function public.claim_location_vibe_processing(integer, text, integer) from public, anon, authenticated;
revoke execute on function public.update_location_image_url(bigint, text) from public, anon, authenticated;
revoke execute on function public.update_location_photo_reference(bigint, text) from public, anon, authenticated;

-- Called by the signed-in client; no reason for anon to reach them.
revoke execute on function public.update_location_popularity(integer, integer, integer) from public, anon;
revoke execute on function public.update_location_photos(bigint, jsonb) from public, anon;

-- Per-user writes: only the user themselves (or the service role) may update.
create or replace function public.update_fcm_token(p_user_id uuid, p_fcm_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' and p_user_id is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  update users
  set fcm_token = p_fcm_token,
      fcm_token_updated_at = now()
  where supabase_id = p_user_id;
end;
$$;

create or replace function public.update_user_location(p_user_id uuid, p_lat double precision, p_lng double precision)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' and p_user_id is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  update users
  set last_lat = p_lat,
      last_lng = p_lng,
      last_location_at = now()
  where supabase_id = p_user_id;
end;
$$;

revoke execute on function public.update_fcm_token(uuid, text) from public, anon;
revoke execute on function public.update_user_location(uuid, double precision, double precision) from public, anon;
grant execute on function public.update_fcm_token(uuid, text) to authenticated, service_role;
grant execute on function public.update_user_location(uuid, double precision, double precision) to authenticated, service_role;
