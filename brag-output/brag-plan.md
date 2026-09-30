# Brag Plan: Pinit

## What is this app?
Pinit is a social food-discovery app: you share a TikTok or Instagram reel into it, it extracts
the actual restaurants from the video, drops them on your map, and your friend group shortlists
and decides — with a literal **gavel** button to end the argument.

## The angle
Everyone recognises the group chat that cannot pick a restaurant. Pinit's own UI already contains
the punchline: a button labelled **GAVEL**, a sheet that says **"Just decide"**, and bubbles named
**"Midnight Munchies 🌙"**. The video does not invent a joke — it shows the real product and lets
the gavel land. Arc: *the chat stalls → a reel becomes real places → the map fills → the gavel ends it.*

Specific to this project and no other: the cream-and-aubergine design system (no other food app
looks like this), the real processing status chain ("Connecting to TikTok…"), the real bubble names,
and the GAVEL.

## Hook (first 2-3 seconds)
Three chat bubbles land on cream, one by one: **"where we eating?"** → **"idm"** → **"idm 🤷"**.
No voice, no logo, no product yet. Pure recognition. The hook is that the viewer has sent "idm"
this week. Then the room goes quiet and the product arrives.

## Key moments (the middle)
- The real status chain ticking through **"Connecting to TikTok…" → "Analyzing video content…" → "Finding locations…"**, resolving to **"Found 3 Locations"**.
- Three accent-red pins dropping onto the map one at a time, the **Shortlist** pill counting **1 → 2 → 3**.
- The bubbles list sliding in with the app's own names: **Midnight Munchies 🌙 / Date Night 🌹 / Drinks Up 🍻**, under a tracked **YOUR BUBBLES** label.
- The **GAVEL** tap — one hard knock, three shortlisted places collapse to one.

## Outro / punchline
The gavel knocks. The shortlist collapses to a single card. Cut to the Pinit logo on cream:
**"Somebody had to decide."**

## User flow worth showing
Real flow, and it is the centerpiece (Scenes 2-5):
1. **Entry** — share a reel into Pinit; it processes the video.
2. **Key action** — extracted restaurants pin onto your map; the group shortlists them in a bubble.
3. **Result** — hit GAVEL; one place, decided.

## Tone
- Preset: `default`
- Creative direction: "the group chat finally shuts up" — premium and warm, with group-chat wit in the copy
- Interpretation: Comfortable 5-6 scene rhythm with room to breathe; copy stays short, lowercase-casual in the chat and editorial-oversized in the product beats. The humour comes from real UI labels, never from jokes written over the product. Polished, never chaotic — restraint is the brand.

## Format: landscape — 1920x1080
## Duration: target 21s

## Visual identity (from the project)
Source of truth is `Style.MD` + `lib/themes/` (the shipped design system is **cream-first**, not the
dark-purple the marketing doc describes — follow the code).
- Background: `#fbf6f3` (cream); surfaces `#f4ede6` (cream-sunk), dividers `#ece2d8` (cream-deep)
- Accent: `#ec3d2c` — map pins, the GAVEL hit, notification dots. **Must stay under 10% of any frame.**
- Text: `#41133d` (aubergine) primary; `#6b3866` (aubergine-soft) secondary; `#8a7a72` (mute) tertiary
- Display font: **Rova** (`rova-font/RovaRegular-5yV0a.ttf`) — oversized, w800, tight tracking
- Body font: **Manrope** (`assets/fonts/Manrope-VF.ttf`); **DM Sans** (Google Fonts) for UPPERCASE tracked labels at 11px, tracking = fontSize x 0.12
- Strongest visual element: oversized aubergine Rova display type on cream, with a single scarce accent-red pin. Never pure black, never pure white, never pure grey.
- Logo: `lib/assets/logo-transparent.png`

## Share copy (draft)
Your gc has 200 saved food reels and still says "idm". So I built a map that remembers them — and a gavel that ends the argument.

## Audio direction
- Role: warm bed with motion-matched accents
- Music: `happy-beats-business-moves-vol-11-by-ende-dot-app.mp3` — 114.84 BPM, confident and warm, not corporate
- Music treatment: start at 0.0s, quiet under the hook (~35%), lift on the product reveal (~70%), full through the map and bubbles, duck ~200ms under the gavel knock so the knock is the loudest single moment, fade out over the last 0.8s of the logo card
- Music cue guidance: preset read from `assets/music/cues/…vol-11…music-cues.md`. Strong cues to target — **1.60s** (hook's third chat bubble), **3.70s** (product reveal / first status), **8.96s** (first map pin), **12.65s** (bubbles list). Beat grid ~0.525s; sequential TEXT snaps to **every other beat (~1.05s)**, never every beat. Gavel knock targets the **17.39s** grid beat.
- Audio-reactive treatment: subtle — use music RMS to let the cream background warmth and the product card's shadow presence breathe. No waveform, equalizer, or visualizer graphics.
- SFX posture: sparse-to-moderate, motion-matched, professional restraint. Soft interface tick per chat bubble and per status line; a distinct pin-drop per map pin; one card sound per bubble row; one dry heavy impact for the gavel.
- Audio-coupled moments: chat bubbles arriving; status chain ticking; the three pins dropping; the shortlist counter incrementing; the GAVEL tap.
- Restraint rule: only **one** loud moment in the whole video — the gavel. Nothing else competes with it. No sound on the logo card except the music fade. No SFX layered more than one at a time.

## Storyboard

### Scene 1 — the group chat — 3.5s
Cream canvas. Three chat bubbles in Manrope arrive one by one, left-aligned, cream-sunk surfaces:
**"where we eating?"**, **"idm"**, **"idm 🤷"**. No product, no logo. After the third, all three hold
on screen in silence for ~1.0s — the pause is the joke.
Sequential/interaction: yes — 3 bubbles arrive one by one on every-other-beat (~0.40s, 1.05s, 1.60s), each with a soft interface tick; full set holds to 3.5s so every line clears its 0.8s read floor.
Audio intent: quiet, almost empty. Music barely present. The ticks are the only texture.
Audio-coupled idea: bubble arrivals on the beat grid; third bubble lands on the 1.60s strong cue.
Music: warm bed, held low (~35%).
Transition mood: clean → Scene 2

### Scene 2 — a reel becomes real places — 4.5s
Phone frame, cream-sunk, centered on cream. A reel thumbnail is shared in. The app's **real** status
chain appears in sequence: **"Connecting to TikTok…"** → **"Analyzing video content…"** →
**"Finding locations…"**, each replacing the last, then resolving to **"Found 3 Locations"** in Rova
title with an accent dot. Small tracked label **PROCESSING URL** above.
Sequential/interaction: yes — simulate the share, then 3 status lines at ~0.85s each (every-other-beat), then "Found 3 Locations" holds ~1.6s. Each status is 2-3 words and clears its read floor.
Audio intent: momentum building — something is actually happening.
Audio-coupled idea: one soft tick per status line; a warmer confirm tone on "Found 3 Locations".
Music: lifts to ~70% on the 3.70s strong cue as the first status appears.
Transition mood: clean → Scene 3

### Scene 3 — your map fills up — 4.0s
Map view in the app's cream map style. Three accent-red (`#ec3d2c`) pins drop in one at a time, each
with a small Rova title card naming a restaurant. Tracked **NEARBY** label top-left. The
**Shortlist (1) → (2) → (3)** pill increments with each pin. Accent stays scarce — pins only.
Sequential/interaction: yes — 3 pin drops on every-other-beat starting at the 8.96s strong cue; the shortlist counter increments on each drop.
Audio intent: satisfying, tactile accumulation.
Audio-coupled idea: distinct pin-drop SFX per pin; tiny counter tick on each shortlist increment.
Music: full, confident.
Transition mood: clean slide → Scene 4

### Scene 4 — the bubble — 3.5s
Bubbles list on cream. Tracked **YOUR BUBBLES** label. Three rows slide in one by one using the app's
own names: **Midnight Munchies 🌙**, **Date Night 🌹**, **Drinks Up 🍻**, each a cream-sunk row with a
Rova title. Full set holds ~1.0s.
Sequential/interaction: yes — 3 rows one by one on every-other-beat from the 12.65s strong cue, each with a soft card sound; set holds so all three names are readable.
Audio intent: social warmth — this is the friend-group beat.
Audio-coupled idea: card sound per row arrival.
Music: full, warm.
Transition mood: clean → Scene 5

### Scene 5 — GAVEL — 3.5s
The shortlist of three sits on screen. A simulated tap hits the **GAVEL** button (accent-red). One hard
knock. On impact the three cards collapse to a **single** aubergine card — one restaurant, decided —
with the app's real line **"Just decide"** above it in tracked label type. Brief accent flash on impact,
then stillness.
Sequential/interaction: yes — simulate a tap on the GAVEL button, then collapse 3 cards to 1 on the impact frame.
Audio intent: the release. The single loudest moment in the video. Music ducks ~200ms so the knock lands alone.
Audio-coupled idea: one dry heavy impact SFX on the tap, timed to the 17.39s grid beat.
Music: ducked under the knock, then back up.
Transition mood: clean → Scene 6

### Scene 6 — end card — 2.0s
Pinit logo (`lib/assets/logo-transparent.png`) centered on cream. Beneath it, in Rova display:
**"Somebody had to decide."** Still, generous whitespace. This frame is the poster candidate.
Sequential/interaction: none — deliberate stillness after the knock.
Audio intent: settle and release; music fades over the final 0.8s.
Audio-coupled idea: none — no SFX on the logo card.
Music: fade to silence.
Transition mood: hold to end

**Total: 3.5 + 4.5 + 4.0 + 3.5 + 3.5 + 2.0 = 21.0s**

**Music mood for this video:** upbeat but warm — confident, social, not corporate.
**Audio summary:** Near-silence under the group-chat hook, a steady warm lift as the reel resolves into real places, tactile motion-matched accents through the map and bubbles, one dry gavel knock as the only loud moment, then a clean fade on the logo.

---

## Built deltas (what shipped vs. this plan)

The storyboard above is the creative contract; these are the changes made during
composition, and why. Final render is 21.0s, as planned.

- **Scene 2's status chain is an accumulating log, not a swap.** Stacking the three
  lines in one slot made them collide mid-crossfade, and swapping them left each
  line only ~0.44s of settled time — under the read floor. They now stack as three
  rows and dim as they complete: no overlap, full read time, and closer to what a
  real processing UI shows.
- **Scene 4 lengthened to 3.8s, Scene 5 shortened to 3.2s.** Needed so the third
  bubble row (14.76s beat) still gets its ~1.0s hold before the cut. Total unchanged.
- **Chat bubbles land at 0.30 / 1.075 / 2.12s** (plan guessed 0.40 / 1.05 / 1.60).
  The bubbles accumulate rather than replace, so the read floor is satisfied by the
  1.38s full-set hold; the first lands on natural timing to avoid opening on dead air.
- **Scene 4's accent notification dot was cut.** Style.MD allows at most two accent
  elements per screen, and the scene already gets its colour from the emoji. Keeping
  accent to the map pins and the GAVEL makes the punchline hit harder.
- **All Scene 3 pin tags are `mute`, including "Wavy".** Style.MD assigns accent to
  the wavy tag, but three accent pins plus an accent tag on one screen breaks the
  same two-element rule. The pins own the accent in that scene.
- **Naria added as Rova's glyph fallback.** Rova ships no numerals, so "Found 3
  Locations" fell back to a generic serif. Wiring Naria is exactly what Style.MD
  prescribes, and the "3" now matches Rova's weight.
- **"Kin Café" → "Kin Cafe".** Neither Rova nor Naria carries the diacritic, so it
  rendered in a third fallback face.
- **Pin-drop SFX cut from 0.60 to 0.44.** At 0.60 the map peaked at −2.0 dB against
  the gavel's −1.6 dB — technically quieter but perceptually equal, which broke the
  "only one loud moment" restraint rule. The gavel now sits 1.8 dB clear.
