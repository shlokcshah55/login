# Share Extension App Group Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iOS URL share extension read the signed-in Pinit user from the same App Group used by the main app.

**Architecture:** Keep the currently signed `group.com.example.srishlok.pinit` App Group unchanged. Add a repository-level regression test for the main app, share extension, and both entitlement files, then correct the extension's mismatched UserDefaults suite.

**Tech Stack:** Flutter test, Dart file inspection, Swift, iOS App Groups

---

### Task 1: Lock and repair the shared App Group identifier

**Files:**
- Create: `test/ios/share_extension_app_group_test.dart`
- Modify: `ios/URLShareExtension/ShareViewController.swift:123`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Runner and URL share extension use the same entitled App Group', () {
    const appGroup = 'group.com.example.srishlok.pinit';
    final runnerSource = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final extensionSource =
        File('ios/URLShareExtension/ShareViewController.swift').readAsStringSync();
    final runnerEntitlements =
        File('ios/Runner/Runner.entitlements').readAsStringSync();
    final extensionEntitlements =
        File('ios/URLShareExtension/URLShareExtension.entitlements')
            .readAsStringSync();

    expect(runnerSource, contains('UserDefaults(suiteName: "$appGroup")'));
    expect(extensionSource, contains('UserDefaults(suiteName: "$appGroup")'));
    expect(runnerEntitlements, contains('<string>$appGroup</string>'));
    expect(extensionEntitlements, contains('<string>$appGroup</string>'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ios/share_extension_app_group_test.dart`

Expected: FAIL because `ShareViewController.swift` uses `group.com.srishlok.pinit`.

- [ ] **Step 3: Apply the minimal fix**

Change the suite in `ShareViewController.swift` to:

```swift
UserDefaults(suiteName: "group.com.example.srishlok.pinit")
```

- [ ] **Step 4: Verify the fix**

Run: `flutter test test/ios/share_extension_app_group_test.dart`

Expected: PASS.

Run: `flutter test test/pages/auth_handler_test.dart test/ios/share_extension_app_group_test.dart`

Expected: PASS.

Run: `flutter build ios --simulator --debug`

Expected: Build succeeds without code-signing or Swift compilation errors.
