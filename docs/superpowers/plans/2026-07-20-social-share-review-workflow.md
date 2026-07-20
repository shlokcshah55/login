# Social Share Review Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the restaurant-first social inbox with a post-first, state-aware inbox and context-rich restaurant confirmation screen backed by the real processor and Supabase records.

**Architecture:** Extend the existing four-table social review model with persisted post metadata and explicit user-confirmation provenance. Centralise the five workflow states in `SocialPostReviewItem`, batch-hydrate location context in `SocialReviewProvider`, render one card per shared post, and make `SocialPostReviewPage` the canonical candidate/search/confirm interaction.

**Tech Stack:** Flutter/Dart, Provider, Supabase/Postgres/RLS/Realtime, Python Flask processor, Google Places, `flutter_test`, Python `unittest`, Pinit UI tokens.

---

## File map

- `supabase/migrations/<generated>_complete_social_share_review_flow.sql` — caption/thumbnail persistence, user-confirmation provenance, and corrected update policies.
- `api/social-free-processor/pipeline.py` — fallback variable fix and metadata retention.
- `api/social-free-processor/supabase_store.py` — post metadata serialization and high-only auto-save predicate.
- `api/social-free-processor/main.py` — persist all available metadata and use high-only auto-save.
- `api/social-free-processor/test_pipeline.py` — transcript/frame regression and failure-metadata coverage.
- `api/social-free-processor/test_supabase_store.py` — metadata and auto-save policy coverage.
- `lib/models/social_review_models.dart` — complete post/candidate/action parsing and derived workflow state.
- `lib/supabase/helpers/social_reviews.dart` — fetch complete review history/context and confirmation provenance.
- `lib/providers/social_review_provider.dart` — batch location map plus confirm/correct/manual/dismiss transitions.
- `lib/pages/social_review/social_review_place_item.dart` — replace place-row filtering with post-first filtering/search support while retaining compatibility projection where needed.
- `lib/pages/social_review/social_review_inbox_page.dart` — post-first filters, cards, state copy, and route handling.
- `lib/pages/social_review/widgets/social_place_search_sheet.dart` — reusable embedded search panel plus compatibility sheet wrapper.
- `lib/pages/social_review/social_post_review_page.dart` — canonical full-screen review interaction.
- `test/models/social_post_review_workflow_test.dart` — state and metadata parsing.
- `test/providers/social_review_provider_projection_test.dart` — hydration and mutation transitions.
- `test/pages/social_review/social_review_place_item_test.dart` — post filtering and search.
- `test/pages/social_review/social_review_inbox_page_test.dart` — informative post cards and filters.
- `test/pages/social_review/social_post_review_page_test.dart` — ranked candidate/search/confirm/dismiss UI.

### Task 1: Database contract

- [ ] **Step 1: Create the migration through the Supabase CLI**

Run:

```bash
supabase --help
supabase migration --help
supabase migration new complete_social_share_review_flow
```

Expected: one timestamped migration file is created.

- [ ] **Step 2: Add the schema and policy changes**

The migration must add:

```sql
alter table public.social_posts
  add column if not exists caption text,
  add column if not exists thumbnail_url text;

alter table public.social_post_place_reviews
  add column if not exists confirmed_by_user boolean not null default false;

update public.social_post_place_reviews
set confirmed_by_user = true
where action in ('corrected', 'manual_added', 'discarded');
```

Recreate the two authenticated update policies with both ownership predicates:

```sql
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id)
```

- [ ] **Step 3: Verify the migration statically**

Run:

```bash
supabase migration list --local
git diff --check -- supabase/migrations
```

Expected: the new migration is listed and has no whitespace errors.

### Task 2: Processor regression and metadata persistence

- [ ] **Step 1: Write failing processor tests**

Add tests proving:

```python
def test_transcript_fallback_reuses_thumbnail_ocr_text(): ...
def test_frame_fallback_combines_thumbnail_and_frame_ocr(): ...
def test_failure_retains_metadata(): ...
def test_only_high_confidence_places_auto_save(): ...
def test_post_metadata_fields_include_caption_and_thumbnail(): ...
```

The first two must drive `process_url()` through the exact fallback paths that currently raise `NameError`.

- [ ] **Step 2: Verify RED**

Run:

```bash
api/social-free-processor/venv/bin/python -m unittest \
  api/social-free-processor/test_pipeline.py \
  api/social-free-processor/test_supabase_store.py
```

Expected: failures mention the missing fallback variable behaviour, absent retained metadata, and absent helper APIs.

- [ ] **Step 3: Implement the minimal processor changes**

Use `thumb_ocr_text` consistently in transcript and frame extraction. Initialise `meta` before the `try` and return it with failed `PipelineResult`s. Add:

```python
def post_metadata_fields(meta: URLMetadata | None) -> dict:
    if meta is None:
        return {}
    return {
        "creator_handle": meta.creator_handle or None,
        "title": meta.title or None,
        "caption": meta.description or meta.title or None,
        "thumbnail_url": meta.thumbnail_url or None,
    }

def should_auto_save_place(place: dict) -> bool:
    return bool(place.get("location_id")) and place.get("confidence_tier") == "high"
```

Use those helpers from `main.py`; processor-created place actions explicitly set `confirmed_by_user = false`.

- [ ] **Step 4: Verify GREEN**

Run the focused Python command again, then:

```bash
api/social-free-processor/venv/bin/python -m unittest discover \
  -s api/social-free-processor -p 'test_*.py'
```

Expected: all processor tests pass.

### Task 3: Complete Flutter domain model

- [ ] **Step 1: Write failing model tests**

Cover:

- caption, thumbnail, evidence flags, safe error presence, post timestamps;
- per-place `confirmed_by_user`;
- active processing versus stale processing;
- failed, needs-checking, resolved, and dismissed states;
- medium auto-saved candidate still requiring confirmation;
- high auto-saved candidate resolving automatically;
- missing caption/creator/thumbnail fallbacks.

- [ ] **Step 2: Verify RED**

Run:

```bash
flutter test test/models/social_post_review_workflow_test.dart
```

Expected: compilation/assertion failures for the new fields and state API.

- [ ] **Step 3: Implement the model**

Add:

```dart
enum SocialPostWorkflowState {
  processing,
  needsChecking,
  failed,
  resolved,
  dismissed,
}
```

Store `caption`, `thumbnailUrl`, `evidenceFlags`, `processingError`, `postUpdatedAt`, `processedAt`, and `userConfirmedPlaceIds`. Add deterministic `workflowStateAt(DateTime now)`, `pendingReviewPlaces`, `summaryText`, `statusExplanation`, and safe insight accessors.

- [ ] **Step 4: Verify GREEN**

Run the focused model test and the existing social model tests.

### Task 4: Supabase fetch and provider transitions

- [ ] **Step 1: Write failing provider/helper contract tests**

Assert that:

- dismissed rows remain in history;
- one batch location load hydrates all unique candidate IDs;
- a processor-saved medium candidate remains pending;
- confirming it records user confirmation and resolves the review;
- manual add completes an empty/failed review;
- dismissal removes the post from actionable filters but retains it in all-history after refresh.

- [ ] **Step 2: Verify RED**

Run:

```bash
flutter test test/providers/social_review_provider_projection_test.dart
```

- [ ] **Step 3: Implement query and provider changes**

Fetch all four review statuses and all new post/action fields. Expose `Map<int, LocationModel> locationsById`. Make app-originated actions write `confirmed_by_user: true`.

Add `confirmPlace()` that confirms the selected candidate and discards only alternatives sharing the same normalised extracted candidate name. Change completion checks to use `pendingReviewPlaces`. Manual add must mark the review `reviewed`.

- [ ] **Step 4: Verify GREEN**

Run the provider tests plus `test/models/social_post_review_workflow_test.dart`.

### Task 5: Post-first projection and search

- [ ] **Step 1: Write failing pure filtering tests**

Define filters:

```dart
enum SocialReviewInboxFilter {
  needsChecking,
  processing,
  recentlySaved,
  all,
}
```

Assert one result per post and search matching creator, caption, candidate, area, dish, vibe, hydrated cuisine, and hydrated location name.

- [ ] **Step 2: Verify RED**

Run:

```bash
flutter test test/pages/social_review/social_review_place_item_test.dart
```

- [ ] **Step 3: Implement the pure post projection**

Create `SocialReviewPostItem` with `review`, hydrated locations, state, insight chips, best candidate, status copy, and query matching. Keep any legacy place projection private or compatibility-only.

- [ ] **Step 4: Verify GREEN**

Run the focused filtering test.

### Task 6: Post-first inbox UI

- [ ] **Step 1: Write failing widget tests**

Pump fixtures for all five states and assert:

- creator/caption/platform/status/explanation/candidate/insights are visible when available;
- missing fields use quiet fallbacks without the generic card replacing real context;
- red borders/shadows are absent;
- processing has no dismiss action;
- failed/uncertain cards expose review/find and dismiss;
- dismissed appears only in `All`;
- card tap opens `SocialPostReviewPage`;
- open-post action is disabled when URL is missing.

- [ ] **Step 2: Verify RED**

Run:

```bash
flutter test test/pages/social_review/social_review_inbox_page_test.dart
```

- [ ] **Step 3: Implement the inbox**

Replace restaurant rows with neutral post cards using Pinit colours, restrained status tint, optional thumbnail, platform fallback artwork, press-scale motion, compact insight chips, and explicit state actions. Preserve local filter/query state across provider refreshes.

- [ ] **Step 4: Verify GREEN**

Run the inbox test and inspect for overflow warnings.

### Task 7: Embedded search and rich review screen

- [ ] **Step 1: Write failing review-screen tests**

Assert the screen includes:

- creator and original-post action;
- extracted status explanation and insight section;
- ranked candidate rows with confidence;
- restaurant search field and selectable result;
- disabled primary action before selection;
- `Confirm restaurant` and `Dismiss post`;
- callback transitions for suggested, corrected, manual, resolved, processing, and failed states.

- [ ] **Step 2: Verify RED**

Run:

```bash
flutter test test/pages/social_review/social_post_review_page_test.dart
```

- [ ] **Step 3: Extract reusable embedded search**

Turn the search sheet’s result logic into `SocialPlaceSearchPanel` with an injectable search callback and selection callback. Keep `SocialPlaceSearchSheet.show()` as a wrapper for existing callers.

- [ ] **Step 4: Implement the canonical review screen**

Use a scrollable post/context/candidate/search body and sticky bottom actions. Preserve selection on mutation failure. Confirm existing candidates through `confirmPlace`, corrections through `correctPlace`, and empty-post choices through `addManualPlace`.

- [ ] **Step 5: Verify GREEN**

Run review-page, inbox, provider, and search tests.

### Task 8: Documentation, analysis, and full verification

- [ ] **Step 1: Verify current Supabase guidance**

Fetch the Supabase changelog index and the official RLS/Data API guidance relevant to the migration. Confirm no recent breaking change affects the SQL or Flutter query.

- [ ] **Step 2: Format scoped files**

Run `dart format` for modified Dart/test files and the Python formatter already used by the project if configured.

- [ ] **Step 3: Run focused verification**

```bash
flutter test \
  test/models/social_post_review_workflow_test.dart \
  test/models/social_video_post_test.dart \
  test/pages/social_review \
  test/providers/social_review_provider_projection_test.dart \
  test/widgets/social_share_signal_host_test.dart
```

- [ ] **Step 4: Run static analysis**

```bash
flutter analyze \
  lib/models/social_review_models.dart \
  lib/supabase/helpers/social_reviews.dart \
  lib/providers/social_review_provider.dart \
  lib/pages/social_review \
  test/models/social_post_review_workflow_test.dart \
  test/pages/social_review \
  test/providers/social_review_provider_projection_test.dart
```

- [ ] **Step 5: Run database checks**

Run Supabase security and performance advisors. Do not auto-remediate unrelated findings; report them separately.

- [ ] **Step 6: Inspect final scope**

```bash
git diff --check
git status --short
git diff --stat
```

Expected: the pre-existing `ios/Runner/Base.lproj/Main.storyboard` change remains untouched.
