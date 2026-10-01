-- Proximity notifications: social context for saved places + a send log.
--
-- 1. get_proximity_context(): for every place the caller has saved, the
--    creator's reason for saving it (top dish, vibe, creator handle) and how
--    sure the share extraction was. The client folds this into its on-device
--    proximity policy so TikTok / Instagram saves get richer, better-gated
--    pushes. Shapes it reads:
--      video_insights.key_dishes    [{name, evidence, description}]
--      video_insights.vibe_signals  {tag: score}
--      social_post_places.confidence_tier  high | medium | low
--
-- 2. proximity_notification_log: one row per proximity push the device sent,
--    so cooldowns and daily caps survive reinstalls and span devices.
--
-- SECURITY DEFINER so the lookups are not blocked by RLS on the social
-- tables; the caller is always auth.uid(), never a parameter.

create or replace function public.get_proximity_context()
returns table (
  location_id bigint,
  saved_method text,
  creator_handle text,
  top_dish text,
  vibe text,
  confidence_tier text,
  confirmed_by_user boolean,
  been_to boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (select auth.uid() as uid),
  saved as (
    -- One row per saved place; prefer the most recent save for its source.
    select distinct on (a.location_id)
      a.location_id,
      a.saved_method::text as saved_method,
      a.source_video_url
    from user_location_actions a, me
    where a.user_id = me.uid
      and a.action in ('save', 'shared_video')
    order by a.location_id, a.created_at desc
  )
  select
    s.location_id,
    s.saved_method,
    vi.creator_handle,
    nullif(btrim(vi.key_dishes -> 0 ->> 'name'), '') as top_dish,
    vibe.tag as vibe,
    sp.confidence_tier,
    coalesce(sp.confirmed, false) as confirmed_by_user,
    exists (
      select 1
      from user_location_actions b, me
      where b.user_id = me.uid
        and b.location_id = s.location_id
        and b.action = 'been_to'
    ) as been_to
  from saved s
  left join lateral (
    select v.creator_handle, v.key_dishes, v.vibe_signals
    from video_insights v
    where v.location_id = s.location_id
      and (s.source_video_url is null or v.source_video_url = s.source_video_url)
    order by v.extracted_at desc
    limit 1
  ) vi on s.saved_method in ('tiktok', 'instagram')
  left join lateral (
    select e.key as tag
    from jsonb_each_text(
      case when jsonb_typeof(vi.vibe_signals) = 'object'
           then vi.vibe_signals else '{}'::jsonb end
    ) e
    where e.value ~ '^[0-9]+(\.[0-9]+)?$'
    order by e.value::float8 desc
    limit 1
  ) vibe on true
  left join lateral (
    select
      p.confidence_tier,
      (r.confirmed_by_user or r.action in ('manual_added', 'corrected')) as confirmed
    from social_post_place_reviews r
    join social_post_places p on p.id = r.social_post_place_id
    join me on r.user_id = me.uid
    where p.location_id = s.location_id
    order by r.updated_at desc
    limit 1
  ) sp on s.saved_method in ('tiktok', 'instagram');
$$;

revoke execute on function public.get_proximity_context() from public, anon;
grant execute on function public.get_proximity_context() to authenticated, service_role;

-- ---------------------------------------------------------------------------

create table public.proximity_notification_log (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid(),
  location_id bigint not null references public.locations (location_id) on delete cascade,
  sent_at timestamptz not null default now()
);

create index proximity_notification_log_user_sent_idx
  on public.proximity_notification_log (user_id, sent_at desc);
create index proximity_notification_log_user_location_idx
  on public.proximity_notification_log (user_id, location_id, sent_at desc);

alter table public.proximity_notification_log enable row level security;

create policy "Users can view own proximity log"
  on public.proximity_notification_log for select to authenticated
  using (auth.uid() = user_id);
create policy "Users can insert own proximity log"
  on public.proximity_notification_log for insert to authenticated
  with check (auth.uid() = user_id);

revoke all on public.proximity_notification_log from public, anon;
grant select, insert on public.proximity_notification_log to authenticated;
grant all on public.proximity_notification_log to service_role;

-- Only the last 4 days matter (the per-place cooldown); keep a little extra.
select cron.schedule('cleanup_proximity_notification_log_daily', '30 3 * * *',
  $$DELETE FROM public.proximity_notification_log WHERE sent_at < now() - interval '14 days';$$);
