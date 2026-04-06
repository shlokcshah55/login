# Bubbles Page Redesign Design

Date: 2026-04-06
Topic: Bubbles page redesign
Status: Approved for spec review

## Context

The current bubbles page works functionally, but the presentation is visually heavy, too dark for the intended mood, and overloaded at the row level. Search behavior is also misaligned with the desired product feel: the main search field currently acts as a people search rather than a unified social search surface.

The redesign should preserve the current bubble data flow and preview-sheet model while making the page feel lighter, more playful, and faster to scan.

## Goals

- Redesign the bubbles page into a light, airy, playful inbox-style screen.
- Keep the page practical and scan-friendly rather than hero-heavy.
- Replace the single-purpose people search with one universal search surface.
- Keep primary row interaction focused on preview first, then chat/activate as explicit follow-up actions.
- Reuse existing provider and sheet behavior where possible to reduce risk.

## Non-Goals

- Rebuild the bubbles data model or realtime subscription system.
- Change bubble mode activation semantics.
- Replace the expanded bubble sheet with a completely different navigation pattern.
- Add unrelated refactors outside the bubbles surface.

## Approved Direction

The approved visual direction is `Airy Inbox`.

This means:

- The page stays list-first and practical.
- The visual system moves away from dark, heavy purple treatments.
- The mood becomes light, pastel, warm, playful, and premium.
- Personality comes from spacing, softness, color accents, and rounded shapes rather than dramatic dark surfaces or dense glass effects.

The closest reference direction is the `A1. Airy Gelato` variant from brainstorming: soft, sunny, social, and polished.

## Visual Design

### Overall Tone

- Bright, soft, and buoyant.
- Warm pastel palette with cream, blush, peach, and light accent tones.
- Rounded forms and gentle shadows.
- Higher visual breathing room than the current implementation.
- Playful, but not childish or noisy.

### Page Chrome

- Use a compact pastel header band rather than a large heavy hero.
- Keep the title area short and readable.
- Present a lighter create action that feels integrated into the header instead of a strong dark CTA block.
- The search field should be a prominent, rounded universal search surface below the title/header area.

### Feed Cards

- Bubble rows should become shorter, cleaner, and easier to scan than the current `ChatGroupTile`.
- Reduce stacked sections and visual density.
- Use clearer prioritization for:
  - bubble name
  - last activity / recency
  - unread state
  - supporting metadata such as member count and pins
- Keep playful color through chips, subtle accents, and soft surfaces instead of large dark gradients.
- Remove the feeling that every row is a mini dashboard.

## Information Architecture

### Default State

The default page is a fast inbox:

- compact header
- universal search field
- bubble feed immediately visible

The feed is the dominant surface, not the header.

### Search State

Search becomes one Snapchat-like universal search interaction.

When the user types into the main search field, the page transitions into a mixed results view with two sections in a single scroll:

1. `Bubbles`
2. `People`

Behavior expectations:

- Bubble results should be derived immediately from the already-loaded local bubble list.
- People results should be fetched asynchronously with debounce.
- Bubble matches appear first.
- The page must remain useful even if people search is slow or fails.

## Interaction Model

### Primary Bubble Row Tap

Primary tap opens a preview/detail sheet first.

The existing `ExpandedChatView` pattern should be reused as the behavioral base, but visually restyled to match the new lighter design language.

Feed rows should behave as a single primary tap target. The redesign should remove the current always-visible dual action emphasis from the row itself and reserve major actions for the preview sheet.

### Actions Inside Preview

Inside the preview sheet:

- `Open Chat` remains available.
- `Activate Bubble` remains available.

These actions should no longer compete as equal primary actions on every feed row.

### People Results

People search results act as discovery/invite entry points and should feel visually simpler than bubble feed items.

## States

### Loading

- Use a lighter branded loading state matching the new palette.
- Avoid heavy, dark, or generic loading visuals.

### Empty Feed

- Empty state should feel welcoming and playful.
- It should encourage creating the first bubble without making the page feel barren.

### Search Empty State

- If no matches exist, show a friendly, lightweight empty result state.
- If only one section is empty, preserve the other section.

### Errors

Error handling should be scoped by surface:

- Bubble feed load failure affects the page-level feed state and should offer retry.
- People search failure affects only the `People` section within search results.
- Bubble search results should remain visible even if people search fails.

## Implementation Boundaries

### Data and State

Keep `BubblesProvider` as the source of truth for the bubble feed and realtime updates.

Use `BubblesPage` presentation state for:

- query text
- search mode visibility
- local bubble filtering
- debounced people search
- per-surface loading and error display

No new parallel data architecture should be introduced for this redesign.

### Existing Components

The redesign should primarily touch:

- `lib/pages/bubbles_page.dart`
- `lib/widgets/chat/chat_group_tile.dart`
- `lib/widgets/chat/expanded_bubble_view.dart`

Shared theme primitives may be extended if needed, but the work should stay focused on bubbles-related styling and interaction.

## Testing Expectations

Add or update tests for the highest-signal behaviors:

- default feed renders bubble content
- search mode shows `Bubbles` and `People` sections in one scroll
- local bubble matches appear without waiting for people search
- tapping a bubble row opens the preview sheet
- empty and error states render in the correct scope

## Risks and Constraints

- The repo already contains unrelated in-progress changes; implementation should avoid interfering with them.
- The browser companion files under `.superpowers/` should remain out of the design commit.
- The redesign should improve style quality without rewriting working realtime/provider behavior.

## Success Criteria

The redesign is successful if:

- the page feels noticeably lighter, more playful, and more polished
- the feed is faster to scan than the current version
- the search experience feels unified rather than split
- preview-first interaction simplifies the main list
- the implementation stays aligned with the current provider-driven architecture
