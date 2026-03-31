---
name: pinit_flutter_ui
description: Use this skill when designing or modifying Flutter UI for Pinit. This skill enforces premium, human-feeling, gesture-first, animation-centric mobile design that feels natural rather than AI-generated. Apply it for screens, components, flows, motion, layout, interaction patterns, and visual refinement.
---

# Pinit Flutter UI Skill

You are designing for **Pinit**, a consumer mobile app centered around places, recommendations, maps, discovery, saving, planning, and social context.

Your job is not just to make screens "look good". Your job is to make them feel:
- premium
- effortless
- tactile
- human
- modern
- calm
- intentional
- not templated
- not “AI-generated”

The design should feel like a product crafted by a strong mobile product/design team, not a generated dashboard.

---

# Core design intent

Pinit UI must feel:
- **gesture-first**, not button-first
- **animation-centric**, but restrained
- **map-native**, not form-heavy
- **editorial and spatial**, not generic
- **human and soft**, not rigid and robotic
- **confidently minimal**, not empty
- **premium**, not flashy
- **playful in micro-interactions**, not childish

The UI should support fast, intuitive place discovery and decision-making.

---

# The anti-AI rule

Avoid anything that makes the UI feel generated, generic, or overly systemised.

Do **not** produce:
- repetitive card grids with identical spacing everywhere
- random gradients
- too many floating buttons
- oversized pills with no hierarchy
- excessive glassmorphism
- overly symmetrical layouts with no focal point
- screens that feel like “widgets placed on a canvas”
- too much text explanation in the interface
- obvious “Dribbble-only” decoration with weak usability
- unnecessary borders around everything
- default Material-feeling composition with no product identity

Every screen should have:
- a clear focal point
- clear primary action hierarchy
- intentional density
- visual rhythm
- at least one interaction detail that feels crafted

---

# Product-specific design principles

## 1. Map is primary
Pinit is fundamentally spatial. The map should usually feel like the base layer of the experience, even when secondary UI sits on top.

Use map-first thinking:
- sheets
- overlays
- peeking carousels
- contextual chips
- draggable panels
- animated focus transitions
- pin emphasis
- clustered spatial context

Do not bury the map beneath dense UI chrome.

## 2. Search should feel fluid
Search in Pinit is not just a text field. It is a core mode switch for intent.

Search should support:
- natural language intent
- place lookup
- person lookup
- fast refinement
- continuation from current map context
- recent/suggested actions

Search entry should feel immediate and lightweight, not like entering a form workflow.

## 3. Saving and shortlisting should feel satisfying
Saving a place should feel emotionally rewarding and fast.

Shortlisting should feel like:
- “I’m considering this for now”
- low-commitment
- lightweight
- easy to undo
- useful in planning flows

Use motion, feedback, and state transitions to make saving/shortlisting feel tactile.

## 4. Social context should feel ambient
Friends, overlap, who saved what, and social proof should appear naturally in the UI.

Avoid noisy social UI.
Prefer:
- subtle avatars
- soft attribution rows
- compact overlap indicators
- lightweight inline explanations

---

# Interaction model

Pinit should be **gesture-first**.

Prefer:
- swipe
- drag
- pull
- scrub
- peek
- expand
- collapse
- long-press
- press-and-hold previews
- momentum-based transitions

Do not rely on rows of static tap targets when a gesture would feel more natural.

But:
- gestures must always be discoverable
- there must be fallback tap affordances
- interactions must remain accessible and predictable

For every feature, ask:
1. what is the most natural direct manipulation model?
2. can the user preview before committing?
3. can motion explain the state change?

---

# Motion principles

Animation is mandatory, but must be purposeful.

Use animation to:
- preserve context
- explain hierarchy changes
- show cause and effect
- reward action
- make the interface feel alive

Do not animate for decoration only.

## Motion style
Motion should feel:
- smooth
- slightly soft
- springy but controlled
- fast enough to feel responsive
- never bouncy in a toy-like way

## Preferred motion patterns
- shared element transitions
- bottom-sheet expansion
- map-to-card focus transitions
- pin lift/focus animations
- chip selection movement
- subtle opacity + blur transitions
- staged entrance animations
- micro-scale feedback on press
- saved/shortlisted confirmation motion

## Avoid
- slow cinematic animations
- excessive stagger everywhere
- large elastic bounce
- over-rotation
- flashy parallax for no reason
- too many simultaneous moving elements

---

# Visual design system

## Overall tone
Premium, warm, understated, tactile.

## Shape language
Prefer:
- soft corners
- elegant radii
- layered surfaces
- clean silhouettes
- subtle depth

Avoid:
- sharp harsh boxes unless intentional
- inconsistent radius usage
- excessive outlines
- crowded stacked containers

## Depth
Depth should be created with:
- layering
- elevation
- shadow restraint
- scale shifts
- blur selectively
- edge contrast

Do not overuse shadows. Premium mobile UI usually uses fewer, better shadows.

## Color
Use color intentionally.
Color should encode:
- meaning
- emphasis
- state
- category
- delight

Avoid loud multicolor UIs unless explicitly justified.
Prefer a refined palette with one clear accent system.

## Typography
Typography should feel editorial and product-grade.
Use strong hierarchy:
- concise headers
- compact supporting copy
- very limited paragraph text
- excellent spacing
- avoid clutter

Do not use large quantities of helper text.

---

# Layout rules

## Compose screens like product surfaces, not documents
Use:
- anchored overlays
- panels
- carousels
- edge-aware spacing
- asymmetry where useful
- visible focal hierarchy

Avoid:
- generic vertically stacked sections
- too many full-width cards
- everything boxed separately
- excessive padding that wastes space

## Density
Premium mobile apps are often moderately dense, not empty.
Aim for:
- enough air to feel calm
- enough information to feel useful
- controlled compression on high-value surfaces

## Safe areas
Respect them, but do not let them create awkward floating gaps.

## Reachability
Primary actions should generally sit in comfortable thumb zones.
Important map/search/planning interactions must feel one-hand usable.

---

# Component guidance for Pinit

## Search bar
The search bar should feel like a command surface, not a form field.
It may support:
- placeholder that invites natural language
- contextual suggestion chips
- recent searches
- nearby / friends / shortlist shortcuts
- animated morph into expanded search mode

It should visually integrate with the map and home composition.

## Floating actions
Use very sparingly.
Do not scatter multiple unrelated FABs around the screen.
If multiple quick actions exist:
- group them
- dock them
- merge them into a smarter surface
- or embed them into a contextual sheet

## Sheets and drawers
Bottom sheets are a strong fit for Pinit.
They should:
- peek useful content
- resize naturally
- preserve map context
- have elegant drag behaviour
- use motion to clarify state

## Cards
Cards should not all look the same.
Vary by priority:
- hero card
- recommendation card
- shortlist item
- friend activity item
- place preview

Use consistent language, but avoid cloned repetition.

## Chips
Chips are good for:
- taste filters
- vibe filters
- distance
- open now
- social overlays
- shortlist state

Chips should feel tactile and compact, not bloated.

---

# Flutter implementation rules

All UI work should be production-quality Flutter code, not mock-style code.

## General
- Prefer clean composition over giant build methods
- Extract reusable widgets where it improves clarity
- Keep widget APIs intentional and minimal
- Preserve existing architecture unless change is justified
- Respect app theming and token systems if present
- Avoid introducing visual hacks unless necessary

## Animation in Flutter
Prefer:
- `AnimatedContainer`
- `AnimatedOpacity`
- `AnimatedScale`
- `AnimatedSlide`
- `TweenAnimationBuilder`
- `AnimationController` when choreography needs precision
- `Hero` for continuity
- spring curves and well-chosen easing

Use explicit animation only when it adds clarity or delight.

## Gestures in Flutter
Prefer:
- `GestureDetector`
- `InkWell` only when Material ripple is appropriate
- drag-aware widgets for sheets/carousels
- custom gesture handling only when justified

Do not force Material defaults if they hurt the desired product feel.

## Performance
Premium feel requires performance.
Always avoid:
- janky scroll interactions
- rebuild-heavy animation
- oversized widget trees for simple components
- unnecessary opacity layers
- too many blur effects
- expensive map overlays without thought

Designs must remain smooth on real mobile devices.

---

# UX quality bar

Every UI proposal or implementation must satisfy these questions:

1. Does this feel like a real consumer product?
2. Does it feel mobile-native?
3. Does it feel crafted rather than assembled?
4. Does the motion clarify the experience?
5. Does the layout have a clear focal point?
6. Are there too many buttons?
7. Is there a more natural gesture-driven version?
8. Does it preserve map context?
9. Does it feel premium without becoming sterile?
10. Would a strong designer be embarrassed by this screen?

If the answer to the last question is yes or maybe, redesign it.

---

# Required design workflow for the agent

When asked to design or modify a Pinit UI, always follow this process:

## Step 1: Understand intent
Identify:
- primary user goal
- screen hierarchy
- core interaction loop
- what should feel instant
- what should feel delightful

## Step 2: Define interaction model
Before writing code, decide:
- what is tap-based
- what is drag-based
- what animates
- where the focal point is
- how the user enters and exits the flow

## Step 3: Design for hierarchy
Choose:
- primary surface
- secondary surface
- persistent actions
- transient actions
- contextual information

## Step 4: Implement with polish
Add:
- motion
- tactile feedback
- good spacing rhythm
- visual restraint
- state clarity

## Step 5: Critique your own result
Explicitly check for:
- generic AI-looking composition
- overuse of pills/cards/buttons
- excessive symmetry
- unclear hierarchy
- too much UI chrome
- insufficient motion
- motion overkill
- weak thumb ergonomics

Then refine before final output.

---

# Output expectations for any agent using this skill

When producing design/code output:
- explain the interaction model briefly
- explain why the hierarchy works
- explain the motion choices
- explain how the design avoids feeling generic
- provide production-ready Flutter code when implementation is requested

Do not just dump a widget tree with no rationale.

---

# Preferred design adjectives

Use these as guardrails:
- premium
- soft
- tactile
- fluid
- spatial
- elegant
- calm
- human
- intentional
- lively
- understated

Avoid drifting into:
- gimmicky
- flashy
- noisy
- corporate
- sterile
- childish
- hyper-minimal to the point of uselessness

---

# Pinit-specific anti-patterns

Do not:
- turn the app into a food delivery clone
- make every action a large bright button
- overexpose admin/data-heavy UI
- make home feel like a dashboard
- drown the map in panels
- create search that behaves like a settings page
- overload users with recommendation metadata
- build social features that feel spammy
- make shortlist/planning feel like project management software

---

# Example design direction

A strong Pinit screen often includes:
- full-bleed or dominant map context
- one high-quality top command surface
- one peeking planning/recommendation layer
- compact contextual chips
- subtle social signals
- a carefully chosen motion system
- one or two strong moments of delight

That is usually better than six independently competing widgets.

---

# Final instruction

When in doubt, simplify the number of visible controls, strengthen hierarchy, preserve spatial context, and improve motion quality.

The result should feel like a premium mobile product designed by humans who care deeply about interaction quality.