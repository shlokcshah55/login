-- B1 tuning, after checking results on production data:
--
-- 1. Smoothed lift. Raw lift let rare cuisines with 3-4 places win dense areas
--    (Soho: Australian n=4 and Taiwanese n=4 outranked Japanese n=89 and
--    Italian n=110). Lift is now (n + 5) / (expected + 5), where expected is
--    the count the area would have at the baseline share. Small samples shrink
--    toward 1. Soho becomes Japanese, Italian, French, Korean.
-- 2. Speed. Cuisine tiles only scan keyed places, via a partial GiST index.
--    Bubble tiles look up their (few) places by id instead of the full radius.

create index if not exists idx_locations_geog_keyed
  on public.locations using gist (geog)
  where cuisine_key is not null;

create or replace function public.get_home_rail(
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer default 1500,
  p_limit integer default 10
)
returns table (
  kind text,
  id text,
  label text,
  score double precision,
  place_count integer,
  location_ids bigint[],
  reason text
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography as pt,
      least(greatest(coalesce(p_radius_m, 1500), 200), 10000) as radius_m,
      least(greatest(coalesce(p_limit, 10), 1), 30) as lim,
      auth.uid() as uid,
      5.0::float8 as prior_n  -- pseudo-count for lift smoothing
  ),
  keyed_nearby as (
    select
      l.location_id,
      l.cuisine_key,
      st_distance(l.geog, p.pt) as dist_m,
      coalesce(l.rating, 0) * ln(1 + coalesce(l.user_ratings_total, 0)) as quality
    from locations l, params p
    where l.cuisine_key is not null
      and st_dwithin(l.geog, p.pt, p.radius_m)
      and coalesce(l.business_status, 'OPERATIONAL') not in ('CLOSED_PERMANENTLY', 'CLOSED_TEMPORARILY')
  ),
  city as (
    select cuisine_key, count(*)::float8 / sum(count(*)) over () as share
    from locations
    where cuisine_key is not null
    group by cuisine_key
  ),
  area as (
    select cuisine_key, count(*)::int as n, sum(count(*)) over ()::float8 as total
    from keyed_nearby
    group by cuisine_key
  ),
  mine as (
    select l.cuisine_key,
           greatest(sum(case a.action when 'dislike' then -1 else 1 end), 0)::float8 as w
    from user_location_actions a
    join locations l on l.location_id = a.location_id
    join params p on a.user_id = p.uid
    where a.action in ('save', 'been_to', 'dislike')
      and l.cuisine_key is not null
    group by l.cuisine_key
  ),
  taste as (
    select cuisine_key, coalesce(w / nullif(sum(w) over (), 0), 0) as share
    from mine
  ),
  cuisine_tiles as (
    select
      a.cuisine_key,
      a.n,
      (a.n + p.prior_n) / (a.total * c.share + p.prior_n) as lift,
      coalesce(t.share, 0) as taste
    from area a
    join city c using (cuisine_key)
    left join taste t using (cuisine_key)
    cross join params p
    where a.n >= 3
  ),
  scored_cuisine as (
    select
      ct.*,
      ct.lift * sqrt(ct.n) * (1 + 2 * ct.taste) as score,
      case
        when ct.lift >= 1.3 and ct.taste >= 0.15 then 'area+personal'
        when ct.lift >= 1.3 then 'area'
        else 'personal'
      end as reason
    from cuisine_tiles ct
    where ct.lift >= 1.3 or ct.taste >= 0.15
    order by score desc
    limit (select lim from params)
  ),
  my_bubbles as (
    select b.bubble_id, b.name
    from bubble_members m
    join bubbles b on b.bubble_id = m.bubble_id
    join params p on m.user_id = p.uid
  ),
  bubble_places as (
    select mb.bubble_id, bl.location_id
    from my_bubbles mb
    join bubble_locations bl on bl.bubble_id = mb.bubble_id
    union
    select mb.bubble_id, a.location_id
    from my_bubbles mb
    join bubble_members m2 on m2.bubble_id = mb.bubble_id
    join user_location_actions a on a.user_id = m2.user_id
    join params p on m2.user_id <> p.uid
    where a.action in ('save', 'been_to')
  ),
  bubble_nearby as (
    select
      bp.bubble_id,
      l.location_id,
      st_distance(l.geog, p.pt) as dist_m,
      coalesce(l.rating, 0) * ln(1 + coalesce(l.user_ratings_total, 0)) as quality
    from bubble_places bp
    join locations l on l.location_id = bp.location_id
    cross join params p
    where st_dwithin(l.geog, p.pt, p.radius_m)
      and coalesce(l.business_status, 'OPERATIONAL') not in ('CLOSED_PERMANENTLY', 'CLOSED_TEMPORARILY')
  ),
  bubble_tiles as (
    select
      mb.bubble_id,
      mb.name,
      count(*)::int as n,
      (array_agg(bn.location_id order by bn.quality desc, bn.dist_m))[1:20] as ids
    from bubble_nearby bn
    join my_bubbles mb on mb.bubble_id = bn.bubble_id
    group by mb.bubble_id, mb.name
    having count(*) >= 2
    order by count(*) desc
    limit 3
  )
  select
    'cuisine'::text,
    sc.cuisine_key,
    initcap(replace(sc.cuisine_key, '_', ' ')),
    sc.score,
    sc.n,
    (select array_agg(x.location_id)
       from (select kn.location_id
               from keyed_nearby kn
              where kn.cuisine_key = sc.cuisine_key
              order by kn.quality desc, kn.dist_m
              limit 20) x),
    sc.reason
  from scored_cuisine sc
  union all
  select 'bubble', bt.bubble_id::text, bt.name, sqrt(bt.n), bt.n, bt.ids, 'bubble'
  from bubble_tiles bt
  order by 1 desc, 4 desc;
$$;
