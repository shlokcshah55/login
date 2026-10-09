# Hyperframes Composition Brief: Pinit — "3 weeks later"

## Objective
A 9:16 unskippable-style ad that tells one Pinit user story inside a pixel-faithful recreation of the shipped app.

## Output
- Composition: `brag-output-2026-10-04-103921/composition/`
- Render: `brag-output-2026-10-04-103921/brag.mp4`
- Format: vertical 1080x1920, 30fps, 27s

## Source material (authoritative)
- `lib/pages/profile/widgets/pinit_colors.dart` (palette), `lib/themes/app_typography.dart`
- `ios/URLShareExtension/ShareViewController.swift` (share card), `api/social-free-processor/notifications.py` (saved push)
- `lib/services/push_notification_service.dart` (proximity push: "Saved place nearby" / "$name is ${m}m away")
- `lib/widgets/home/expanded_location_card.dart` + `expanded_card/sections/*` (place sheet, HEAD layout: hero 0.26·H, address/stats/match hidden)
- `lib/pages/home/widgets/home_header_search_shell.dart`, `mode_toggle.dart`, `magic_search_suggestions.dart`, `location_carousel.dart`, `bottom_nav_bar.dart`, `lib/models/markers.dart`
- `lib/widgets/home/expanded_card/add_to_bubble_sheet.dart`, `lib/pages/bubble_messaging_page.dart`, `lib/widgets/chat/*`

## Verbatim copy
Pinning this location...\nWe will let you know when it is done. · OK · Saved from TikTok · HTacos was added to your saves. ·
Saved place nearby · HTacos is 200m away · Saved from @eat.snack.repeat’s TikTok · Been here? · FROM THIS TIKTOK · What they said ·
Dishes mentioned · Seen on TikTok · Saved by friends · You + Max match 82% here · WHAT PEOPLE SAY · Reviews · from your network ·
8.0 / 10 · FRIEND · SEARCH FOR A VIBE, DISH OR SOMETHING YOU ARE FEELING · SAVED · PICKS · EAT-LISTS · Suggested · Sweet treat nearby ·
Dinner date spot · Cocktails + small plates · MAGIC SEARCH · Finding your spots... · Search this area · MATCH · Max saved · See All ·
SEND TO BUBBLES · Share this place. · Add a note for the bubble · SEND TO 1 BUBBLE · BUBBLE CHAT · 2 members · 1 PINS · MESSAGES ·
SHARED PLACE · Add a message · Save / Saved · Eat-List

## Creative direction
See `brag-plan.md`. App-Store framing (coral tracked label + Rova plum headline above a gold-edged phone on cream).

## Audio
Music vol-1 bed (0.30–0.36), SFX matched to simulated taps/notifications/typing/sheets, one bell on the logo.
Cue preset: `assets/music/cues.json`. Audio-reactive RMS pre-extracted to `assets/audio-data.js` (ffmpeg astats; numpy unavailable).

## Hyperframes
Standalone composition, one paused GSAP timeline at `window.__timelines["main"]`. Only audio elements are timed clips;
screens are persistent layers animated by the timeline (seek-safe). Gate: `npx hyperframes check`.
