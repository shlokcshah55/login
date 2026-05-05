# Profile Setup “Zine” Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Home “Finish setting up” carousel card and the Profile checklist card feel playful/loud with a zine-like poster style (no gradients, no rounding).

**Architecture:** Pure UI styling changes in-place (no logic changes). Introduce one new quaternary color token (`teal`) in `PinitColors` and apply it sparingly for labels/badges/icon tiles.

**Tech Stack:** Flutter, Material, GoogleFonts, existing `PinitColors`.

---

## File map

**Modify**
- `lib/pages/profile/widgets/pinit_colors.dart` (add `teal` constant)
- `lib/pages/home/widgets/profile_completion_carousel_card.dart` (square-corner zine styling)
- `lib/pages/profile/widgets/profile_completion_checklist_card.dart` (square-corner zine styling)

## Task 1: Add quaternary color token

**Files:**
- Modify: `lib/pages/profile/widgets/pinit_colors.dart`

- [ ] **Step 1: Add `static const Color teal`**

Add near existing palette tokens:

```dart
static const Color teal = Color(0xFF1FA89A);
```

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/pages/profile/widgets/pinit_colors.dart`  
Expected: no issues.

## Task 2: Restyle Home carousel setup card

**Files:**
- Modify: `lib/pages/home/widgets/profile_completion_carousel_card.dart`

- [ ] **Step 1: Remove all BorderRadius usage**

Changes include:
- Outer card `BoxDecoration.borderRadius` → remove
- Remove `ClipRRect` used only for rounding
- Button shape from rounded to square
- `_MiniIconButton` from circular to square

- [ ] **Step 2: Apply zine styling**

Implement:
- Thicker border (`~2.2`)
- Hard stamped shadow (offset, blurRadius 0)
- Add a small square corner label (e.g. `SETUP`) using `PinitColors.teal`
- Make progress badge square and louder
- Add square icon tile around the checklist icon

- [ ] **Step 3: Run analyzer**

Run: `dart analyze lib/pages/home/widgets/profile_completion_carousel_card.dart`  
Expected: no issues.

## Task 3: Restyle Profile checklist card

**Files:**
- Modify: `lib/pages/profile/widgets/profile_completion_checklist_card.dart`

- [ ] **Step 1: Remove all BorderRadius usage**

Changes include:
- Outer card `BoxDecoration.borderRadius` → remove
- Progress badge radius → remove
- `_ChecklistRow` container + InkWell radius → remove
- Replace circular icon bubble with square tile (`BoxShape.rectangle`)

- [ ] **Step 2: Apply zine styling**

Implement:
- Thicker border + stamped shadow
- Add a small label row (“SETUP CHECKLIST”) in uppercase DM Sans
- Use `PinitColors.teal` + existing `PinitColors.accent` for icon tiles/badges
- Stronger row borders (aubergine) and distinct tile colors per row

- [ ] **Step 3: Run analyzer**

Run: `dart analyze lib/pages/profile/widgets/profile_completion_checklist_card.dart`  
Expected: no issues.

## Task 4: Quick smoke checks

- [ ] **Step 1: Search for accidental remaining rounding**

Run: `rg -n "BorderRadius\\.circular\\(|BorderRadius\\.all\\(|BoxShape\\.circle" lib/pages/home/widgets/profile_completion_carousel_card.dart lib/pages/profile/widgets/profile_completion_checklist_card.dart`  
Expected: no matches (unless circle is intentionally used elsewhere in those files).

- [ ] **Step 2: Run analyzer on both**

Run: `dart analyze lib/pages/home/widgets/profile_completion_carousel_card.dart lib/pages/profile/widgets/profile_completion_checklist_card.dart`  
Expected: no issues.

