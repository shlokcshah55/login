-- B1: server-ranked candidates for the home category rail.
--
-- Area cuisines use "lift" — the cuisine's share of places near the point
-- divided by its share across all keyed locations — so an area surfaces what
-- it is *known for* rather than what is common everywhere. Ranked by
-- lift * sqrt(count) (one odd restaurant can't win) and boosted by the
-- caller's own saved / been-to cuisine mix. Bubble tiles surface the caller's
-- bubbles that have places nearby (explicit bubble adds + other members' saves).
--
-- Vibe, source and eat-list tiles stay client-side (HomeCategoryBuilder).
-- The area label ("Islington") comes from client reverse geocoding (B2).
--
-- SECURITY DEFINER so bubble tiles can see other members' saves; the caller is
-- always auth.uid(), never a parameter. Only location ids leave the function.

create or replace function public.get_home_rail(
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer default 1500,
  p_limit integer default 10
)
returns table (
  kind text,              -- 'cuisine' | 'bubble'
  id text,                -- cuisine_key or bubble_id
  label text,
  score double precision, -- comparable within a kind only
  place_count integer,    -- places within the radius
  location_ids bigint[],  -- best first (rating x review volume, then distance), max 20
  reason text             -- 'area' | 'personal' | 'area+personal' | 'bubble'
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
      auth.uid() as uid
  ),
  nearby as (
    select
      l.location_id,
      l.cuisine_key,
      st_distance(l.geog, p.pt) as dist_m,
      coalesce(l.rating, 0) * ln(1 + coalesce(l.user_ratings_total, 0)) as quality
    from locations l, params p
    where st_dwithin(l.geog, p.pt, p.radius_m)
      and coalesce(l.business_status, 'OPERATIONAL') not in ('CLOSED_PERMANENTLY', 'CLOSED_TEMPORARILY')
  ),
  -- Baseline: share of each cuisine across every keyed location (~London today).
  city as (
    select cuisine_key, count(*)::float8 / sum(count(*)) over () as share
    from locations
    where cuisine_key is not null
    group by cuisine_key
  ),
  area as (
    select cuisine_key, count(*)::int as n, count(*)::float8 / sum(count(*)) over () as share
    from nearby
    where cuisine_key is not null
    group by cuisine_key
  ),
  -- Caller's taste: saves and been-tos count +1, dislikes -1, floored at 0.
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
      a.share / c.share as lift,
      coalesce(t.share, 0) as taste
    from area a
    join city c using (cuisine_key)
    left join taste t using (cuisine_key)
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
  bubble_tiles as (
    select
      mb.bubble_id,
      mb.name,
      count(*)::int as n,
      (array_agg(nb.location_id order by nb.quality desc, nb.dist_m))[1:20] as ids
    from bubble_places bp
    join nearby nb on nb.location_id = bp.location_id
    join my_bubbles mb on mb.bubble_id = bp.bubble_id
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
       from (select nb.location_id
               from nearby nb
              where nb.cuisine_key = sc.cuisine_key
              order by nb.quality desc, nb.dist_m
              limit 20) x),
    sc.reason
  from scored_cuisine sc
  union all
  select 'bubble', bt.bubble_id::text, bt.name, sqrt(bt.n), bt.n, bt.ids, 'bubble'
  from bubble_tiles bt
  order by 1 desc, 4 desc;  -- 'cuisine' before 'bubble', then score
$$;

revoke execute on function public.get_home_rail(double precision, double precision, integer, integer) from public, anon;
grant execute on function public.get_home_rail(double precision, double precision, integer, integer) to authenticated, service_role;
