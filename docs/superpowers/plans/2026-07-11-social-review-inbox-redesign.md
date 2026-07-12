# Social Review Inbox Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the post-centric social review inbox with a searchable, restaurant-first Pinit list whose resolved items open the normal expanded card with social-video insights and match-confidence context.

**Architecture:** Add a pure projection model that flattens social posts into searchable place rows, batch-hydrate their `LocationModel`s in `SocialReviewProvider`, and render them through a reusable carousel-style `LocationListCard`. Pass optional `SocialReviewContext` into `ExpandedLocationCard` so review metadata and actions appear beside the existing TikTok/Reel insight content without affecting other expanded-card callers.

**Tech Stack:** Flutter, Dart, Provider, Supabase, `flutter_test`, cached_network_image, Pinit Rova/DM Sans typography and colour tokens.

---

### Task 1: Restaurant-first projection and filtering

**Files:**
- Create: `lib/pages/social_review/social_review_place_item.dart`
- Test: `test/pages/social_review/social_review_place_item_test.dart`

- [ ] **Step 1: Write failing tests for flattening, attention state, saved state, and search tokens**

Construct `SocialPostReviewItem` fixtures with high-, low-, failed-, and manually saved candidates. Assert `SocialReviewPlaceItem.fromReviews()` returns one row per place plus one fallback row for an empty failed post. Assert `needsChecking`, `recentlySaved`, `statusLabel`, `resolvedLocationId`, and `matchesQuery()` for restaurant name, address, creator, title, and dish name.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/pages/social_review/social_review_place_item_test.dart`

Expected: compilation fails because `SocialReviewPlaceItem` and `SocialReviewInboxFilter` do not exist.

- [ ] **Step 3: Implement the pure projection model**

Create immutable `SocialReviewPlaceItem` with source review/post, optional place, optional hydrated location, derived outcome, search tokens, and `copyWith(location:)`. Define `SocialReviewInboxFilter { needsChecking, recentlySaved, all }` and a pure `visibleSocialReviewPlaces(items, filter, query)` helper.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `flutter test test/pages/social_review/social_review_place_item_test.dart`

Expected: all projection and search tests pass.

### Task 2: Batch hydration and completed-review visibility

**Files:**
- Modify: `lib/supabase/helpers/social_reviews.dart`
- Modify: `lib/providers/social_review_provider.dart`
- Test: `test/providers/social_review_provider_projection_test.dart`

- [ ] **Step 1: Write failing provider tests**

Inject a fake review loader and fake batch location loader. Assert one batch request receives unique resolved IDs, hydrated rows are exposed through `placeItems`, and refresh preserves the query-independent projection contract. Assert pending count still excludes reviewed history.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/providers/social_review_provider_projection_test.dart`

Expected: provider construction and `placeItems` assertions fail because dependencies and projection state are not yet exposed.

- [ ] **Step 3: Implement injectable loaders and batch hydration**

Allow `SocialReviewProvider` to receive optional helper dependencies, call one `LocationHelper.getLocationsByIds()` request after fetching reviews, map locations by ID, and expose `placeItems`. Update `fetchReviewItems()` to include `reviewed` rows while continuing to exclude `dismissed`; `pendingItems` and `pendingCount` remain status-specific.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `flutter test test/providers/social_review_provider_projection_test.dart`

Expected: hydration, completed-history, and pending-count tests pass.

### Task 3: Reusable carousel-style location card

**Files:**
- Create: `lib/widgets/home/location_list_card.dart`
- Modify: `lib/pages/home/carousel_list_page.dart`
- Test: `test/widgets/home/location_list_card_test.dart`
- Modify: `test/pages/home/carousel_list_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Pump `LocationListCard` with a restaurant fixture and assert name, cuisine/summary, status overlay, and tap callback. Update the carousel page test to assert it renders `LocationListCard` instances.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `flutter test test/widgets/home/location_list_card_test.dart test/pages/home/carousel_list_page_test.dart`

Expected: compilation fails because the public reusable card does not exist.

- [ ] **Step 3: Extract the existing card without visual drift**

Move the current `_ListCard` and its card-only helper widgets/functions into `LocationListCard`. Give it `location`, optional `onTap`, optional `statusLabel`, optional `statusIcon`, optional `sourceLabel`, and optional `borderColor`; preserve the existing default expanded-card navigation. Replace `_ListCard` calls in `CarouselListPage`.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run: `flutter test test/widgets/home/location_list_card_test.dart test/pages/home/carousel_list_page_test.dart`

Expected: reusable-card and existing carousel sorting tests pass.

### Task 4: Match-confidence section for the expanded card

**Files:**
- Create: `lib/widgets/home/expanded_card/social_review_context.dart`
- Create: `lib/widgets/home/expanded_card/sections/social_match_section.dart`
- Modify: `lib/widgets/home/expanded_location_card.dart`
- Test: `test/widgets/home/expanded_card/sections/social_match_section_test.dart`
- Modify: `test/widgets/home/expanded_location_card_config_test.dart`

- [ ] **Step 1: Write failing section and configuration tests**

Assert numeric confidence renders `92%` and `Strong match`, tier-only confidence renders a label without a percentage, Instagram uses `Reel match`, and action callbacks render only when supplied. Assert `ExpandedLocationCard.socialReviewContext` defaults to null and accepts the new context.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `flutter test test/widgets/home/expanded_card/sections/social_match_section_test.dart test/widgets/home/expanded_location_card_config_test.dart`

Expected: missing context/section types cause compilation failure.

- [ ] **Step 3: Implement context and section**

Define `SocialReviewContext` with platform, place name, confidence score/tier, state, and optional confirm/correct/remove callbacks. Render `SocialMatchSection` immediately before existing TikTok/Reel insights in `_buildRestaurantBody`; omit only when no context is provided.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run: `flutter test test/widgets/home/expanded_card/sections/social_match_section_test.dart test/widgets/home/expanded_location_card_config_test.dart`

Expected: all confidence and backwards-compatibility tests pass.

### Task 5: Searchable restaurant-first inbox UI

**Files:**
- Replace: `lib/pages/social_review/social_review_inbox_page.dart`
- Test: `test/pages/social_review/social_review_inbox_page_test.dart`

- [ ] **Step 1: Write failing inbox widget tests**

Pump the page with an injected/provider-backed place list. Assert Rova `Shared saves` header, DM Sans `Search restaurants` field, three filters, attention-first default, local filtering, carousel-style resolved cards, fallback unresolved card, and empty-state copy. Tap a resolved card and assert an `ExpandedLocationCard` carrying matching `SocialReviewContext` is pushed.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/pages/social_review/social_review_inbox_page_test.dart`

Expected: the post-centric page lacks the new search, filters, restaurant cards, and navigation.

- [ ] **Step 3: Implement the restaurant-first page**

Use a bounded `Column` with header, carousel-style search, animated compact filters, and an `Expanded` refreshable list. Render `LocationListCard` for hydrated items and a similarly proportioned unresolved card otherwise. Preserve search/filter state across provider refreshes. Use Rova/Naria only for the page title and DM Sans everywhere else.

- [ ] **Step 4: Wire review actions**

Open resolved rows in `ExpandedLocationCard` with `SocialReviewContext`. Route correct/find through `SocialPlaceSearchSheet`; call existing provider `savePlace`, `correctPlace`, `discardPlace`, and `dismissPost` methods; show concise failure feedback and retain the prior UI state when a mutation fails.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run: `flutter test test/pages/social_review/social_review_inbox_page_test.dart`

Expected: all search, filter, card, navigation, fallback, and action tests pass.

### Task 6: Remove obsolete review presentation and verify the feature story

**Files:**
- Modify: `lib/pages/social_review/social_post_review_page.dart`
- Modify: `lib/pages/social_review/social_review_inbox_page.dart`
- Test: all focused social-review, carousel-card, and expanded-card tests above

- [ ] **Step 1: Remove unreachable custom place detail presentation**

Delete or stop routing through the custom `_PlaceDetailSheet` path once every inbox action is available through `ExpandedLocationCard`. Keep `SocialPostReviewPage` operational for existing notification deep links until the separate notification redesign changes those routes.

- [ ] **Step 2: Format and analyze scoped files**

Run: `dart format lib/pages/social_review lib/widgets/home/location_list_card.dart lib/widgets/home/expanded_card/social_review_context.dart lib/widgets/home/expanded_card/sections/social_match_section.dart lib/widgets/home/expanded_location_card.dart lib/providers/social_review_provider.dart lib/supabase/helpers/social_reviews.dart test/pages/social_review test/widgets/home/location_list_card_test.dart test/widgets/home/expanded_card/sections/social_match_section_test.dart test/widgets/home/expanded_location_card_config_test.dart`

Run: `dart analyze lib/pages/social_review lib/widgets/home/location_list_card.dart lib/widgets/home/expanded_card/social_review_context.dart lib/widgets/home/expanded_card/sections/social_match_section.dart lib/widgets/home/expanded_location_card.dart lib/providers/social_review_provider.dart lib/supabase/helpers/social_reviews.dart test/pages/social_review test/widgets/home/location_list_card_test.dart test/widgets/home/expanded_card/sections/social_match_section_test.dart test/widgets/home/expanded_location_card_config_test.dart`

Expected: no errors or warnings introduced by the changed files.

- [ ] **Step 3: Run the complete focused test suite**

Run: `flutter test test/pages/social_review test/providers/social_review_provider_projection_test.dart test/widgets/home/location_list_card_test.dart test/pages/home/carousel_list_page_test.dart test/widgets/home/expanded_card/sections/social_match_section_test.dart test/widgets/home/expanded_location_card_config_test.dart test/widgets/home/expanded_card/sections/tiktok_insights_section_test.dart`

Expected: all focused tests pass with no exceptions or overflow warnings.

- [ ] **Step 4: Inspect the final diff scope**

Run: `git status --short` and `git diff --check`.

Expected: only social-review, shared location-card, expanded-card context, tests, and approved docs are new or modified by this work; the pre-existing processor changes remain untouched.
