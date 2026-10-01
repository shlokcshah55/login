# Proximity notifications for saved places (iOS)

Nudge users when they are near a place they saved, with social saves
(TikTok / Instagram) boosted and explained by the creator's reason. Works
when the app is closed via iOS region monitoring.

## How it works

1. **Candidates.** Every saved place becomes a `ProximityCandidate`
   (`lib/services/proximity/proximity_candidate.dart`). Social context
   (creator, top dish, vibe, extraction confidence, been-to) comes from the
   `get_proximity_context()` RPC (`supabase/migrations/20261001140000_*`).
2. **Policy.** `ProximityPolicy` decides whether and in what order to notify:
   400 m radius, quiet hours (22:00-08:00), 2/hour and 3/day caps, 4-day
   per-place cooldown, been-to, closed or closing within 30 min, and
   unconfirmed low-confidence shares. Social saves score higher. All numbers
   live in `ProximityConfig`.
3. **Copy.** `buildProximityMessage` leads with the creator's reason
   ("@foodie's pick is nearby / Try the miso cod at Nobu").
4. **Foreground.** `ProximityNotificationService` watches the location stream
   and sends a server push through `send-notification` (this also creates the
   in-app notification row). Places blocked by closing time, quiet hours or
   the hourly cap stay pending and fire once the blocker clears.
5. **Background (iOS).** With "Always" location the nearest <=15 saved places
   are registered as OS regions (`GeofenceManager.swift`). Significant location
   changes (~500 m) wake the app to re-pick the nearest set. A region entry
   runs the same policy on-device and posts a **local** notification. Tapping
   it opens the place via `FCMService.openDeepLink`.
6. **Asking for Always.** After the user's first social save, once the app is
   on screen, `ProximityPrimingSheet` explains the benefit, then iOS shows its
   one-shot upgrade prompt. At most two asks, 14 days apart.
7. **Shared history.** Every send is logged to `proximity_notification_log`
   so caps and cooldowns span devices and reinstalls.

## Known limits (by design)

- Background mode cannot retry: a closed place or quiet hours means a skip,
  because iOS only reports region entries. Deferral works in the foreground.
- Local notifications do not create an in-app notification row.
- iOS monitors at most 20 regions and may report an entry 1-5 minutes late.
- iOS only. Android needs its own geofencing implementation.

## Manual device test (cannot be covered by unit tests)

Use a real iPhone with a debug or TestFlight build. Region monitoring does not
behave faithfully in the simulator.

1. Fresh install, sign in. Confirm iOS does **not** ask for location "Always"
   at launch (the old `GeofenceManager` did).
2. Grant "While Using" through the normal map flow.
3. Share a TikTok/Instagram post of a nearby restaurant to Pinit. Wait for the
   "saved" push. Open Pinit: the explainer sheet appears after ~2 s.
   "Not now" must not show the iOS prompt. Repeat after 14+ days or reset the
   app data to see it again; choose "Turn on nudges" and confirm the iOS
   upgrade prompt appears. Pick "Change to Always Allow".
4. Settings > Pinit > Location shows **Always**.
5. Force-quit Pinit. Walk or drive into the place's 400 m radius. Expect a
   local notification within a few minutes, titled "@creator's pick is nearby"
   when creator data exists. Tap it: Pinit opens on the place.
6. Repeat the entry: no second notification within 4 days.
7. Try a place that is closed right now, and quiet hours (after 22:00): no
   notification.
8. Walk ~1 km. Confirm the monitored set refreshes (debug log
   `[Proximity] monitoring N regions`) and a different nearby saved place now
   triggers.
9. Revoke "Always" in Settings: nudges stop, the foreground behaviour remains.
10. Sign out: monitored regions are cleared.
