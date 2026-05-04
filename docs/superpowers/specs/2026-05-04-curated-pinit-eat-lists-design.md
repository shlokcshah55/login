# Curated Pinit Eat-Lists (Read-Only) + Wizard Adoption

Date: 2026-05-04

## Goal

Create a set of Pinit-owned curated eat-lists that new users can adopt into their eat-lists library during signup. Curated lists must be searchable in the wizard. Curated lists are read-only once adopted.

Also: assess and improve the current state of eat-lists around sharing and removing locations.

## Non-Goals

- Building share-links or a public web page for eat-lists.
- Allowing edits to Pinit curated lists by adopters (no cloning, no per-user copies).
- Full text search across all collections in the app (only the curated picker in wizard is in scope).

## Current State (As Implemented)

- Eat-lists are `collections` + `collection_locations`.
- Users can "adopt" other users' public collections via `collection_saves`.
- Adopted collections appear in the user's collection library with `canEdit = false`.
- Adding a location to a collection is already enforced as read-only for non-owners via `add_location_to_collection`.
- Sharing is currently "visibility" based: `collections.is_public` gates discoverability in friend/profile contexts; there is no share link UI.
- Users can delete their own collections, but cannot delete system collections ("Been To", "Shared Finds").
- Users cannot currently remove a single location from a collection in the UI.

## Requirements

1. Seed 8 curated Pinit collections:
   - Date Night
   - Cheap Eats
   - Vegetarian & Vegan
   - Splurge / Special Occasion
   - Group Dining / Big Night Out
   - Hidden Gems / Under the Radar
   - Comfort Food / Casual Classics
   - Crowd Favourites / The London Essentials

2. Ensure locations exist in DB before linking them to curated collections.
   - Use `api/process-locations` (venv python) to resolve names and ingest into the `locations` table.

3. Wizard step:
   - Show curated lists with a search box that filters by list name.
   - Allow adopting/unadopting via `save_collection` / `unsave_collection`.
   - Curated lists remain read-only for adopters.

4. Eat-list mutation:
   - Allow removing a location from an owned eat-list (collection owner only).
   - Do not allow removing locations from saved/adopted read-only lists.

## Data Model

Reuses existing schema:

- `collections` fields used:
  - `collection_id` (UUID, stable, referenced by app)
  - `created_by` (UUID of a Pinit-owned user row)
  - `is_curated = true`
  - `is_public = true`
  - `name`, `emoji`, `photo`/`cover_color` optional

- `collection_saves`:
  - Drives "adoption" into a user's collection library.

- `collection_locations`:
  - Holds the set of locations for curated collections.

## Backend Changes

1. Seed curated collections:
   - Add a migration that inserts the curated collections with stable UUIDs.
   - Ensure a "Pinit" user row exists (stable UUID) so owner fields resolve in RPCs.

2. Remove location from collection:
   - Add RPC `remove_location_from_collection(p_collection_id uuid, p_location_id bigint) -> jsonb`.
   - Enforce owner-only deletion.

3. Location linking (operational script):
   - Provide a python script that:
     - Ensures curated collections exist (idempotent upsert).
     - For each restaurant name:
       - Resolve ingest via the existing Google Places + recommendations API path.
       - Insert `(collection_id, location_id, added_by)` into `collection_locations` (idempotent).

## App/UI Changes

1. Signup wizard:
   - Add a dedicated curated eat-list adoption step.
   - Fetch curated collections by stable IDs using existing `get_collections_by_ids`.
   - Provide search-as-you-type filter.
   - Tapping a curated list toggles adoption (save/unsave).
   - "Finish" completes signup wizard and routes into the app.

2. Eat-list detail:
   - In the collection detail sheet, show a remove control per location when:
     - `collection.canEdit == true`
   - Removing calls the new RPC and updates the local list optimistically.

## Error Handling

- Wizard adoption:
  - Failures surface a small error toast/popover; keep the user in the wizard.
- Removing a location:
  - If the RPC fails, revert the optimistic removal and show an error.

## Testing Strategy

- Dart unit/widget tests:
  - Add tests for curated list filtering (search) and toggle semantics (save/unsave calls can be mocked at helper level).
  - Add tests for the new remove-from-collection behavior in the detail sheet (logic-only; UI snapshot if existing patterns support it).
- SQL:
  - Keep migration + RPCs idempotent; safety via `ON CONFLICT DO NOTHING` / guarded deletes.

## Open Questions

- Should curated lists be shown to all geographies or gated by city/locale? (Assume global for now; lists are London-based.)
- Should the wizard step be skippable? (Assume yes; adopting is optional.)

