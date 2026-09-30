-- A4: lookup indexes on foreign-key / filter columns that only had sequential
-- scans or were covered by a composite index with a different leading column.

create index if not exists idx_user_location_actions_location_id
  on public.user_location_actions (location_id);

create index if not exists idx_collection_locations_location_id
  on public.collection_locations (location_id);

create index if not exists idx_location_reviews_location_id
  on public.location_reviews (location_id);

create index if not exists idx_location_reviews_user_id
  on public.location_reviews (user_id);

create index if not exists idx_collections_created_by
  on public.collections (created_by);

-- RLS subqueries on bubbles/messages filter bubble_members by user_id.
create index if not exists idx_bubble_members_user_id
  on public.bubble_members (user_id);

-- PK is (followee_id, follower_id); "who do I follow" lookups need follower first.
create index if not exists idx_user_friends_follower_id
  on public.user_friends (follower_id);

-- Usernames are case-insensitively unique (0 conflicts in production on 2026-09-30).
create unique index if not exists users_username_lower_key
  on public.users (lower(username));

-- pg_stat showed ~85 live rows for locations (actual: ~42k); refresh stats.
analyze public.locations;
analyze public.user_location_actions;
analyze public.collection_locations;
analyze public.users;
