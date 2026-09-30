-- Drop locations columns that nothing reads (audit 2026-10-01 across login
-- lib/ + api/, ai/ on tiktok-refactor, and pinit-recommendations):
--
--   saved_count                  0% filled; only read by the dead RPCs below
--   photo_reference_valid_until  0% filled
--   photo_source                 0% filled
--   photo_reference_score        2%; written by a backfill script, never read
--   is_takeaway                  1.5%, only ever true, never read
--   ingested_at                  duplicate of created_at
--   data_version                 ingestion provenance, never read
--   derived_attributes           ingestion tile metadata (10 MB, mostly
--                                double-encoded JSON strings), never read
--   cuisine_detected / cuisine_source   superseded by cuisine_primary / cuisine_key
--   price_bucket                 derivable from price_level
--   is_open_late / is_open_early / is_sunday_open  derivable from opening_hours_periods
--
-- Kept on purpose: cuisine_scores_json (still written by the cuisine
-- classifier and menu processing).
--
-- The client parses these in LocationModel.fromJson null-safely, so existing
-- app builds are unaffected. Writers were removed from pinit-recommendations
-- scripts first (stage_a_discover, backfill_photo_waterfall).
--
-- These functions read the dropped columns and have no callers in any repo
-- (the live paths are get_locations_with_pillars / get_fill_locations /
-- refresh_location_quality_scores / get_home_rail), so they go too rather
-- than being left broken.

drop function if exists public.get_ranked_proximal_recommendations(
  uuid, double precision, double precision, double precision,
  double precision, double precision, double precision, integer);
drop function if exists public.search_locations(text, integer, double precision, double precision);
drop function if exists public.compute_location_quality_score(bigint);

alter table public.locations
  drop column if exists saved_count,
  drop column if exists photo_reference_valid_until,
  drop column if exists photo_source,
  drop column if exists photo_reference_score,
  drop column if exists is_takeaway,
  drop column if exists ingested_at,
  drop column if exists data_version,
  drop column if exists derived_attributes,
  drop column if exists cuisine_detected,
  drop column if exists cuisine_source,
  drop column if exists price_bucket,
  drop column if exists is_open_late,
  drop column if exists is_open_early,
  drop column if exists is_sunday_open;
