# Home Refactor Notes

This doc explains the HomePage refactor so other developers can quickly orient to the new structure and responsibilities.

## Goals
- Separate UI composition from orchestration logic.
- Centralize state changes and cross-widget coordination.
- Make HomePage easier to read, test, and extend.

## High-Level Changes
- HomePage now composes smaller widgets and delegates orchestration to a view-model.
- Map, carousel, and search overlay are now presentational and callback-driven.
- “Search this area” no longer instantiates a controller inside the map widget.

## New Structure

### View-Model
- `lib/pages/home/home_view_model.dart`
  - Owns Home UI state and side effects.
  - Handles map/carousel sync, debounce, magic search, and nav visibility.

Key responsibilities:
- Initialize map + location tracking.
- Debounced sync from map selection to carousel page.
- Carousel page changes -> map selection and camera animation.
- Search overlay show/hide + magic search submission.
- “Search this area” action.

### UI Widgets
- `lib/pages/home/widgets/home_map_layer.dart`
  - Wraps the map and forwards callbacks.
- `lib/pages/home/widgets/home_header.dart`
  - Gradient header + filter bar.
- `lib/pages/home/widgets/home_carousel.dart`
  - Scroll listener + carousel wrapper.
- `lib/pages/home/widgets/magic_search_button.dart`
  - Floating action button.
- `lib/pages/home/widgets/magic_search_overlay.dart`
  - Modal search UI; stateless.

### Updated Existing Widgets
- `lib/widgets/home/LocationCarousel/location_carousel.dart`
  - Now presentational: accepts `selectedMarkerId`, `bottomNavVisible`, and callbacks.
  - No Provider reads or side effects.
- `lib/widgets/home/pinit_map.dart`
  - Removed controller instantiation.
  - Added `onSearchThisArea` callback.

## Data/State Ownership
- `HomeViewModel` is the single owner of HomePage UI state.
- Providers remain for app-wide state:
  - `LocationListManager`: location data and list state.
  - `MapStateProvider`: map controller, camera, selection.
  - `BottomNavVisibilityProvider`: nav visibility state.

## Flow Summary
- HomePage creates a `HomeViewModel` with providers and calls `init()`.
- Map marker selection -> `MapStateProvider` updates -> view-model debounces and scrolls carousel.
- Carousel page change -> view-model updates `MapStateProvider` and camera.
- Magic search -> view-model calls `LocationListManager.magicSearch`.
- “Search this area” -> view-model calls `MapStateProvider.searchThisArea` and fetches recommended pins.

## Developer Notes
- Avoid creating controllers inside widgets; use the view-model instead.
- Keep widgets stateless/presentational where possible.
- If new features require cross-widget coordination, add it to `HomeViewModel`.

## Suggested Next Steps
- Consider splitting `LocationListManager` into smaller units (data vs UI state).
- Consider a repository interface for location data for easier testing.
