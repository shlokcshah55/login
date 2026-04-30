# Default Picks Fallback Design

## Context

The home map currently defaults to the user's saved pin list. This works well
for users with enough nearby saved places, but it leaves sparse users looking at
an underfilled map. The default pin list should use Picks recommendations when
the saved list is not useful enough.

## Requirement

On home startup, use Picks as the default list when either condition is true:

- The user has fewer than 10 saved locations in total.
- The user has fewer than 5 saved locations within 4km of their current
  location.

Otherwise, keep the existing saved-location default.

This is an initial/default-list decision only. User-initiated tab or mode
changes should continue to work as they do today.

## Proposed Approach

Add a small decision helper to `LocationListManager` that evaluates saved-list
coverage from the already-loaded saved locations and an optional user position.
The helper will count total saved locations and saved locations within 4km using
the provider's existing distance calculation.

`HomeViewModel` will run the default-list decision once during startup after
saved locations have loaded and a current position is available. If the saved
list is sparse, it will switch the list type to `recommended` and fetch
recommendations centered on the user's current location. The existing `homeMode`
getter already derives the visible mode from `currentListType`, so the UI should
show Explore/Picks consistently without a separate visual override.

If saved locations are loaded but the current position is not available yet, the
view model should wait for the location rather than switching early. If the user
manually changes modes before the startup decision runs, the startup fallback
should not override that user action.

## Data Flow

1. User signs in and `LocationListManager.fetchSavedLocations()` loads saved
   locations.
2. `HomeViewModel` observes provider changes.
3. Once saved locations are loaded and current location exists, the view model
   asks the provider whether the saved list is sparse.
4. Sparse saved list: set current list type to `recommended`, then fetch Picks
   recommendations for the current location.
5. Sufficient saved list: keep current list type as `saved`.

## Error Handling

If the recommendations fetch fails or returns no results, keep the existing
recommendation error handling and popover behavior. The fallback decision should
not clear saved locations or block users from switching back to the saved list.

If the app cannot get a current location, keep the saved default until location
state changes or the user manually chooses another mode.

## Testing

Add focused test coverage for the sparse-saved decision:

- Fewer than 10 saved locations total returns true.
- At least 10 saved locations but fewer than 5 within 4km returns true.
- At least 10 saved locations with at least 5 within 4km returns false.

Add startup behavior coverage if the current test harness can instantiate the
view model cheaply: saved list sparse plus a known current location switches to
recommendations once, while a manual mode change prevents the automatic
fallback.
