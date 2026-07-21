# Social Review Multi-Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user select and confirm several restaurant candidates from one shared post without one selection clearing another.

**Architecture:** Keep selection state local to `SocialPostReviewPage` as a set of candidate IDs. Add one provider batch operation that saves each selected candidate independently, optionally adds the searched place, discards unselected candidates, and resolves the review only after the batch succeeds.

**Tech Stack:** Flutter, Provider, Supabase helpers, flutter_test.

---

### Task 1: Batch confirmation behaviour

**Files:**
- Modify: `lib/providers/social_review_provider.dart`
- Test: `test/providers/social_review_provider_multi_select_test.dart`

- [ ] **Step 1: Write the failing provider tests**

Create a recording subclass that overrides `savePlace`, `discardPlace`, and the manual-place persistence seam. Assert that `confirmPlaces` saves two selected candidates even when their names match, discards an unselected candidate, and completes the review only when all operations succeed.

```dart
final ok = await provider.confirmPlaces(
  review,
  selectedPlaces: [sameNameA, sameNameB],
);

expect(ok, isTrue);
expect(provider.savedIds, ['same-a', 'same-b']);
expect(provider.discardedIds, ['other']);
```

- [ ] **Step 2: Run the provider test and verify RED**

Run:

```bash
flutter test test/providers/social_review_provider_multi_select_test.dart
```

Expected: FAIL because `confirmPlaces` does not exist.

- [ ] **Step 3: Implement the minimal batch API**

Add:

```dart
Future<bool> confirmPlaces(
  SocialPostReviewItem item, {
  required List<SocialPostPlace> selectedPlaces,
  LocationModel? additionalPlace,
}) async
```

The method must:

1. Persist `additionalPlace` without completing the review yet.
2. Call `savePlace` for every selected candidate without grouping by name.
3. Call `discardPlace` for every candidate not selected.
4. Call `_completeReview(item, 'reviewed')` only after all operations succeed.
5. Return `false` on the first failed operation while preserving earlier successful saves.

Extract the persistence body of `addManualPlace` into a private `_persistManualPlace` helper with a `completeReview` flag so the batch controls when the review resolves. Keep the existing public `addManualPlace` behaviour unchanged.

- [ ] **Step 4: Run the provider test and verify GREEN**

Run:

```bash
flutter test test/providers/social_review_provider_multi_select_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the provider behaviour**

```bash
git add lib/providers/social_review_provider.dart test/providers/social_review_provider_multi_select_test.dart
git commit -m "feat: batch confirm social restaurants"
```

### Task 2: Multi-select candidate cards

**Files:**
- Modify: `lib/pages/social_review/social_post_review_page.dart`
- Test: `test/pages/social_review/social_post_review_page_test.dart`

- [ ] **Step 1: Write the failing widget test**

Update the recording provider to capture every candidate passed to `confirmPlaces`. Tap the first and second candidate cards and assert both remain selected, the action reads `Confirm 2 restaurants`, and both IDs are submitted.

```dart
await tester.tap(find.text('Noodle Yard'));
await tester.tap(find.text('Xi’an Corner'));

expect(find.text('Confirm 2 restaurants'), findsOneWidget);

await tester.tap(find.text('Confirm 2 restaurants'));
expect(provider.confirmedCandidateIds, ['candidate-1', 'candidate-2']);
```

- [ ] **Step 2: Run the widget test and verify RED**

Run:

```bash
flutter test test/pages/social_review/social_post_review_page_test.dart
```

Expected: FAIL because candidate taps still replace the single selection.

- [ ] **Step 3: Implement local set-based selection**

Replace `_selectedCandidateId` with:

```dart
final Set<String> _selectedCandidateIds = <String>{};
```

Preserve the current default by seeding only the first preferred candidate. Candidate taps toggle membership without clearing `_searchedPlace`. Build the selected candidate list from the ranked candidates and call `provider.confirmPlaces`.

Pass the total selected count to `_ReviewActionBar`:

```dart
final selectionCount =
    _selectedCandidateIds.length + (_searchedPlace == null ? 0 : 1);
```

Render `Confirm restaurant` for one selection and `Confirm N restaurants` for more than one.

- [ ] **Step 4: Run the page tests and verify GREEN**

Run:

```bash
flutter test test/pages/social_review/social_post_review_page_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the UI behaviour**

```bash
git add lib/pages/social_review/social_post_review_page.dart test/pages/social_review/social_post_review_page_test.dart
git commit -m "feat: multi-select social restaurant matches"
```

### Task 3: Focused regression verification

**Files:**
- Verify: `lib/pages/social_review/social_post_review_page.dart`
- Verify: `lib/providers/social_review_provider.dart`

- [ ] **Step 1: Format and analyze**

```bash
dart format lib/providers/social_review_provider.dart lib/pages/social_review/social_post_review_page.dart test/providers/social_review_provider_multi_select_test.dart test/pages/social_review/social_post_review_page_test.dart
flutter analyze lib/providers/social_review_provider.dart lib/pages/social_review/social_post_review_page.dart
```

Expected: no analysis issues.

- [ ] **Step 2: Run the social-review test suite**

```bash
flutter test test/models/social_post_review_workflow_test.dart test/pages/social_review test/providers/social_review_provider_projection_test.dart test/providers/social_review_provider_multi_select_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 3: Check and publish the branch**

```bash
git diff --check
git status -sb
git push
```

Expected: clean diff checks and the feature branch updated on GitHub.
