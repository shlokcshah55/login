-- A4: normalised cuisine per location, for the area-aware home rail (B1).
--
-- locations.cuisine_primary covers ~8% of rows with inconsistent casing
-- ("italian"/"Italian", "unknown"). Google `types` covers ~100% with a fixed
-- vocabulary (`indian_restaurant`, ...). cuisine_key prefers the most specific
-- Google cuisine type (lowest priority, then earliest position in `types`),
-- falling back to cuisine_primary only when it normalises to a known key.
-- Dietary/meal/format types (vegan, halal, breakfast, brunch, fast_food,
-- dessert, fine_dining, buffet, family) are deliberately not cuisines.

create table public.cuisine_type_map (
  google_type text primary key,          -- Google type without the "_restaurant" suffix
  cuisine_key text not null,
  priority    smallint not null default 1 -- 1 specific, 2 broad, 3 generic
);

comment on table public.cuisine_type_map is
  'Maps Google place types (minus "_restaurant") to locations.cuisine_key. Edit rows, then re-run public.backfill_cuisine_key().';

insert into public.cuisine_type_map (google_type, cuisine_key, priority) values
  -- South Asian
  ('indian','indian',1), ('north_indian','indian',1), ('south_indian','indian',1),
  ('pakistani','pakistani',1), ('bangladeshi','bangladeshi',1), ('sri_lankan','sri_lankan',1),
  ('afghani','afghan',1), ('tibetan','tibetan',1),
  -- East / South-East Asian
  ('chinese','chinese',1), ('cantonese','chinese',1), ('chinese_noodle','chinese',1),
  ('dim_sum','chinese',1), ('dumpling','chinese',1), ('hot_pot','chinese',1), ('taiwanese','taiwanese',1),
  ('japanese','japanese',1), ('sushi','japanese',1), ('ramen','japanese',1),
  ('japanese_izakaya','japanese',1), ('japanese_curry','japanese',1), ('yakitori','japanese',1),
  ('yakiniku','japanese',1), ('tonkatsu','japanese',1),
  ('korean','korean',1), ('korean_barbecue','korean',1),
  ('thai','thai',1), ('vietnamese','vietnamese',1), ('malaysian','malaysian',1),
  ('indonesian','indonesian',1), ('filipino','filipino',1), ('cambodian','cambodian',1),
  -- European
  ('italian','italian',1), ('pizza','pizza',1), ('french','french',1),
  ('spanish','spanish',1), ('tapas','spanish',1), ('basque','spanish',1),
  ('portuguese','portuguese',1), ('greek','greek',1), ('gyro','greek',1),
  ('german','german',1), ('bavarian','german',1), ('belgian','belgian',1),
  ('scandinavian','scandinavian',1), ('irish','irish',1),
  ('british','british',1), ('fish_and_chips','british',1),
  ('eastern_european','eastern_european',1), ('ukrainian','eastern_european',1),
  ('russian','eastern_european',1), ('croatian','eastern_european',1),
  -- Middle Eastern / African / Caribbean
  ('turkish','turkish',1), ('lebanese','lebanese',1), ('persian','persian',1),
  ('israeli','middle_eastern',1), ('middle_eastern','middle_eastern',1),
  ('falafel','middle_eastern',1), ('shawarma','middle_eastern',1), ('moroccan','moroccan',1),
  ('african','african',1), ('ethiopian','african',1),
  ('caribbean','caribbean',1), ('cuban','caribbean',1),
  -- Americas
  ('mexican','mexican',1), ('taco','mexican',1), ('burrito','mexican',1), ('tex_mex','mexican',1),
  ('brazilian','brazilian',1), ('peruvian','peruvian',1),
  ('argentinian','latin_american',1), ('colombian','latin_american',1),
  ('latin_american','latin_american',1), ('south_american','latin_american',1),
  ('american','american',2), ('hot_dog','american',1), ('californian','american',1),
  ('soul_food','american',1), ('cajun','american',1),
  ('hamburger','burgers',1), ('barbecue','barbecue',1),
  ('chicken','chicken',1), ('chicken_wings','chicken',1),
  -- Other
  ('seafood','seafood',1), ('oyster_bar','seafood',1),
  ('hawaiian','hawaiian',1), ('australian','australian',1),
  ('mediterranean','mediterranean',2),
  ('asian','asian',3), ('asian_fusion','asian',3),
  ('european','european',3), ('western','european',3), ('fusion','fusion',3);

alter table public.cuisine_type_map enable row level security;
create policy "cuisine_type_map_select_all" on public.cuisine_type_map
  for select using (true);
revoke insert, update, delete, truncate on public.cuisine_type_map from anon, authenticated;

alter table public.locations add column cuisine_key text;

create or replace function public.derive_cuisine_key(p_types text, p_cuisine_primary text)
returns text
language sql
stable
set search_path = public
as $$
  select coalesce(
    (select m.cuisine_key
       from unnest(string_to_array(p_types, ',')) with ordinality as t(google_type, pos)
       join cuisine_type_map m on m.google_type || '_restaurant' = trim(t.google_type)
      order by m.priority, t.pos
      limit 1),
    (select m.cuisine_key
       from cuisine_type_map m
      where m.cuisine_key = replace(lower(trim(p_cuisine_primary)), ' ', '_')
      limit 1)
  );
$$;

create or replace function public.trg_locations_set_cuisine_key()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.cuisine_key := derive_cuisine_key(new.types, new.cuisine_primary);
  return new;
end;
$$;

create trigger locations_set_cuisine_key_trg
  before insert or update of types, cuisine_primary on public.locations
  for each row execute function public.trg_locations_set_cuisine_key();

-- Re-derive for every row (after editing cuisine_type_map). Service role only.
create or replace function public.backfill_cuisine_key()
returns integer
language plpgsql
set search_path = public
as $$
declare
  v_updated integer;
begin
  update locations l
     set cuisine_key = derive_cuisine_key(l.types, l.cuisine_primary)
   where l.cuisine_key is distinct from derive_cuisine_key(l.types, l.cuisine_primary);
  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

revoke execute on function public.backfill_cuisine_key() from public, anon, authenticated;

select public.backfill_cuisine_key();

create index idx_locations_cuisine_key
  on public.locations (cuisine_key)
  where cuisine_key is not null;

analyze public.locations;
