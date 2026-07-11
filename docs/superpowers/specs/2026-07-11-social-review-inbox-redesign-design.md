# Social Review Inbox Redesign Design

Date: 2026-07-11
Status: Approved design

## Objective

Replace the post-centric social review presentation with a searchable, restaurant-first inbox that looks and behaves like Pinit's carousel list view. Restaurant taps open the normal expanded card with video insights and an additional confidence segment.

## Product principles

- Restaurants, not processing jobs, are the primary object users recognise and review.
- Reuse Pinit's established restaurant card and expanded-card interaction.
- Successful shares remain easy to inspect without demanding attention.
- Uncertain and failed matches clearly explain the action required.
- Search is conventional local filtering, not magic or natural-language search.

## Information architecture

The inbox has three filters:

- **Needs checking:** low-confidence, unresolved, ambiguous, or failed results.
- **Recently saved:** successfully resolved social-share restaurants, newest first.
- **All:** the complete visible social-share history.

When attention items exist, `Needs checking` is selected on first entry. Otherwise, `Recently saved` is selected. A notification deep link overrides the initial filter and focuses the relevant post or places.

The existing `Review later` section is removed. Dismissing the in-app signal controls interruption; inbox status controls whether a restaurant still needs action.

## Header and typography

- Rova with Naria fallback is used for the page title and major branded heading only.
- DM Sans is used for search, filters, restaurant cards, metadata, confidence, and actions.
- Remove local social-review typography choices that produce a visibly different type system.
- Use Pinit's warm background, cream surfaces, aubergine structure, and existing spacing rhythm.

## Search

Reuse the carousel list search field's dimensions, fill, border, clear action, and typography. The hint is `Search restaurants`.

Filtering is case-insensitive and matches:

- restaurant name;
- cuisine;
- address or area;
- creator handle;
- social post title;
- extracted dish names.

Search operates across the selected filter. Clearing the query restores its full list. Empty copy distinguishes `No matching restaurants` from `No shares need checking` and `No recent social saves`.

## Restaurant list card

Extract the private carousel `_ListCard` into a reusable `LocationListCard` rather than duplicating it. Both the carousel list and social inbox consume this shared component.

The shared visual structure retains:

- image-left and information-right layout;
- restaurant name, cuisine, area, and useful location metadata;
- cream surface, aubergine or accent border, rounded corners, and offset shadow;
- existing image fallback and open/closed treatment;
- full-card tap target.

The inbox supplies a compact trailing/context overlay:

- TikTok or Instagram provenance;
- `Saved`, `Check match`, or `Processing` state;
- optional creator handle.

Confidence does not dominate the list. Only items requiring attention display `Check match` prominently.

## Data preparation

The inbox flattens post review items into view models representing one extracted restaurant each. Each view model includes:

- source review and social post IDs;
- platform, creator, title, and source URL;
- extracted candidate and confidence metadata;
- place action and review outcome;
- hydrated `LocationModel` when a location ID exists;
- searchable text tokens.

Locations are fetched in batches by ID and cached for the active inbox session. Loading one restaurant must not trigger one independent network request per list row. Items with missing or stale location IDs fall back to an unresolved card instead of disappearing.

## Expanded restaurant experience

Tapping a resolved list item opens the standard `ExpandedLocationCard` using the same dialog transition as the carousel list.

The card receives optional `SocialReviewContext`. Without it, existing callers and layout remain unchanged. With it, the expanded card:

- renders normal restaurant content;
- renders existing TikTok/Reel provenance and video insights;
- adds a `TikTok match` or `Reel match` confidence segment;
- exposes review actions appropriate to the current status.

The custom social-review detail sheet is removed after all actions have parity in the expanded card.

## Confidence segment

Place the segment near the existing social-video insight content so the rating is understood as extraction confidence, not restaurant quality.

When a numeric processor score exists:

> TikTok match
> 92% - Strong match
> We matched this post to Dishoom Shoreditch.

When only a tier exists, show `Strong match`, `Possible match`, or `Needs checking` without inventing a percentage. When neither exists, omit the rating and show only the source relationship.

Actions are status-dependent:

- resolved and saved: `Correct restaurant` and `Remove from saves`;
- unresolved candidate: `Confirm match`, `Correct restaurant`, and `Not a restaurant`;
- corrected: show the corrected state and allow another correction;
- processing: no destructive actions, with a clear processing state;
- failed: route to place search.

Action completion updates the inbox view model immediately, persists through the existing review provider, and refreshes the associated notification state.

## Unresolved and failed cards

Use a fallback card with the same dimensions and structural styling as a restaurant card. It contains:

- source thumbnail or platform artwork;
- extracted candidate name when present;
- `Restaurant not identified` or `Check this match` copy;
- primary `Find restaurant` action;
- secondary `Dismiss` action.

`Find restaurant` opens the existing social place-search picker. After selection, Pinit registers and saves the location, updates the review record, replaces the fallback with a hydrated restaurant card, and opens the expanded card.

Dismissal resolves only the candidate or review item; it must not remove unrelated restaurants extracted from the same post.

## Error and loading behaviour

- Initial load uses restaurant-card skeletons rather than a full-page spinner.
- Search remains responsive while already-loaded locations are visible.
- A failed batch hydration shows fallback cards and one retry affordance.
- An individual missing location shows an unresolved card.
- Failed review mutations restore the prior local state and show actionable error feedback.
- Realtime updates merge without resetting the user's current search text or selected filter.

## Analytics

Track:

- inbox opened with source and initial filter;
- filter changes and search usage without logging raw query text;
- restaurant card opened;
- expanded confidence segment shown;
- confirm, correct, remove, find, and dismiss outcomes;
- video insight and original-post interactions;
- hydration and routing failures.

## Accessibility

- Restaurant card semantics include name, cuisine/area, source platform, and review status.
- Confidence is spoken as match confidence and never as restaurant quality.
- All swipe or gesture actions have visible button alternatives.
- Search, filter controls, cards, and expanded-card actions support logical focus order and dynamic text.
- Status is communicated by text and icon as well as colour.

## Verification

- View-model flattening and batch location hydration.
- Default filter selection with and without attention items.
- Search matching every supported field and interacting correctly with filters.
- Shared carousel-style card rendering in both original and inbox surfaces.
- Resolved-card navigation to `ExpandedLocationCard`.
- TikTok/Reel insights and optional confidence segment variants.
- Confirm, correct, remove, find, dismiss, and processing states.
- Missing-location, failed hydration, mutation rollback, empty, and retry states.
- Deep-link focus from individual and consolidated notifications.
- Realtime updates preserving search and filter state.
- Semantics and dynamic-text coverage.

## Out of scope

- Changing the extraction model or confidence calibration.
- Natural-language or global map search inside the inbox.
- A second restaurant detail design separate from `ExpandedLocationCard`.
- Reworking non-social sections of Profile notifications.
