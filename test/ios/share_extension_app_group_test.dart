import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Runner and URL share extension use the same entitled App Group', () {
    const appGroup = 'group.com.example.srishlok.pinit';
    final runnerSource =
        File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final extensionSource =
        File('ios/URLShareExtension/ShareViewController.swift')
            .readAsStringSync();
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
