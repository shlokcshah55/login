# Device Startup Cache Design

**Date:** 2026-07-11
**Status:** Approved design, pending implementation plan

## Goal

Make a cold launch substantially faster for an already-signed-in user by showing their last known profile and saved locations from on-device storage, then refreshing that data from Supabase in the background.

There is no fixed launch-time service-level target for this first iteration. Success means a clearly earlier first usable home screen without weakening logout, account-switching, legal-consent, or session-invalidity behavior.

## Current Startup Path

The current cold-start path has two blocking stages:

1. `main()` waits for the full bootstrap before calling `runApp()`. Bootstrap currently includes analytics setup, Firebase, notification-open registration, location service initialization, custom marker initialization, environment loading, Supabase initialization and session validation, and FCM initialization.
2. `AuthHandler` keeps the launch splash visible until the authenticated user's profile, legal-consent status, and saved locations have loaded. Saved-location loading also creates map markers before it reports completion.

The existing location cache is in memory with a time-to-live, so it does not survive process death. `cached_network_image` already provides a suitable managed disk cache for remote images and should remain responsible for image files.

## Scope

This design covers:

- cold launches for users with a locally restored Supabase session;
- persistent, user-scoped snapshots of profile and saved-location data;
- immediate provider hydration from a valid snapshot;
- stale-while-revalidate refreshes from Supabase;
- legal-consent cache safety;
- deferring noncritical initialization until after the first frame;
- cache lifecycle, failures, observability, and testing.

This design does not add offline writes, background synchronization of user mutations, a general-purpose offline database, cached recommendation/search results, or Android `FlutterEngine` prewarming. Those can be considered separately if measurement shows they are needed.

## Chosen Approach

Store a versioned JSON snapshot in the platform-private application-support directory. This is preferred over:

- `SharedPreferences`, which is appropriate for small preferences but not a growing saved-location dataset;
- SQLite or Drift, which would add database schema and migration complexity before the app needs local querying.

The cache is accessed through an interface so its JSON implementation can later be replaced without changing provider or startup-coordinator APIs.

## Architecture

### `StartupSnapshot`

An immutable model representing the last usable authenticated state. It contains:

- `schemaVersion`;
- `userId`;
- `writtenAt` in UTC;
- serialized `UserModel`, when available;
- saved locations as serialized `LocationModel` values;
- legal-consent policy version accepted by the user, when known.

The snapshot stores image URLs but never image bytes, access tokens, or refresh tokens.

### `StartupSnapshotStore`

A small storage boundary responsible only for snapshot persistence:

- `read(userId)` returns a decoded snapshot or no snapshot;
- `write(snapshot)` atomically replaces the prior snapshot;
- `clear(userId)` deletes one user's snapshot;
- `clearAll()` is reserved for account cleanup or an unrecoverable ownership mismatch.

Files are namespaced by a non-reversible hash of the user ID rather than a raw ID in the filename. Writes use a temporary file followed by replacement so an interrupted write cannot destroy the last good snapshot. Concurrent writes are serialized, and frequent writes caused by realtime events are debounced.

Parsing is defensive. An unsupported schema, ownership mismatch, or corrupt section is treated as a cache miss for that section. A corrupt saved-location payload must not prevent a valid cached profile from being used.

### `StartupHydrationCoordinator`

The coordinator joins session restoration, local hydration, and remote revalidation without owning UI state.

Its responsibilities are:

1. identify the user from the locally restored Supabase session;
2. load the matching snapshot;
3. hydrate `UserDataProvider` and `LocationListManager` through explicit cache-hydration methods;
4. notify routing that cached startup data is usable;
5. start independent remote refreshes for profile, saved locations, and consent;
6. persist a consolidated snapshot after successful refreshes.

The coordinator must never apply an asynchronous result after the active user changes.

### Provider Changes

`UserDataProvider` gains an explicit method to hydrate a cached `UserModel` without presenting the operation as a server fetch.

`LocationListManager` gains an explicit method to hydrate cached saved locations. It marks the saved-location dataset usable immediately, publishes the list, and schedules marker generation separately. Cached locations may therefore appear in list-based UI before every map marker has finished rendering.

Existing remote fetch methods remain authoritative and replace cached state when they succeed. Provider state distinguishes:

- usable cached data;
- a background refresh in progress;
- fresh remote data;
- stale data retained after a refresh error.

Background refreshes must not switch the whole home screen back to the launch splash.

## Startup Data Flow

### Minimal pre-UI bootstrap

Only initialization required to construct the app and identify the locally restored session remains before the first Flutter UI. Work that can safely happen later is started after the first frame and is not awaited by the first usable home screen.

The implementation plan must classify each existing bootstrap operation before moving it. The expected deferred candidates are FCM registration, location tracking, notification setup, and marker preparation. Deep-link and notification-open behavior must be preserved, so their handlers may need early registration even when their network or token work is deferred.

### Cached launch

1. Restore the local Supabase session and obtain its user ID.
2. Read only the snapshot belonging to that user.
3. Hydrate each valid cached section independently.
4. If the cached profile and saved-location state are sufficient for the existing home route and the cached consent-policy version matches the app's required version, show `MainScreen` without waiting for Supabase data fetches or marker generation. Otherwise, preserve the relevant profile, consent, or network gate.
5. Start remote profile, saved-location, and consent requests concurrently.
6. Apply each successful result independently, then write an updated consolidated snapshot.

Snapshot age is recorded for diagnostics and stale-state presentation but is not a hard expiry. Old user content remains useful when offline. Every cold launch still attempts a background refresh.

### Cache miss

If there is no usable snapshot, retain the current network-backed launch behavior. The app must not fabricate an authenticated home state from incomplete data.

### Remote refresh

Profile, locations, and consent refresh independently. A failure in one request does not discard successful results from another request or erase usable cached data. Successful data replaces stale data in its provider immediately.

The snapshot store consolidates the latest known sections so a partial refresh does not overwrite a valid cached section with an absent value.

## Authentication and Legal Consent

Cached application data is accepted only when its `userId` matches the locally restored session. A definitive invalid-session result clears the user-scoped cache, clears provider state, and routes to the welcome screen.

Logout, account deletion, and user switching clear the affected user's provider state and snapshot. Cache cleanup is device-side work and remains separate from server-side session or account cleanup.

Legal consent is not cached as an unversioned boolean. The app defines the currently required consent-policy version. Cached consent can bypass the network-backed gate only when the snapshot records the same accepted version. A missing or mismatched version requires the existing legal-consent gate. The background server check may correct cached consent state and must never silently accept a newer policy for the user.

## Offline and Error Behavior

- When a matching snapshot exists but the device is offline, show cached content and expose a subtle offline or stale indicator rather than returning to the launch splash.
- When one cache section is corrupt, ignore that section and continue with other valid sections.
- When the entire snapshot is unreadable, treat it as a cache miss and replace it only after a successful remote load.
- When a background refresh fails, retain cached data and record the failure for diagnostics. Do not show a blocking startup error.
- When marker generation fails for an individual location, keep the location in non-map UI and report the marker failure without invalidating the snapshot.
- When the active user changes during hydration or refresh, discard results belonging to the previous user.

## Storage and Privacy

Snapshots live in the OS-private application-support directory. No auth credentials are duplicated into the cache. Supabase remains responsible for auth-session persistence.

The first implementation relies on platform app-container protection rather than adding application-level encryption. If the product threat model later requires encryption at rest beyond the OS sandbox, the store interface allows an encrypted implementation to replace the JSON store.

Snapshot size and write duration are instrumented. A conservative maximum decoded size prevents malformed or unexpectedly large files from consuming excessive memory. Image files remain in the managed network-image cache and follow its eviction policy.

## Observability and Success Criteria

Record monotonic timing milestones for:

- process/Dart entry to `runApp()`;
- local session restoration;
- snapshot read and decode;
- first Flutter frame;
- cached providers usable;
- first usable home screen;
- remote profile refresh complete;
- remote saved-location refresh complete;
- marker generation complete.

Record cache hit, partial hit, miss, unsupported schema, ownership mismatch, corrupt snapshot, and offline-refresh outcomes without logging cached personal data.

The change is successful when profile-mode cold launches on representative Android and iOS devices show a materially earlier first usable home screen, cached data refreshes correctly, and invalid-session/logout behavior remains correct. Measurement must distinguish a rendered splash, a first frame, and a genuinely usable home screen.

## Testing

### Unit tests

- snapshot serialization and round trips;
- supported and unsupported schema versions;
- user ownership checks;
- corrupt whole-file and corrupt-section handling;
- atomic replacement and recovery from an interrupted temporary write;
- maximum-size enforcement;
- debounced and serialized writes;
- per-user clearing and full clearing;
- consent-policy version matching.

### Provider and coordinator tests

- cached profile is published before a delayed remote profile response;
- cached saved locations are usable before marker generation and remote refresh complete;
- independent refresh success and failure preserve the latest valid sections;
- stale async results are discarded after a user switch;
- invalid sessions clear cached and in-memory state;
- logout and account deletion clear the correct snapshot;
- offline refresh retains cached content and exposes stale status.

### Widget tests

- a matching snapshot allows authenticated home content to replace the launch splash while remote requests remain pending;
- a cache miss keeps the current guarded startup behavior;
- background refresh does not return the UI to the launch splash;
- consent-policy mismatch presents the legal gate;
- cached list content can render while map markers are still being prepared.

### Device verification

Run repeated profile-mode cold launches on representative Android and iOS devices. Compare timing distributions before and after the change, test online and offline launches, and manually verify notification/deep-link routing after bootstrap work is deferred.

## Rollout

Introduce the cache behind a local feature flag or remotely controlled rollout switch. First ship instrumentation with behavior disabled to establish a baseline, then enable cache writes, then enable cache reads for internal users. Expand only after observing cache integrity, session cleanup, and startup timing.

If cache reads cause a startup regression, disable reads while leaving remote startup intact. The JSON cache is an optimization, never the sole source of authenticated user data.
