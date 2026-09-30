begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(13);

-- ---------------------------------------------------------------------------
-- Fixtures. cuisine_key is set by locations_set_cuisine_key_trg from `types`.
--   Baseline cluster (far away): 20 each italian / indian / pizza / chinese / korean
--   "Islington" (51.536, -0.103): 10 italian, 3 indian, 5 pizza, 3 korean
--   "East Ham"  (51.539,  0.052): 10 indian, 2 italian, 5 pizza
-- ---------------------------------------------------------------------------
insert into locations (location_id, name, lat, lng, types, rating, user_ratings_total)
select 990000 + row_number() over (), 'fixture', lat, lng, t || '_restaurant,restaurant', 4.0 + (g % 10) / 10.0, 50 + g
from (
  select 51.45 + g * 0.0001 as lat, -0.20 as lng, t, g
    from unnest(array['italian','indian','pizza','chinese','korean']) t, generate_series(1, 20) g
  union all
  select 51.536 + g * 0.0001, -0.103, t, g
    from (values ('italian', 10), ('indian', 3), ('pizza', 5), ('korean', 3)) v(t, n), generate_series(1, n) g
  union all
  select 51.539 + g * 0.0001, 0.052, t, g
    from (values ('indian', 10), ('italian', 2), ('pizza', 5)) v(t, n), generate_series(1, n) g
) s;

-- A permanently closed Italian next to Islington must be ignored.
insert into locations (location_id, name, lat, lng, types, business_status)
values (999999, 'closed', 51.5361, -0.1031, 'italian_restaurant', 'CLOSED_PERMANENTLY');

insert into users (supabase_id, username, name, email) values
  ('00000000-0000-0000-0000-00000000000a', 'rail_me', 'Me', 'rail_me@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'rail_friend', 'Friend', 'rail_friend@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'rail_stranger', 'Stranger', 'rail_stranger@test.local');

-- Me: loves Korean (two saves in the baseline cluster).
insert into user_location_actions (user_id, location_id, action)
select '00000000-0000-0000-0000-00000000000a', location_id, 'save'
from locations where cuisine_key = 'korean' and lat < 51.5 order by location_id limit 2;

-- Bubble with a friend who saved two Islington places.
insert into bubbles (bubble_id, name, created_by, is_private)
values ('00000000-0000-0000-0000-0000000000b1', 'Sunday Crew', '00000000-0000-0000-0000-00000000000a', true);
insert into bubble_members (bubble_id, user_id) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000b');
insert into user_location_actions (user_id, location_id, action)
select '00000000-0000-0000-0000-00000000000b', location_id, 'save'
from locations where lat between 51.536 and 51.537 and lng = -0.103 and cuisine_key = 'pizza' order by location_id limit 2;

-- Stranger's bubble with Islington places: must never leak to me.
insert into bubbles (bubble_id, name, created_by, is_private)
values ('00000000-0000-0000-0000-0000000000b2', 'Not Mine', '00000000-0000-0000-0000-00000000000c', true);
insert into bubble_members (bubble_id, user_id)
values ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000000c');
insert into bubble_locations (bubble_id, location_id, added_by)
select '00000000-0000-0000-0000-0000000000b2', location_id, '00000000-0000-0000-0000-00000000000c'
from locations where lat between 51.536 and 51.537 and lng = -0.103 order by location_id limit 3;

-- ---------------------------------------------------------------------------
-- Area lift (as the service role: no caller, so no taste or bubbles)
-- ---------------------------------------------------------------------------
select is(
  (select id from get_home_rail(51.536, -0.103) where kind = 'cuisine' order by score desc limit 1),
  'italian', 'Islington: Italian has the highest area lift');

select is(
  (select id from get_home_rail(51.539, 0.052) where kind = 'cuisine' order by score desc limit 1),
  'indian', 'East Ham: Indian has the highest area lift');

select ok(
  not exists (select 1 from get_home_rail(51.536, -0.103) where id = 'pizza'),
  'Pizza (share ~= baseline) is not an area tile');

select is(
  (select place_count from get_home_rail(51.536, -0.103) where id = 'italian'),
  10, 'Permanently closed places are excluded from counts');

select ok(
  not (select location_ids @> array[999999::bigint] from get_home_rail(51.536, -0.103) where id = 'italian'),
  'Permanently closed places are excluded from location_ids');

select is(
  (select reason from get_home_rail(51.536, -0.103) where id = 'italian'),
  'area', 'Area-only tile is labelled area');

select ok(
  not exists (select 1 from get_home_rail(51.536, -0.103) where id = 'korean'),
  'Korean (lift ~0.86) is not an area tile without taste');

-- ---------------------------------------------------------------------------
-- As "me" (authenticated)
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select is(
  (select reason from get_home_rail(51.536, -0.103) where id = 'korean'),
  'personal', 'My Korean taste surfaces Korean nearby even without area lift');

select is(
  (select reason from get_home_rail(51.536, -0.103) where id = 'italian'),
  'area', 'Italian stays an area tile for me (I have no Italian saves)');

select is(
  (select place_count from get_home_rail(51.536, -0.103) where kind = 'bubble' and label = 'Sunday Crew'),
  2, 'My bubble shows the friend''s nearby saves');

select ok(
  not exists (select 1 from get_home_rail(51.536, -0.103) where kind = 'bubble' and label = 'Not Mine'),
  'A bubble I am not in never appears');

select is(
  (select count(*)::int from get_home_rail(51.539, 0.052) where kind = 'bubble'),
  0, 'Bubbles with fewer than 2 nearby places are omitted');

reset role;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
select ok(
  not has_function_privilege('anon', 'public.get_home_rail(double precision, double precision, integer, integer)', 'EXECUTE'),
  'anon cannot call get_home_rail');

select * from finish();
rollback;
