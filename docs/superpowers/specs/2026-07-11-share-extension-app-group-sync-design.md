# Share Extension App Group Sync

## Problem

The iOS app saves the signed-in Supabase user ID under the `user_id` key in the `group.com.example.srishlok.pinit` App Group. Both the Runner and URL share-extension entitlements grant access to that group.

`ShareViewController` currently opens `group.com.srishlok.pinit` instead. Because it reads a different defaults suite, it cannot find `user_id` and shows “Please open Pinit and sign in first” even when the user is signed in.

## Design

Keep the active App Group identifier unchanged and update the URL share extension to read `group.com.example.srishlok.pinit`, matching the main app and both active entitlement files.

Do not migrate App Groups or alter signing and provisioning as part of this fix. Those changes are unnecessary for restoring sharing and could invalidate existing provisioning profiles.

## Regression Protection

Add a focused repository test that reads the relevant iOS source and entitlement files and verifies that:

- the Runner writes to the entitled App Group;
- the share extension reads from the same App Group;
- both active entitlement files declare that same identifier.

The test must fail against the current mismatch before the production change is applied and pass afterward.

## Verification

Run the focused regression test, the existing Flutter test suite relevant to sharing/authentication, and an unsigned iOS simulator build. A physical-device TikTok share remains the final end-to-end check because App Group containers and the TikTok share sheet depend on iOS runtime signing and extension hosting.
