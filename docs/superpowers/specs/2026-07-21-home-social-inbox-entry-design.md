# Home Social Inbox Entry Design

## Goal

Replace the home page's World Cup/football action with a direct entry to the existing social-share inbox. The change should make shared TikToks and Instagram Reels easy to reach without adding another home mode or obscuring the map.

## Scope

- Remove the football action from the home page and remove its home-only imports, callbacks, and search/overlay wiring.
- Leave the standalone football implementation files in place but unreachable from home. Deleting the feature implementation is outside this change.
- Reuse the existing `SocialReviewProvider` and `SocialReviewInboxPage`; do not add a parallel inbox or new data flow.

## Interaction and Visual Design

The action stays in the existing trailing slot beneath the Saved, Picks, and Eat-lists mode row. It becomes a compact, circular inbox button using Pinit's cream/aubergine styling, restrained offset shadow, and a short press-scale response.

The button is always visible outside bubble mode so the inbox remains reachable even when it is empty. When `SocialReviewProvider.needsCheckingCount` is greater than zero, a small count badge appears on the button. The semantic label is `Open shared saves inbox` and includes the outstanding count when present.

Tapping the button uses the app's existing imperative navigation pattern to push `SocialReviewInboxPage`. The inbox remains responsible for loading, empty, error, filtering, and review states.

## Component Boundaries

- `HomeSocialInboxButton` owns only the compact button presentation, badge, semantics, and press feedback.
- `HomePage` reads the existing provider count, supplies the tap callback, and opens the inbox route.
- `HomeChipRow` exposes a neutral trailing-action slot instead of a football-specific property, so the row no longer contains seasonal feature terminology.

## Testing

- A widget test verifies the inbox control renders, reports the outstanding count, and invokes its callback.
- Existing home-related tests and social-review tests remain green.
- Static analysis verifies that removal of football-specific home dependencies leaves no unresolved references.

## Non-goals

- Changing the social-share inbox itself.
- Changing how review counts are calculated.
- Deleting the football view model, overlay, service, or their tests.
- Adding a new bottom-navigation destination or deep link.
