# Profile Setup “Zine” Cards — Design Spec

**Date:** 2026-05-05  
**Owner:** Codex  
**Status:** Draft (awaiting approval)

## Goal

Make the profile setup **carousel card** (Home) and **checklist card** (Profile) feel more **playful + loud** while staying readable on the existing purple/beige/orange theme.

## Scope

**In scope**
- Home carousel card: `ProfileCompletionCarouselCard`
  - File: `lib/pages/home/widgets/profile_completion_carousel_card.dart`
- Profile checklist card: `ProfileCompletionChecklistCard`
  - File: `lib/pages/profile/widgets/profile_completion_checklist_card.dart`
- Add one new “quaternary” accent color token
  - File: `lib/pages/profile/widgets/pinit_colors.dart` (and/or shared theme color file if that’s the canonical source in-app)

**Out of scope**
- Changing checklist logic, navigation behavior, or text content meaningfully
- Introducing gradients
- Increasing rounding (we explicitly remove it)

## Non-negotiables (from request)

- **No gradients** anywhere in these components.
- **No rounding** anywhere in these components:
  - Outer card containers
  - Pills/badges
  - Buttons
  - Icon containers
  - Checklist rows

## Visual Direction: Approach 1 — “Sticker / Zine Poster”

High-contrast outlines, offset hard shadow (“printed” feel), corner label, and color-blocked icon tiles.

### New Quaternary Color

Add a single new accent color that plays well with:
- Aubergine (purple)
- Cream family (beige)
- Accent (orange/red)

**Proposed:** `teal` (cool counterpoint; used sparingly)
- Example hex: `#1FA89A`

Rules:
- Teal is used as a *secondary accent* to keep orange scarce.
- Only these two components use teal initially.

## Component Specs

### A) Home: `ProfileCompletionCarouselCard`

Current: rounded card, tidy, relatively calm.

Target changes:
- **Square geometry:** `BorderRadius.zero` everywhere.
- **Louder frame:** thicker border (2.0–2.5) in `aubergine`.
- **Hard offset shadow:** stamped/printed feel (no blur).
- **Corner label:** “SETUP” or “PROFILE” label in uppercase DM Sans.
- **Progress badge:** replace the rounded pill with a square badge.
- **Icon tile:** checklist icon sits in a square color block (teal/orange).
- **Button:** square corners; strong fill; optionally add a thin border for a “poster” look.
- Maintain existing layout height and tap targets.

Suggested palette usage (example):
- Card fill: `creamSunk`
- Border/shadow/text: `aubergine`
- Corner label fill: `teal` with `aubergine` text (or inverse, depending on contrast)
- Progress badge fill: `teal` (or `accent` when incomplete) with `cream` text

### B) Profile: `ProfileCompletionChecklistCard`

Current: rounded container + rounded rows; icon circles; muted.

Target changes:
- **Square geometry:** `BorderRadius.zero` everywhere.
- **Poster frame:** thicker aubergine border + hard offset shadow.
- **Header art direction:**
  - Add a small corner label (e.g. “SETUP CHECKLIST”)
  - Make progress badge square + louder
- **Checklist rows:**
  - Square row container with strong border
  - Replace circular icon bubble with a **square icon tile**
  - Each row gets a distinct tile fill (rotate: teal / accent / creamDeep) to feel “stickered”
  - Done state becomes more “stamped”: e.g. `DONE` tag or a bold check icon + muted row background (still square)
- Keep `onTap` behavior and disabled behavior identical.

## Accessibility / Legibility

- Preserve minimum 44px tap targets for row and buttons.
- Ensure teal/orange usage keeps text contrast high (prefer aubergine/cream text).
- Avoid using orange for long text; reserve it for small labels/tiles.

## Success Criteria

- Both cards read as intentionally “poster-like”: square corners, thick outline, offset stamp shadow.
- Teal feels additive (not random), and does not spread beyond these components.
- No visual regressions: layout remains stable, no overflow, no clipped content.

## Open Questions (confirm before finalizing)

1) Corner label text: “SETUP”, “PROFILE SETUP”, or “CHECKLIST”?
2) Teal hex preference (I propose `#1FA89A`), or do you have a specific quaternary color in mind?

