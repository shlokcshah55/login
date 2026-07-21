# Home Social Inbox Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home page's World Cup button with a compact button that opens the existing shared-saves inbox.

**Architecture:** Add a focused home inbox-button widget for presentation and expose a neutral trailing-action slot from `HomeChipRow`. `HomePage` consumes the existing `SocialReviewProvider.needsCheckingCount` and pushes `SocialReviewInboxPage`, while all football-only home wiring is removed.

**Tech Stack:** Flutter, Provider, Material `Navigator`, flutter_test

---

### Task 1: Build the compact inbox control

**Files:**
- Create: `lib/pages/home/widgets/home_social_inbox_button.dart`
- Create: `test/pages/home/widgets/home_social_inbox_button_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create the test file with the button and neutral-slot behavior expressed separately:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/home/widgets/home_social_inbox_button.dart';
import 'package:login/pages/home/widgets/mode_toggle.dart';

void main() {
  testWidgets('shows the outstanding count and invokes its callback',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSocialInboxButton(
            count: 3,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('home_social_inbox_button')), findsOneWidget);
    expect(find.byIcon(FeatherIcons.inbox), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Open shared saves inbox, 3 need checking'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('home_social_inbox_button')));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('hides the count badge when nothing needs checking',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSocialInboxButton(count: 0, onTap: () {}),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
    expect(
      find.bySemanticsLabel('Open shared saves inbox'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/pages/home/widgets/home_social_inbox_button_test.dart`

Expected: FAIL because `home_social_inbox_button.dart` and `HomeSocialInboxButton` do not exist.

- [ ] **Step 3: Implement the minimal production widget**

Create `HomeSocialInboxButton` as a stateful, 44px circular control:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

class HomeSocialInboxButton extends StatefulWidget {
  const HomeSocialInboxButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  State<HomeSocialInboxButton> createState() =>
      _HomeSocialInboxButtonState();
}

class _HomeSocialInboxButtonState extends State<HomeSocialInboxButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final hasCount = widget.count > 0;
    final countLabel = widget.count > 99 ? '99+' : '${widget.count}';
    final semanticLabel = hasCount
        ? 'Open shared saves inbox, ${widget.count} need checking'
        : 'Open shared saves inbox';

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('home_social_inbox_button'),
        onTapDown: (_) => setState(() => _scale = 0.94),
        onTapUp: (_) {
          setState(() => _scale = 1);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _scale = 1),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PinitColors.cream,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: PinitColors.aubergine,
                        width: 1.6,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: PinitColors.aubergine,
                          blurRadius: 0,
                          offset: Offset(3, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      FeatherIcons.inbox,
                      color: PinitColors.aubergine,
                      size: 21,
                    ),
                  ),
                ),
                if (hasCount)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 19),
                      height: 19,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: const BoxDecoration(
                        color: PinitColors.aubergine,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        countLabel,
                        style: GoogleFonts.dmSans(
                          color: PinitColors.cream,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test to verify it passes**

Run: `flutter test test/pages/home/widgets/home_social_inbox_button_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the control**

```bash
git add lib/pages/home/widgets/home_social_inbox_button.dart test/pages/home/widgets/home_social_inbox_button_test.dart
git commit -m "feat: add home social inbox button"
```

### Task 2: Replace the football home entry

**Files:**
- Modify: `lib/pages/home/widgets/mode_toggle.dart`
- Modify: `lib/pages/home_page.dart`
- Test: `test/pages/home/widgets/home_social_inbox_button_test.dart`

- [ ] **Step 1: Extend the failing test around the neutral slot contract**

Add this widget test before the closing brace of the test file:

```dart
testWidgets('home mode row exposes a neutral trailing action', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          child: HomeChipRow(
            currentMode: HomeMode.you,
            onModeChanged: (_) {},
            collections: const [],
            isLoadingCollections: false,
            onCollectionMenuOpened: () {},
            onCollectionSelected: (_) {},
            trailingAction: const Text('Inbox action'),
          ),
        ),
      ),
    ),
  );

  expect(find.text('Inbox action'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/pages/home/widgets/home_social_inbox_button_test.dart`

Expected: FAIL because `HomeChipRow` has no `trailingAction` parameter.

- [ ] **Step 3: Make the mode row slot neutral**

In `mode_toggle.dart`, rename `footballAction` to `trailingAction` in the constructor, field, visibility condition, and rendered child. Preserve its existing position and hide it in bubble mode.

- [ ] **Step 4: Wire the inbox route and remove football wiring**

In `home_page.dart`:

- remove the football view-model, overlay, fixtures service, natural-language service, and geo-type imports;
- remove `_runFootballMagicSearch`, `_openFootballDiscoveryOverlay`, and `_FootballDiscoveryButton`;
- import `HomeSocialInboxButton` and `SocialReviewInboxPage`;
- rename `_TopPanel.onFootballDiscoveryTap` to `onSocialInboxTap`;
- pass a callback that pushes `const SocialReviewInboxPage()` from both `_TopPanel` call sites;
- replace the old `footballAction` argument with:

```dart
trailingAction: Consumer<SocialReviewProvider>(
  builder: (context, socialReview, _) => HomeSocialInboxButton(
    count: socialReview.needsCheckingCount,
    onTap: onSocialInboxTap,
  ),
),
```

- [ ] **Step 5: Verify targeted behavior and static analysis**

Run:

```bash
dart format lib/pages/home/widgets/home_social_inbox_button.dart lib/pages/home/widgets/mode_toggle.dart lib/pages/home_page.dart test/pages/home/widgets/home_social_inbox_button_test.dart
flutter test test/pages/home/widgets/home_social_inbox_button_test.dart
flutter analyze lib/pages/home/widgets/home_social_inbox_button.dart lib/pages/home/widgets/mode_toggle.dart lib/pages/home_page.dart test/pages/home/widgets/home_social_inbox_button_test.dart
rg -n "FootballDiscovery|onFootballDiscoveryTap|footballAction|sports_soccer_rounded" lib/pages/home_page.dart lib/pages/home/widgets/mode_toggle.dart
```

Expected: formatting succeeds; the test passes; analysis reports no issues; the final search returns no matches.

- [ ] **Step 6: Run related regression tests**

Run:

```bash
flutter test test/pages/home test/pages/social_review
git diff --check
```

Expected: all tests pass and `git diff --check` reports no whitespace errors.

- [ ] **Step 7: Commit and push**

```bash
git add lib/pages/home/widgets/home_social_inbox_button.dart lib/pages/home/widgets/mode_toggle.dart lib/pages/home_page.dart test/pages/home/widgets/home_social_inbox_button_test.dart
git commit -m "feat: open social inbox from home"
git push origin codex/social-share-review-redesign
```
