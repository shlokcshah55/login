# Brag Plan: Pinit — "3 weeks later" (9:16 ad)

## What is this app?
Pinit is the save-and-decide layer on top of TikTok and Instagram: share a food video to it, it
pins the real restaurant, reminds you when you're nearby, and gets your friends to a decision.

## The angle
A single user story told entirely in the shipped UI. Every screen is the current code (HEAD,
after `41ee739` and `efbd8869`), not the older App Store screenshots. Copy on screen is verbatim
from the Flutter/Swift source. The headlines above the phone reuse Pinit's own App Store lines, so
the ad and the store listing read as one campaign.

Story: **1am TikTok → share to Pinit → three weeks later "Saved place nearby" → the creator's
words + Max's 8.0 / 10 → Magic Search "cute date spot near me" → send it to a Bubble.**

## Hook (0–3s)
Cold open on a vertical food video (HTacos loaded fries) inside a phone — the viewer recognises
their own feed before they see a logo. Headline: "Seen a spot on TikTok?"

## User flow worth showing (the whole video is the flow)
1. TikTok → iOS share sheet → **Pinit** → share-extension card *"Pinning this location... We will let you know when it is done."*
2. Push: **"Saved from TikTok" / "HTacos was added to your saves."**
3. Lock screen, 3 weeks later: **"Saved place nearby" / "HTacos is 200m away"** (real template: `'$name is ${m}m away'`).
4. Expanded place card: hero, coral **"Saved from @eat.snack.repeat’s TikTok"**, **HTacos** + **Been here?**, **FROM THIS TIKTOK / What they said**, Dishes mentioned → scroll → **Saved by friends** ("You + Max match 82% here") → **WHAT PEOPLE SAY / Reviews from your network** with Max's plum card **"8.0 / 10" · FRIEND**.
5. Home map (live Mapbox style) → coral search → **Suggested** panel → type **"cute date spot near me"** → **MAGIC SEARCH / Finding your spots...** → MATCH card with 87% badge and coral "Max saved" pill.
6. Send icon → **SEND TO BUBBLES / Share this place.** → pick **Date Night 🌹** → **SEND TO 1 BUBBLE** → bubble chat: **SHARED PLACE** card in an aubergine sent bubble, reply lands.
7. End card: logo + **"Find the good ones."**

## Tone
- Preset: `app-store` (feature-forward, clean slides) blended with `default` warmth
- Direction: "a real Saturday, filmed inside the app"
- Copy over the phone is App-Store style: coral tracked label + big Rova plum headline.

## Format: vertical — 1080x1920
## Duration: 31.5s
Over the 25s brag ceiling on purpose: the brief has six story beats and an ad needs a CTA card.
Note for placement: YouTube non-skippable in-stream caps at 15s (30s on some inventory);
TikTok/Reels/Stories placements accept 27s.

## Visual identity (from the code)
- Cream `#FBF6F3`, creamSunk `#F4EDE6`, creamDeep `#ECE2D8`, aubergine `#41133D`, aubergineSoft `#6B3866`, mute `#8A7A72`, accent `#EC3D2C`
- Rova (display), DM Sans (UI), Manrope (sheet/chat body), Material Icons / Feather / Cupertino icon fonts from the Flutter toolchain
- Hard offset plum shadows (3,3 / 4,4 / 5,5 / 10,5) exactly where the code uses them
- Map: static render of the live style `srishlok/cmlpttggl000p01rz51whgzk9`, Kensington

## Storyboard (31.5s, v2)
| # | Scene | Time | Headline |
|---|---|---|---|
| 1 | TikTok + share sheet | 0.0–2.9 | FROM THE FYP · "Seen a spot on TikTok?" |
| 2 | Share extension + saved push | 2.9–6.3 | TWO TAPS · "Share it to Pinit." |
| 3 | Lock screen, proximity push | 6.3–9.0 | 3 WEEKS LATER · "We'll remind you when you're near." |
| 4 | Expanded card: creator + Max 8.0/10 | 9.0–14.5 | "Hear what the creator said." → "And what your mates think." |
| 4b | Zoom out: every saved spot on the map | 14.5–17.5 | SAVED PLACES · "Every save, on one map." |
| 5 | Magic Search → fully populated result card | 17.5–25.0 | MAGIC SEARCH · "Any vibe, dish, or craving." |
| 6 | Share to Bubble → chat | 25.0–29.1 | BUBBLES · "Settle the group-chat debate." |
| 7 | End card (logo only) | 29.1–31.5 | "Stop losing the good ones." |

Interaction is simulated throughout with a tap ripple: share arrow, Pinit icon, OK, notification,
close, search bar, typed query (per-key ticks), card, send icon, bubble row, send button.

## Audio direction
- Music: `happy-beats-business-moves-vol-1` (120 BPM), ~0.32 bed, lift after the hook, fade over the last 0.8s.
- Cue guidance (bundled preset): beat grid ~0.5s; strong cues 18.02 (Magic Search results land), 22.01 (send to bubble), 25.02 (logo).
- SFX: soft clicks on taps, `bong_001` on each push notification, keypress ticks while typing, `card-slide-1` on sheets, `impactSoft_medium_001` on the "3 weeks later" jump, `impactBell_heavy_000` on the logo.
- Audio-reactive: subtle — background ring texture and phone glow breathe with RMS. No visualisers.

## Data decisions (flag to user)
- Hero venue **HTacos** (62-64 Kensington High St) — photos from the app's own image cache; the name is on the storefront and packaging.
- Date-spot venue name is a **placeholder** ("Petal & Pine") on a real cached interior photo whose venue couldn't be verified (Supabase lookup was blocked). Swap in `VENUES` before publishing.
- Friend "Max", creator "@eat.snack.repeat" (from the App Store art), bubble "Date Night 🌹" are demo data.

## Share copy (draft)
Saw it on TikTok at 1am. Pinit pinned it, reminded me three weeks later when I was 200m away, and sent it to the group chat. Find the good ones.
