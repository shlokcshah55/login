# Restaurant Expanded Card Structural Redesign Design

Date: 2026-04-08
Topic: Restaurant expanded card structural redesign
Status: Approved for spec review

## Context

The current expanded location card has already been visually extracted into section widgets, but its information architecture still reads as a long stack of similarly weighted modules:

- hero
- floating match banner
- name block
- quick stats
- actions
- about
- vibe
- dishes
- reviews
- details
- similar places

This makes the restaurant experience feel assembled from interchangeable parts rather than built around a clear page backbone. The user feedback is that the redesign problem is primarily structural, not stylistic. The card needs a more intentional layout that feels less AI-generated, less overcomposed, and less like a vertical list of mini-cards.

The approved direction is to redesign the restaurant expanded card as a two-part sheet with a persistent action dock. The emphasis is on better grouping, stronger hierarchy, and more stable actions, while keeping the app's existing behavior and overall visual language.

## Goals

- Redesign the restaurant expanded card around a clearer structure instead of adding more decorative styling.
- Reduce the sense of a long, equally weighted module stack.
- Make the restaurant identity and reason-to-go understandable within the first screenful.
- Keep the primary actions visible at all times through a persistent bottom dock.
- Reuse the existing expanded sheet shell, data sources, and interaction callbacks where possible.
- Preserve the app's paper-like feel and avoid introducing a layout that feels imported from another product.

## Non-Goals

- Replace the existing `DraggableScrollableSheet` interaction model.
- Redesign all expanded location cards for every place type in this pass.
- Rewrite save, dislike, review, similar-place, or match-calculation logic.
- Add tabbed navigation, route changes, or a second sticky header region.
- Resolve broader app styling questions; this spec is about layout and grouping first.

## Approved Direction

The approved layout direction is `Two-Part Sheet` with a persistent action dock.

This means:

- the hero remains at the top
- the top-of-card experience is simplified into a compact summary slab directly under the hero
- the existing floating match banner is absorbed into that summary instead of remaining a standalone block
- the rest of the card becomes a smaller number of larger editorial sections
- the primary actions stay pinned at the bottom of the sheet while the content scrolls behind them

The user specifically wants the redesign to prioritize structure over styling and wants `Save`, `Shortlist`, `Dislike`, `Add to Collection` and `Add to Bubble` to remain persistent.

## Information Architecture

### Top Layer: Hero

The hero remains the visual entry point but becomes simpler and less structurally noisy.

It should contain only:

- restaurant image carousel
- close button
- the highest-signal status items such as open/closed and price level

The hero should not introduce its own separate secondary card underneath it. The current floating match banner pattern is removed as a distinct layer.

### Second Layer: Summary Slab

Directly below the hero, the card introduces a single summary slab that acts as the page backbone. This slab replaces the current sequence of:

- `MatchBannerSection`
- `NameLocationSection`
- most of `QuickStatsSection`
- the non-persistent role currently played by `ActionsSection`

The summary slab should answer three questions immediately:

1. What place is this?
2. Why should I care?
3. What can I do with it?

The summary slab should contain:

- restaurant name
- tappable address / location line
- a compact cluster of key facts
- short match or reason-to-go copy
- enough contextual data to orient the user without requiring them to enter the long-scroll body

The match explanation moves here as supporting copy rather than appearing as a separate floating promo card.

### Third Layer: Editorial Body

Below the summary slab, the page becomes a smaller number of larger, intent-based content sections.

The approved section order is:

1. `Why go`
2. `What to get`
3. `Social proof`
4. `Practicals`

These map to the current implementation as follows.

`Why go`

- merges the current about content and the highest-value vibe/match rationale
- explains the place in human terms first
- may include a reduced version of vibe profile content where it supports the place narrative

`What to get`

- keeps recommended dishes and any menu-relevant highlights
- stays focused on order guidance rather than generic metadata

`Social proof`

- contains reviews
- contains similar-place recommendations when present
- groups social validation and recommendation depth into one zone instead of scattering them

`Practicals`

- contains directions, website, phone, hours, services, amenities, and other utility details
- sits at the end of the hierarchy so utility does not dominate the top half of the experience

## Interaction Model

### Persistent Action Dock

The bottom action row becomes a fixed dock inside the expanded sheet and remains visible while the body scrolls.

The dock contains:

- `Add to Bubble`
- `Save`
- `Shortlist`
- `Dislike`

Current assumption: `Shortlist` is the current collection action unless the naming or semantics are changed during implementation.

The persistent dock becomes the only location for these core actions. The actions should not also appear in the main scroll body.

### Scroll Behavior

The summary slab remains in normal scroll flow. It should not become sticky.

Rationale:

- the persistent action dock already creates one stable layer
- adding a second persistent layer would reduce usable vertical space
- keeping the summary in the flow preserves the natural sheet behavior already established elsewhere in the app

The scrollable content must include bottom inset sized to the persistent dock so the final section remains fully readable and tappable.

### First Screenful

The first visible portion of the expanded card should now read as one continuous scan:

- hero
- summary slab
- persistent action dock

This first screenful should give the user enough information to decide whether to act immediately or scroll for depth.

## Component Design

### Existing Shell To Keep

The redesign stays inside the existing expanded-card container and preserves:

- sheet entrance/exit animation
- backdrop behavior
- draggable sheet behavior
- close interaction

No new route or navigation model is introduced.

### Proposed Composition

For restaurant locations, the parent card should render a different internal composition than it does today.

Current high-level composition:

- `HeroSection`
- `MatchBannerSection`
- `NameLocationSection`
- `QuickStatsSection`
- `ActionsSection`
- remaining sections in a long vertical list

Proposed high-level composition:

- `HeroSection` reduced to hero-only responsibilities
- new `SummarySlabSection`
- scrollable editorial body with merged sections
- new `PersistentActionDock`

Likely section-level changes:

- `MatchBannerSection` removed or folded into summary rendering
- `NameLocationSection` removed or merged into summary rendering
- `QuickStatsSection` reduced and embedded inside summary
- `ActionsSection` removed from the scroll body and replaced by a dock-specific action component
- `AboutSection` and part of `VibeSection` regrouped into `WhyGoSection`
- `ReviewSection` and `SimilarPlacesSection` grouped under `SocialProofSection` composition
- `DetailsSection` retained near the end with minimal structural changes

This is a layout refactor with selective section merging, not a full rewrite of all child widgets.

### Restaurant-Only Scope

This redesign applies to restaurant-like locations only. Non-restaurant locations should continue using the existing expanded-card structure for now unless implementation reveals a trivial way to share part of the new layout safely.

Restaurant detection can reuse the same heuristics already used elsewhere in the card flow, such as restaurant types or cuisine presence.

## Data Flow And State

No new backend or derived-data pipeline is required.

The redesign should continue using the existing sources for:

- photo carousel state
- save state
- dislike state
- match calculation
- summary/editorial text
- vibe vector
- recommended dishes
- review loading and submission
- similar places lookup
- details links and phone actions

The main structural change is where this data is rendered, not how it is fetched or stored.

The persistent dock must preserve the current button behaviors:

- save loading state
- dislike loading state
- saved active state
- collection/shortlist action
- bubble action

## Error Handling And Degraded States

The redesign must degrade cleanly when restaurant data is sparse.

Requirements:

- if there is no match explanation, the summary slab still works with identity and key facts only
- if there are no recommended dishes, `What to get` collapses cleanly or is omitted
- if there are no reviews, `Social proof` still renders without broken spacing
- if there are no similar places, the social-proof group still works with reviews alone
- if there are no practical details, `Practicals` can shrink or disappear
- if image loading fails, the hero fallback still feels integrated with the new structure

The action dock must remain functional even when downstream content sections are absent.

## Implementation Boundaries

### Core Files

The redesign should primarily stay within:

- `lib/widgets/home/expanded_location_card.dart`
- `lib/widgets/home/expanded_card/sections/hero_section.dart`
- `lib/widgets/home/expanded_card/sections/actions_section.dart` or its replacement
- new section files for the summary slab and merged editorial groups

Supporting updates to existing section files are expected, but the work should stay focused on the restaurant expanded card path.

### Layout Strategy

The expected structure inside the sheet is:

- a stack or layered layout where the scroll body occupies the main area
- a safe-area-aware persistent dock anchored to the bottom
- explicit bottom padding in the scrollable content equal to the dock height plus breathing room

This should avoid content being hidden behind the dock and prevent the dock from visually fighting the scroll body.

## Testing Expectations

The redesign should be verified against the highest-signal structural behaviors:

- the restaurant expanded card still opens and closes correctly
- the persistent dock remains visible while the body scrolls
- the last section of content is fully visible above the dock
- save and dislike loading states still render correctly from the dock
- the summary slab still renders cleanly with sparse restaurant data
- shorter phone heights still allow the summary and dock to coexist without clipping
- non-restaurant locations remain unaffected if the redesign is gated by place type

Widget tests should be updated or added where practical for the dock and restaurant-specific composition.

## Risks And Constraints

- The card currently relies on several already-extracted sections, so the implementation should avoid accidental duplication while merging responsibilities.
- A persistent dock introduces overlap risk if bottom padding is not calculated carefully.
- The existing `DraggableScrollableSheet` behavior should not be destabilized by additional stacking and safe-area logic.
- Grouping sections into larger editorial blocks must not make sparse-data cases feel empty or broken.
- The redesign should not accidentally spread into a universal expanded-card rewrite unless that becomes clearly necessary.

## Success Criteria

The redesign is successful if:

- the restaurant expanded card no longer feels like a long stack of equal-weight modules
- the first screenful communicates place identity, reason-to-go, and available actions clearly
- the primary actions remain visible throughout the experience
- the lower content feels grouped by user intent rather than by raw data type
- the new layout feels more intentional and less AI-generated without depending on heavy visual styling tricks
- existing expanded-card behavior and data-driven functionality continue to work
