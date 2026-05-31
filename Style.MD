# pinit — Design System

A reference for pinit's UI. The **profile page** is the canonical style reference — all screens should feel consistent with it. This document defines the visual language: typography, colour, spacing, shape, shadows, and component patterns.

The guiding principle: **commit to extremes**. Vibe-coded UIs hedge with medium weights, medium radii, medium spacing, and medium contrast. This system commits — heavy display type, generous whitespace, fully rounded shapes, and a tightly restricted palette.

---

## 1. Colour

### Core palette

| Token | Hex | Usage |
|---|---|---|
| `cream` | `#fbf6f3` | Primary background. The default canvas for every screen. |
| `cream-sunk` | `#f4ede6` | Cards, sheets, and surfaces that sit *on top of* the cream background. Subtle contrast only. |
| `cream-deep` | `#ece2d8` | Hover/pressed states on cream-sunk surfaces. Dividers. |
| `aubergine` | `#41133d` | Brand colour. Primary text, primary buttons, active states, selected pins. **Replaces black everywhere.** |
| `aubergine-soft` | `#6b3866` | Secondary text on cream. De-emphasised UI elements. |
| `mute` | `#8a7a72` | Tertiary text, placeholder text, disabled states. A warm mid-tone — never use pure grey on the cream background. |

### Accent

| Token | Hex | Usage |
|---|---|---|
| `accent` | `#ec3d2c` | The single high-energy accent. Used for the "wavy" tag, active map pins, primary CTAs that need to shout, and notification dots. **Must occupy less than 10% of any given screen.** Scarcity is what makes it work. |

### Rules

- Never use pure black (`#000`) or pure white (`#fff`). Aubergine and cream are the substitutes.
- Never use pure grey. Use `mute` for warm neutrals.
- Maximum three colours visible on any screen at once: cream family + aubergine family + (optional) accent.
- The accent is a guest, not a resident. If a screen has more than two accent-coloured elements, one of them is wrong.

---

## 2. Typography

### Fonts

Three primary fonts, with strict role separation:

| Family | Role | Source |
|---|---|---|
| **Rova** | Display, headings, titles, labels | `assets/rova-font/RovaRegular-5yV0a.ttf` |
| **Naria** | Fallback glyphs for Rova numbers and symbols | `naria-font/naria.otf` |
| **Manrope** | Body copy, reading text | `assets/fonts/Manrope-VF.ttf` |
| **DM Sans** | Accent labels, tags, badges, captions | Google Fonts |

Rova is used for anything that needs editorial weight, with Naria only as its glyph fallback for characters Rova does not contain. Manrope is for readable prose. DM Sans is for compact functional text (chips, counts, all-caps labels). Never swap their roles.

### Type scale

| Token | Font | Size | Line height | Weight | Tracking | Use |
|---|---|---|---|---|---|---|
| `display-xl` | Rova | 48 | 1.0 | w800 | -0.03em | Hero screens, poster-style titles |
| `display-lg` | Rova | 36 | 1.05 | w800 | -0.02em | Section heroes, onboarding headlines |
| `display-md` | Rova | 28 | 1.1 | w800 | -0.02em | Card headlines, modal titles. Profile section headers. |
| `title` | Rova | 20 | 1.2 | w400 | -0.01em | List item titles, restaurant names in cards |
| `body` | Manrope | 15 | 1.45 | w500 | 0 | All paragraph text |
| `body-sm` | Manrope | 13 | 1.4 | w500 | 0 | Metadata, captions, secondary info |
| `label` | DM Sans | 11 | 1.0 | w600 | +`fontSize × 0.12` (UPPERCASE) | Section headers ("NEARBY", "YOUR BUBBLES"). The signature move. |
| `micro` | DM Sans | 10 | 1.0 | w700 | +0.4 (UPPERCASE) | Tag text, badge text, chip labels |

### In-code examples

```dart
// Profile/section header — large, heavy Rova
TextStyle(
  fontFamily: 'Rova',
  fontSize: 28,
  fontWeight: FontWeight.w800,
  color: PinitColors.aubergine,
  letterSpacing: 1.0,
  height: 1.05,
)

// Hero name — large, ultra-light Rova on dark background
TextStyle(
  fontFamily: 'Rova',
  fontSize: 28,
  fontWeight: FontWeight.w100,
  color: PinitColors.cream,
  letterSpacing: 1.7,
  height: 1.05,
)

// All-caps section label
GoogleFonts.dmSans(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: PinitColors.aubergineSoft,
  letterSpacing: 11 * 0.12,  // fontSize × 0.12
)

// Body / description copy
GoogleFonts.dmSans(
  fontSize: 15,
  color: PinitColors.aubergine.withValues(alpha: 0.7),
  height: 1.45,
)
```

### Rules

- Display type should feel oversized. If it looks "right", make it bigger. Headlines should dominate their containers.
- Body text is always aubergine (`#41133d`), never black.
- Labels are always uppercase, always tracked, always 11px or smaller. They are the cheapest way to make a screen look art-directed instead of defaulted.
- Never use italic. Never use underline except for inline links in body copy.
- Numerals should be tabular wherever they appear in lists or tables (`font-feature-settings: "tnum"`).

---

## 3. Spacing

A 4px base grid. Use these tokens; do not invent intermediate values.

| Token | Value |
|---|---|
| `space-1` | 4 |
| `space-2` | 8 |
| `space-3` | 12 |
| `space-4` | 16 |
| `space-5` | 24 |
| `space-6` | 32 |
| `space-7` | 48 |
| `space-8` | 64 |
| `space-9` | 96 |

### Rules

- **Default screen padding is 24px**, not 16px. Generosity is what makes UIs feel expensive.
- Vertical rhythm between major sections is 48px minimum. If two sections feel close, they are.
- Inside a card: 20px padding minimum. Inside a button: 16px vertical, 24px horizontal minimum.
- The space *around* a headline should be roughly equal to the headline's own height. Big type needs big breathing room.

---

## 4. Shape & radii

Commit to **fully rounded**. The aesthetic is friendly, not brutalist.

| Token | Value | Use |
|---|---|---|
| `radius-sm` | 12 | Inputs, small chips. |
| `radius-md` | 20 | Cards, sheets, modals. |
| `radius-lg` | 28 | Hero cards, image containers. |
| `radius-pill` | 999 | All buttons. All tags. All filter chips. Avatars. |

### Rules

- Buttons are **always pills**. There are no rectangular buttons in this app.
- Tags and chips are **always pills**.
- Cards use `radius-md` (20). Never less.
- Images inside cards inherit the card's radius minus the card's padding (e.g. card radius 20, padding 4 → image radius 16).
- No mixed radii on the same component. Pick one and stick to it.

---

## 5. Elevation & Shadows

All shadows use **aubergine-tinted colors — never pure black or grey**. This keeps the depth system within the warm palette.

```dart
// subtleShadow — small buttons, icon containers
BoxShadow(
  color: Color(0x0F41133D),  // aubergine ~6% opacity
  blurRadius: 8,
  offset: Offset(0, 2),
)

// cardShadow — default for cards and containers (USE THIS BY DEFAULT)
BoxShadow(
  color: Color(0x1441133D),  // aubergine ~8% opacity
  blurRadius: 16,
  offset: Offset(0, 4),
)

// elevatedShadow — bottom sheets and modals
BoxShadow(
  color: Color(0x1F41133D),  // aubergine ~12% opacity
  blurRadius: 32,
  offset: Offset(0, 12),
)

// stampedShadow — editorially featured cards only (Hidden Gems, Trending tiles)
BoxShadow(
  color: PinitColors.aubergine,  // solid, full opacity
  blurRadius: 0,                 // hard edge — no blur
  offset: Offset(4, 4),          // down + right = printed/stamped look
)
```

Use `cardShadow` as the default for all cards. Reserve `stampedShadow` for featured or hero cards where a graphic, editorial look is intentional. Do not use `stampedShadow` on generic list items.

Prefer separation by **colour contrast** (cream → cream-sunk → cream-deep) over shadow where possible. Less shadow = more premium.

---

## 6. Component primitives

### Cards (canonical pattern)

Every card or box follows this exact pattern. This is the universal styling rule.

```dart
Container(
  padding: const EdgeInsets.all(18),  // or 20 for larger cards
  decoration: BoxDecoration(
    color: PinitColors.creamSunk,      // cream for elevated white variant
    borderRadius: BorderRadius.circular(20),
    border: Border.all(               // ALWAYS include border before shadow
      color: PinitColors.creamDeep,
      width: 1.5,
    ),
    boxShadow: PinitColors.cardShadow,
  ),
)
```

**Rule: every card has a 1.5pt `creamDeep` border. Shadow always accompanies a border, never alone.**

Icon container inside a card:

```dart
Container(
  width: 42,
  height: 42,
  decoration: BoxDecoration(
    color: PinitColors.creamDeep,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Icon(icon, color: PinitColors.aubergine, size: 20),
)
```

### Buttons

- **Primary:** aubergine fill, cream text, pill (`r:999`), `body` w600, 16px vertical / 28px horizontal padding. No shadow. No gradient.
- **Secondary:** transparent, aubergine text, 1.5px aubergine border, pill, same padding.
- **CTA (gradient):** warm red-orange gradient (`#E85D4C` → `#FF7A6B`), cream text, `r:14`, with `cardShadow` in accent colour at 30% opacity. Used for one primary action per screen maximum.
- **Ghost:** transparent, aubergine text, no border. Tertiary actions only.
- Buttons span content + padding only — full-width only inside bottom sheets and forms.

```dart
// Gradient CTA button
Container(
  padding: const EdgeInsets.symmetric(vertical: 14),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE85D4C), Color(0xFFFF7A6B)],
    ),
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: PinitColors.accent.withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  ),
)
```

### Tab / toggle buttons (animated)

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 280),
  curve: Curves.easeOutCubic,
  height: 40,
  padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 11),
  decoration: BoxDecoration(
    color: isSelected ? PinitColors.aubergine : PinitColors.creamSunk,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(
      color: isSelected ? PinitColors.aubergine : PinitColors.creamDeep,
      width: 1.5,
    ),
    boxShadow: isSelected ? PinitColors.subtleShadow : null,
  ),
)
```

### Tags / chips

- Pill shape (`r:999`), always.
- 4px vertical / 9px horizontal padding.
- `micro` token (10px, DM Sans w700, tracked).
- Default: `creamSunk` fill, `creamDeep` border, aubergine text.
- Active/selected: aubergine fill + aubergine border + cream text.
- The "wavy"/"accent" tag uses `accent` fill.

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(
    color: filled ? PinitColors.aubergine : PinitColors.creamSunk,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(
      color: filled ? PinitColors.aubergine : PinitColors.creamDeep,
      width: 1,
    ),
  ),
  child: Text(label, style: GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: filled ? PinitColors.cream : PinitColors.aubergine,
  )),
)
```

### Inputs

- Background: `creamSunk`.
- Radius: 16 (`radius-sm` = 12 for compact, 16 for standard).
- 16px padding all sides.
- No border by default. On focus: 1.5px aubergine border.
- Placeholder text in `mute`.

### Bottom sheets

```dart
Container(
  decoration: BoxDecoration(
    color: PinitColors.cream,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: PinitColors.creamDeep, width: 1.5),
    boxShadow: PinitColors.elevatedShadow,
  ),
  child: SafeArea(
    top: false,
    child: Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 18), ...),
  ),
)
```

Drag handle: `Container(width: 36, height: 4, decoration: BoxDecoration(color: PinitColors.creamDeep, borderRadius: BorderRadius.circular(999)))`.

### Section headers

The signature pattern. Every list section should be preceded by:

```
[DM Sans, 11px, w600, uppercase, tracked at fontSize × 0.12, aubergine-soft]
NEARBY
[24px space]
[content]
```

No icons next to section headers. No "see all" buttons inline — put those underneath.

---

## 7. Motion

```dart
// From lib/themes/pinit_theme.dart
class PinitMotion {
  static const fast     = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 220);
  static const slow     = Duration(milliseconds: 350);

  static const curve     = Curves.easeOutCubic;
  static const curveFast = Curves.fastOutSlowIn;
}
```

Default for state transitions: **280ms, `easeOutCubic`**. Use `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSize` by default. Use `AnimationController` only when multi-step choreography is needed.

---

## 8. Layout patterns

### Screen structure

```
[24px top safe-area padding]
[optional: micro corner label, top-left, aubergine-soft]
[48px space]
[display-lg or display-xl headline]
[24px space]
[body content]
[48px space between major sections]
```

Page horizontal margin is **24px** (20px acceptable where density is required). Card margins from screen edge are 20–24px horizontal.

### Lists

- Vertical spacing between list items: 16px minimum.
- Dividers are optional and discouraged. Use whitespace instead. If a divider is necessary, use `cream-deep` at 1px, never grey.

### Grid spacing

```dart
// Collections grid
SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  childAspectRatio: 0.78,
)

// Mosaic / tight grid
const gap = 6.0;
```

### Image clipping inside bordered containers

When an image fills a bordered card or tile, clip the image at `borderRadius - 1.5` to prevent corner bleed:

```dart
// Card with border r:10 → clip image at r:8.5
ClipRRect(
  borderRadius: BorderRadius.circular(8.5),
  child: image,
)
```

---

## 9. What to delete

Things that signal "vibe-coded" and should be removed during refactor:

- Any shadow with grey or black. Replace with the warm aubergine-tinted shadow system.
- Any radius between 4 and 11px on a card or container. Round up to 12 or down to 0.
- Any use of pure black for text. Replace with aubergine.
- Any use of pure grey. Replace with `mute` or `aubergine-soft`.
- Any rectangular button. Make it a pill.
- Any section header that is not a tracked uppercase DM Sans label.
- Any screen with less than 20px horizontal padding.
- Any card missing its 1.5pt `creamDeep` border.
- Any gradient other than: the warm CTA gradient (`#E85D4C → #FF7A6B`) or a cream → cream-sunk background gradient. Nothing else.
- Any use of a font other than Rova, Naria as the Rova fallback, Manrope, or DM Sans.

---

## 10. Flutter token mapping

For direct use in `PinitTheme` / `PinitColors`:

```dart
class PinitColors {
  static const cream      = Color(0xFFFBF6F3);
  static const creamSunk  = Color(0xFFF4EDE6);
  static const creamDeep  = Color(0xFFECE2D8);
  static const aubergine  = Color(0xFF41133D);
  static const aubergineSoft = Color(0xFF6B3866);
  static const mute       = Color(0xFF8A7A72);
  static const accent     = Color(0xFFEC3D2C);
}

class PinitRadii {
  static const sm   = 12.0;
  static const md   = 20.0;
  static const lg   = 28.0;
  static const pill = 999.0;
}

class PinitSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;
  static const s8 = 64.0;
  static const s9 = 96.0;
}
```

---

## 11. The one-screen checklist

Before shipping any screen, verify:

- [ ] Fonts: Rova for display/headings, Naria only as Rova fallback, Manrope for body, DM Sans for labels/chips. No other fonts.
- [ ] Background is `cream`. Cards are `creamSunk`. No pure white anywhere.
- [ ] All text is `aubergine`, `aubergineSoft`, or `mute`. No black, no grey.
- [ ] Accent colour appears on at most two elements per screen.
- [ ] Every button is a pill (`r:999`).
- [ ] Every card has a 1.5pt `creamDeep` border AND `cardShadow`.
- [ ] Every card uses `radius-md` (20) or larger.
- [ ] Every section has a tracked DM Sans uppercase label header.
- [ ] Horizontal screen padding is at least 20px (24px preferred).
- [ ] The headline feels too big. (If it feels right, it's too small.)
- [ ] Vertical space between major sections is at least 48px.
- [ ] All shadows use aubergine-tinted colors, never black or grey.
- [ ] Image clips inside bordered containers use `borderRadius - 1.5`.
