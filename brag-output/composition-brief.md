# Hyperframes Composition Brief: Pinit

## Objective
Create a short launch-style brag video for Pinit — a social food-discovery app that turns saved
TikToks into a shared restaurant map, and settles the group-chat argument with a GAVEL button.

## Output
- Composition directory: `brag-output/composition/`
- Rendered video: `brag-output/brag.mp4`
- Format: landscape — 1920x1080
- Duration: 21 seconds

## Source Material
- Project root: `/Users/shlok/Documents/Pinit/login` (Flutter app)
- Primary files read: `Style.MD` (design system — authoritative), `lib/themes/pinit_colors.dart`,
  `lib/pages/social_review/`, `lib/widgets/url_processing_popover.dart`, `lib/pages/home/widgets/`
  (gavel, decide, shortlist, magic search), `lib/pages/bubbles/`, `pubspec.yaml`
- Product name: **Pinit**
- Tagline / strongest claim: "Save spots. Share plans. Decide faster." — but the strongest *real*
  material is the app's own GAVEL button and its "Just decide" sheet.
- Key UI moment to recreate: the **URL processing status chain** resolving into found restaurants,
  then the **map with accent-red pins**, then the **GAVEL** tap collapsing a shortlist to one place.

- Copy that must appear verbatim (all of it is real product/chat copy):
  - `where we eating?` / `idm` / `idm 🤷`  (the hook — group-chat vernacular, not product copy)
  - `Connecting to TikTok...`
  - `Analyzing video content...`
  - `Finding locations...`
  - `Found 3 Locations`
  - `PROCESSING URL`
  - `NEARBY`
  - `Shortlist (1)` → `Shortlist (2)` → `Shortlist (3)`
  - `YOUR BUBBLES`
  - `Midnight Munchies 🌙` / `Date Night 🌹` / `Drinks Up 🍻`
  - `GAVEL`
  - `Just decide`
  - `Somebody had to decide.`

## Creative Direction
- Tone preset: `default`
- Creative direction: "the group chat finally shuts up"
- Interpretation: Comfortable 6-beat rhythm with room to breathe. Copy stays short — lowercase and
  casual in the chat hook, editorial and oversized in the product beats. Humour comes only from real
  UI labels (a literal GAVEL button), never from jokes written over the product. Polished, never
  chaotic; restraint is the brand.
- Angle: Everyone recognises the group chat that cannot pick a restaurant. Pinit's own UI already
  contains the punchline — a button labelled GAVEL, a sheet that says "Just decide", and bubbles
  named "Midnight Munchies 🌙". The video shows the real product and lets the gavel land. Arc: the
  chat stalls → a reel becomes real places → the map fills → the gavel ends it.
- Hook: three chat bubbles land on cream one by one — "where we eating?", "idm", "idm 🤷" — then hold
  in silence. No product, no logo. Pure recognition.
- Outro / punchline: the gavel knocks, the shortlist collapses to one card, cut to the Pinit logo on
  cream with "Somebody had to decide."
- Avoid:
  - Generic SaaS language
  - Abstract filler visuals
  - Unrelated visual redesign
  - The dark-purple palette from the marketing doc — the **shipped** design system is cream-first.
    `Style.MD` is the truth here.

## Visual Identity
Authoritative source: `Style.MD` ("commit to extremes" — heavy display type, generous whitespace,
tightly restricted palette).
- Background: `#fbf6f3` (cream). Surfaces `#f4ede6` (cream-sunk). Dividers/pressed `#ece2d8` (cream-deep).
- Text: `#41133d` (aubergine) primary · `#6b3866` (aubergine-soft) secondary · `#8a7a72` (mute) tertiary
- Accent: `#ec3d2c` — map pins, the GAVEL, notification dots. **Under 10% of any frame. The accent is
  a guest, not a resident.**
- Display font: **Rova** — ship `rova-font/RovaRegular-5yV0a.ttf` into the composition and declare
  `@font-face`. Oversized, tight tracking. Used for all headlines and titles.
- Body font: **Manrope** — ship `assets/fonts/Manrope-VF.ttf` and declare `@font-face`. Body copy and
  chat bubbles. For UPPERCASE tracked labels, use Manrope at `letter-spacing: fontSize x 0.12`
  (the app uses DM Sans here; Manrope is the shipped local file and reads the same at label size).
- Visual references from the project:
  - `lib/assets/logo-transparent.png` — the end card logo
  - Fully-rounded pill shapes, cream-sunk cards, uppercase tracked micro-labels
  - Never pure black, never pure white, never pure grey (use `mute` for warm neutrals)

## Storyboard
Use the storyboard in `brag-output/brag-plan.md` as the creative contract.

Scene summary:
1. **the group chat** — 3.5s — three chat bubbles arrive one by one, then the full set holds. Must read: "where we eating?", "idm", "idm 🤷"
2. **a reel becomes real places** — 4.5s — phone frame; real status chain ticks through, resolves to "Found 3 Locations" under a "PROCESSING URL" label
3. **your map fills up** — 4.0s — 3 accent-red pins drop one at a time with restaurant name cards; "NEARBY" label; Shortlist pill counts 1→2→3
4. **the bubble** — 3.5s — "YOUR BUBBLES" label; three real bubble rows slide in one by one, set holds
5. **GAVEL** — 3.5s — simulated tap on the accent-red GAVEL button; on impact three cards collapse to one decided restaurant; "Just decide" above
6. **end card** — 2.0s — Pinit logo on cream + "Somebody had to decide." Poster-frame candidate.

## Audio
- Audio role: warm bed with motion-matched accents
- Audio arc: near-silence under the group-chat hook → steady warm lift as the reel resolves into real
  places → tactile accents through the map and bubbles → one dry gavel knock as the only loud moment
  → clean fade on the logo.
- Music: `happy-beats-business-moves-vol-11-by-ende-dot-app.mp3` (114.84 BPM, warm and confident)
- Music treatment: start 0.0s. ~35% under the hook, lift to ~70% on the product reveal, full through
  map and bubbles, **duck ~200ms under the gavel knock** so the knock is the loudest single moment,
  then fade out across the last 0.8s of the logo card.
- Music cue guidance: bundled preset at
  `<brag-assets>/music/cues/happy-beats-business-moves-vol-11-by-ende-dot-app.music-cues.md`.
  Strong cues to target: **1.60s** (third chat bubble), **3.70s** (product reveal / first status),
  **8.96s** (first map pin), **12.65s** (first bubble row). Beat grid ~0.525s — sequential **text**
  snaps to **every other beat (~1.05s)**, never every beat. Gavel knock targets the 17.39s grid beat.
  Lock 3-4 strong cues total; use natural timing anywhere a cue would hurt readability.
- Audio-reactive treatment: **subtle** — use RMS/bass to let the cream background warmth and the
  product card's shadow presence breathe (3-6% on anything carrying text). No waveform, equalizer,
  spectrum, or musical-note graphics.
- Audio-coupled moments:
  - Scene 1, each chat bubble — beat-grid reveal + soft interface tick
  - Scene 2, each status line — sequential tick; warmer confirm cue on "Found 3 Locations"
  - Scene 3, each pin drop — beat-grid reveal + distinct pin-drop SFX; counter tick on each Shortlist increment
  - Scene 4, each bubble row — beat-grid reveal + card sound
  - Scene 5, the GAVEL tap — simulated interaction + one dry heavy impact, music ducked
  - Scene 6, logo — no SFX; music fade only
- SFX selection guidance: sparse-to-moderate and motion-matched. Card sounds for card-like reveals,
  a short announcement cue for the "Found 3 Locations" payoff, soft interface ticks for status lines
  and chat bubbles, one heavy impact for the gavel. Sound and motion land on the same timestamp.
- SFX analysis guidance: read `<brag-assets>/sfx/sfx-analysis.md` before choosing files. Prefer
  **low/medium high-frequency risk** files — the ticks repeat five-plus times and must not get shrill.
- Exact SFX choice: Hyperframes chooses filenames, timestamps, density, and volume based on the
  implemented animation.
- Audio files: copy the chosen music and all selected SFX into `brag-output/composition/assets/`.
  Paths in the HTML are relative to `composition/`. Never absolute.

## Hyperframes Instructions
Load the composition-building domain skills — `hyperframes-core` (composition contract + `data-*`
timing), `hyperframes-animation` (motion), `hyperframes-creative` (design spec, beats,
audio-reactive), `hyperframes-keyframes` (seek-safe keyframes), `hyperframes-cli` (lint/check/render).
This is the `/brag` workflow: do **not** enter the `hyperframes` entry-point intent interview and do
**not** route into the generic promo / launch-video workflow. Prefer native Hyperframes conventions.

Requirements:
- Show at least one real UI, copy, or visual element from the source project. (Several, per storyboard.)
- Keep all text readable in the final render. Reading floor: short label ~0.8s settled, sentence
  ~0.3s/word. Sequential text holds the full set on screen afterward.
- Keep the video within 15-25 seconds (target 21s).
- Include the planned music/SFX layer.
- Treat `/brag` audio notes as guidance, not a fixed cue sheet. Choose SFX after the animation exists.
- Treat music cue metadata as optional timing hints; ignore cues that hurt readability or pacing.
  Major reveals may move to a nearby strong cue within ~0.15s; smaller entrances to a nearby beat
  within ~0.10s. Mark them `// beat-locked:` and `// beat-grid:`.
- Honor the planned music treatment — the gavel duck and the closing fade especially.
- Use local assets for audio, fonts, logo, and any runtime dependency.
- Run `npx hyperframes check` before render — it is brag's single gate.

### Environment note
`node` is not on PATH in this shell (mise has no global version set). Prefix every CLI call:
`mise exec node@22.22.0 -- npx hyperframes ...`
