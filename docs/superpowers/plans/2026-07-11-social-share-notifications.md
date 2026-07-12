# Social Share Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the incorrect persistent Review shares prompt and replace it with deduplicated in-app TikTok/Reel result signals backed by the Profile notification history.

**Architecture:** Keep Supabase `notifications` as the history source, enrich `SocialPostReviewNotification` with an explicit saved/needs-checking/failed outcome, and use a small presentation controller plus per-user SharedPreferences store to prevent replay. A root `SocialShareSignalHost` scans startup, resume, realtime, and foreground updates and renders one aggregated Pinit card; the Profile feed groups history by date and supports persisted dismissal.

**Tech Stack:** Flutter, Dart, Provider, Firebase Messaging, Supabase, SharedPreferences, Python social processor, `flutter_test`, Pinit Rova/DM Sans tokens.

---

### Task 1: Align Home attention state

**Files:**
- Modify: `lib/providers/social_review_provider.dart`
- Modify: `lib/pages/home_page.dart`
- Test: `test/providers/social_review_provider_projection_test.dart`

- [ ] Add a failing test proving a successful pending post has zero `needsCheckingCount` while a low-confidence pending candidate increments it.
- [ ] Run `flutter test test/providers/social_review_provider_projection_test.dart` and confirm RED because the getter does not exist.
- [ ] Add `needsCheckingCount` from projected place items and remove the obsolete Home `SocialReviewPill` block/imports because the root signal host replaces it.
- [ ] Re-run the provider test and confirm GREEN.

### Task 2: Make social notification outcomes explicit

**Files:**
- Modify: `lib/models/notifications/social_post_review_notification.dart`
- Modify: `api/social-free-processor/notifications.py`
- Test: `test/models/social_post_review_notification_test.dart`
- Test: `api/social-free-processor/test_notifications.py`

- [ ] Add failing Dart tests for saved, needs-checking, and failed parsing, platform-specific copy, saved count/name metadata, and contextual action labels.
- [ ] Add failing Python tests for explicit `outcome`, `savedCount`, and `firstPlaceName` payload metadata.
- [ ] Implement the model and processor payload changes with backwards-compatible outcome derivation.
- [ ] Run both focused suites and confirm GREEN.

### Task 3: Deduplicated presentation selection and storage

**Files:**
- Create: `lib/services/social_share_signal_controller.dart`
- Create: `lib/services/social_share_presentation_store.dart`
- Test: `test/services/social_share_signal_controller_test.dart`
- Test: `test/services/social_share_presentation_store_test.dart`

- [ ] Add failing tests that aggregate multiple successful notifications, prioritise one attention item, exclude already-presented IDs, and persist presented IDs per user.
- [ ] Implement immutable `SocialShareSignal`, pure selection, and a bounded SharedPreferences store.
- [ ] Run the focused tests and confirm GREEN.

### Task 4: Root in-app signal host

**Files:**
- Create: `lib/widgets/social_share_signal_host.dart`
- Modify: `lib/app/app_root.dart`
- Modify: `lib/pages/social_review/social_review_inbox_page.dart`
- Test: `test/widgets/social_share_signal_host_test.dart`
- Modify: `test/pages/social_review/social_review_inbox_page_test.dart`

- [ ] Add failing widget tests for success rendering, aggregation, swipe dismissal, six-second auto-dismiss, persistent attention state, and tap routing callback.
- [ ] Add a failing inbox test for an explicit initial filter.
- [ ] Implement a lifecycle-aware root host around the navigator child, scanning startup/resume/notification stream updates and marking signals presented before display.
- [ ] Route saved signals to `Recently saved` and attention signals to `Needs checking`; successful auto-dismiss marks the associated Profile notifications read.
- [ ] Run the focused widget tests and confirm GREEN.

### Task 5: Robust notification persistence and Profile history

**Files:**
- Create: `supabase/migrations/20260711130000_add_notification_dismissal.sql`
- Modify: `lib/supabase/helpers/notifications.dart`
- Modify: `lib/services/fcm_service.dart`
- Modify: `lib/widgets/profile/notifications_popover.dart`
- Test: `test/widgets/profile/notifications_popover_grouping_test.dart`

- [ ] Add failing tests for Today/Yesterday/date buckets and social outcome labels.
- [ ] Add `dismissed_at`, filter dismissed rows, and expose `dismissNotification` through FCMService.
- [ ] Stop foreground handling from re-inserting a notification already persisted by the push service; refresh and emit the canonical row instead.
- [ ] Render date-pill grouping, circular status artwork, outcome accents, and swipe-to-dismiss with undo in Profile.
- [ ] Run focused notification tests and confirm GREEN.

### Task 6: Verification

**Files:** all files above plus the existing focused inbox tests.

- [ ] Format all changed Dart and Python files.
- [ ] Run scoped Dart analysis and Python syntax/tests.
- [ ] Run the social notification, inbox, provider, signal host/controller/store, Profile grouping, expanded-card, and carousel-card test suites.
- [ ] Run `git diff --check` and inspect `git status --short`, preserving the uncommitted inbox redesign and unrelated user changes.
