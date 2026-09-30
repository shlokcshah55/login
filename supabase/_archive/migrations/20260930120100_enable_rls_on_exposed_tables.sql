-- A1 security: tables in public that had RLS disabled (readable/writable by anon).
-- Client direct access is owner-scoped; cross-user reads go through SECURITY DEFINER
-- RPCs; backend services use the service role. All unaffected by these policies.

-- collections --------------------------------------------------------------
alter table public.collections enable row level security;

create policy "collections_select_own_or_public" on public.collections
  for select to authenticated
  using (created_by = auth.uid() or is_public or is_curated);

-- create_user_profile (SECURITY INVOKER) seeds the default collections.
create policy "collections_insert_own" on public.collections
  for insert to authenticated
  with check (created_by = auth.uid());

create policy "collections_update_own" on public.collections
  for update to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

create policy "collections_delete_own" on public.collections
  for delete to authenticated
  using (created_by = auth.uid());

revoke all on public.collections from anon;

-- collection_locations -----------------------------------------------------
alter table public.collection_locations enable row level security;

create policy "collection_locations_select" on public.collection_locations
  for select to authenticated
  using (
    added_by = auth.uid()
    or exists (
      select 1 from public.collections c
      where c.collection_id = collection_locations.collection_id
        and (c.created_by = auth.uid() or c.is_public or c.is_curated)
    )
  );

create policy "collection_locations_write_own_collection" on public.collection_locations
  for all to authenticated
  using (
    exists (
      select 1 from public.collections c
      where c.collection_id = collection_locations.collection_id
        and c.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.collections c
      where c.collection_id = collection_locations.collection_id
        and c.created_by = auth.uid()
    )
  );

revoke all on public.collection_locations from anon;

-- notifications ------------------------------------------------------------
-- Clients read/update/insert only their own rows (the FCM handler saves the
-- incoming push for the current user). send-notification uses the service role.
alter table public.notifications enable row level security;

create policy "notifications_select_own" on public.notifications
  for select to authenticated using (user_id = auth.uid());

create policy "notifications_insert_own" on public.notifications
  for insert to authenticated with check (user_id = auth.uid());

create policy "notifications_update_own" on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "notifications_delete_own" on public.notifications
  for delete to authenticated using (user_id = auth.uid());

revoke all on public.notifications from anon;

-- locations ----------------------------------------------------------------
-- Already has "Anyone can view locations" (SELECT, true) but RLS was off, so
-- anon could also INSERT/UPDATE/DELETE. Writes come from backend services only.
alter table public.locations enable row level security;
revoke insert, update, delete, truncate on public.locations from anon, authenticated;

-- video_insights -----------------------------------------------------------
alter table public.video_insights enable row level security;

create policy "video_insights_select_all" on public.video_insights
  for select using (true);

revoke insert, update, delete, truncate on public.video_insights from anon, authenticated;

-- backend-only tables: RLS on, no policies => service role only ------------
alter table public.location_similarities enable row level security;
alter table public.v_action_exists enable row level security;
revoke all on public.location_similarities from anon, authenticated;
revoke all on public.v_action_exists from anon, authenticated;

-- SECURITY DEFINER views ---------------------------------------------------
-- user_bubble_chats exposed every bubble's last message to anyone. As an
-- invoker view it respects user_chat_state / bubbles / messages RLS.
alter view public.user_bubble_chats set (security_invoker = true);
revoke all on public.user_bubble_chats from anon;

-- Analytics views are for the dashboard (service role), not the app.
alter view public.analytics_daily_user_activity set (security_invoker = true);
alter view public.analytics_feature_adoption_daily set (security_invoker = true);
alter view public.analytics_notification_funnel_daily set (security_invoker = true);
alter view public.analytics_retention_cohorts set (security_invoker = true);
revoke all on public.analytics_daily_user_activity from anon, authenticated;
revoke all on public.analytics_feature_adoption_daily from anon, authenticated;
revoke all on public.analytics_notification_funnel_daily from anon, authenticated;
revoke all on public.analytics_retention_cohorts from anon, authenticated;
