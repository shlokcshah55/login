# Home Header Search Overlay Refresh Design

Date: 2026-04-07
Topic: Homepage header search overlay refresh
Status: Approved for spec review

## Context

The new homepage header search behavior has already been implemented functionally as a premium predictive search surface with waterfall loading, three result families, and map/profile actions. The current issue is presentation rather than search logic: the overlay feels too heavy, too modal, and too visibly layered over the home page.

The redesigned surface should still launch from the homepage header search entry point, but once opened it should feel like a complete search environment of its own. The home page should not remain visually present underneath the search state.

## Goals

- Restyle the header search into a full-screen premium search surface.
- Cover the entire page so the home screen is no longer visible beneath the search state.
- Reuse the lighter, warmer visual language established on the bubbles page.
- Shift the UI away from highly rounded pill-heavy forms toward a cleaner pressed-glass shape language.
- Add subtle motion that makes the surface feel live while typing without becoming flashy.
- Preserve the existing waterfall predictive search behavior and interaction model.

## Non-Goals

- Rework the search ranking, intent detection, or waterfall data pipeline.
- Change the existing magic-search entry point or remove `MagicSearchOverlay`.
- Introduce a new navigation route for search.
- Replace map focus, carousel sync, or people profile navigation behavior.
- Add unrelated visual refactors elsewhere on home.

## Approved Direction

The approved visual direction is:

- Palette: `Rose Mint Mist`
- Shape language: `Pressed Glass`
- Motion language: `Pulse Trace`

This means:

- The search experience expands into a full-screen surface with no visible home-page backdrop.
- The color system stays close to bubbles-page warmth, but gains a light mint haze under the blush tones to feel fresher and more current.
- Cards, chips, rows, and input chrome use reduced corner radii and cleaner panel geometry.
- Motion is present in the search surface itself rather than in large transitions or obvious decorative effects.

## Visual Design

### Overall Tone

- Light, premium, warm, and slightly atmospheric.
- Built from soft blush, cream, pale rose, and mint-tinted gradients rather than dark glass or sharp contrast.
- The overlay should read like a thin luminous layer sitting above the app, but it visually covers the entire viewport.
- Avoid showing the home map, carousel, or blurred home content behind the search UI.

### Full-Screen Surface

- Opening search transitions the header entry into a full-screen surface that covers the entire home screen.
- The screen should feel continuous with the header origin, but once open it behaves visually like its own page-sized layer.
- Use subtle vertical gradients and faint luminous mist shapes to create depth instead of exposing underlying content.
- The background treatment should feel airy and expensive, not like a standard modal sheet.

### Color System

- Base: warm off-white / cream background family.
- Primary tint: blush-rose highlights and accents.
- Secondary atmosphere: very soft mint haze to cool the composition slightly.
- Surfaces: translucent white and cream panels with restrained shadowing.
- Text and icons: muted rose-brown and softened plum neutrals rather than heavy black.

### Shape Language

- Move away from large rounded pills.
- Search field, filter chips, row containers, and cards use tightened radii to create a pressed-glass feel.
- The surface should still feel soft enough to belong near the bubbles page, but with more architectural control.
- Avoid perfect rectangles and avoid exaggerated roundness.

## Motion Design

### Approved Motion: Pulse Trace

Use a restrained motion system that makes the UI feel active:

- the search field gently breathes while active
- the currently loading or prioritized row can carry a faint pulse/highlight
- small live-status dots may pulse softly
- the inline typing caret can blink
- background mist shapes can drift very slowly

### Motion Constraints

- Motion should be low amplitude and low contrast.
- Avoid sweeping sheens across the whole screen.
- Avoid decorative animations that compete with search results.
- The surface should feel alive even when static, but never busy.

## Information Architecture

The search behavior remains the new homepage header search system already implemented:

- header tap opens search
- empty state shows recent and personalized suggestions
- typing triggers the progressive waterfall
- result families remain `Places`, `Natural language + Recommended`, and `People`
- row order still changes based on detected intent

The redesign is purely about how that system is surfaced visually and how its states are presented.

## Interaction Model

### Open / Close

- Tapping the homepage header search expands directly into the full-screen search surface.
- The open animation should feel continuous from the header field, but it should end in a fully covering layout.
- Dismissing search returns the user cleanly to home.

### Search Input

- The search field remains the dominant control at the top of the screen.
- Inline completion should still appear immediately and remain visually obvious.
- Supporting chips and suggestion elements should sit within the same full-screen visual system rather than feeling like floating modal fragments.

### Result Rows

- Rows should read as calm pressed-glass panels rather than bubbly capsules.
- The prioritized row may receive the subtle `Pulse Trace` emphasis while data is resolving or updating.
- Long-press map preview behavior remains, but the surface styling during preview should stay subtle and consistent with the new full-screen treatment.

## Implementation Boundaries

### Core Files

The redesign should stay focused on the existing search surface implementation:

- `lib/pages/home/widgets/home_header_search_shell.dart`
- any directly related home search presentation helpers under `lib/pages/home/search/`
- only minimal supporting updates elsewhere if required for animation/state wiring

### Behavior Preservation

Keep the current logic intact where possible:

- waterfall staging and cancellation
- recent-search store
- natural-language reuse
- DB-first place merging with Mapbox fallback
- place selection and map sync
- person selection and profile navigation

The redesign should be implemented as a presentation-layer refresh over the already-built logic.

## Testing Expectations

Update or add tests for the highest-signal visual/state behaviors:

- tapping the header search opens a full-screen search surface
- home content is no longer visually present in the search state
- inline completion remains visible before full rows
- intent-driven row ordering still behaves as before
- long-press preview still keeps search open
- any new animation/state hooks remain deterministic enough for widget tests

## Risks and Constraints

- The worktree already contains in-progress feature changes, so the redesign should avoid broad refactors.
- `.superpowers/` mockup files should not be included in the design commit.
- Full-screen visual coverage must not accidentally break the existing search interaction flow or gesture handling.
- Motion should be carefully tuned so it feels premium rather than noisy on lower-end devices.

## Success Criteria

The redesign is successful if:

- the search state feels like a dedicated full-screen premium surface
- the visual language feels related to the bubbles page without duplicating it exactly
- reduced radii make the interface feel cleaner and more intentional
- subtle motion makes the surface feel live without distracting from search
- the already-implemented predictive waterfall behavior continues to work unchanged
