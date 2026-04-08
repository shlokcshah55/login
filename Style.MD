# pinit — Design System

A reference for refactoring pinit's UI to a sleek, playful, art-directed aesthetic. This document defines the visual language only — typography, colour, spacing, shape, and component primitives. Personality elements (illustrations, mascots, micro-interactions) are intentionally out of scope for this pass.

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

Two fonts only. No exceptions.

- **Display:** Rova.
- **Body:** Geist.

### Type scale

| Token | Size | Line height | Weight | Tracking | Use |
|---|---|---|---|---|---|
| `display-xl` | 48 | 1.0 | Display 800 | -0.03em | Hero screens, restaurant detail page titles. Should feel like a poster. |
| `display-lg` | 36 | 1.05 | Display 800 | -0.02em | Section heroes, onboarding headlines. |
| `display-md` | 28 | 1.1 | Display 800 | -0.02em | Card headlines, modal titles. |
| `title` | 20 | 1.2 | Body 600 | -0.01em | List item titles, restaurant names in cards. |
| `body` | 15 | 1.45 | Body 400 | 0 | All paragraph text. |
| `body-sm` | 13 | 1.4 | Body 400 | 0 | Metadata, captions, secondary info. |
| `label` | 11 | 1.0 | Body 600 | +0.12em (UPPERCASE) | Section headers ("NEARBY", "WAVY SPOTS", "YOUR BUBBLES"). The signature move. |
| `micro` | 10 | 1.0 | Body 600 | +0.15em (UPPERCASE) | Corner labels, tag text, badge text. |

### Rules

- Display type should feel oversized. If it looks "right", make it bigger. Headlines should dominate their containers.
- Body text is always aubergine (`#41133d`), never black.
- Labels are always uppercase, always tracked, always 11px or smaller. They are the cheapest way to make a screen look art-directed instead of defaulted.
- Never use italic. Never use underline (except for inline links in body copy, and even then prefer a colour change).
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

## 5. Elevation

Avoid drop shadows where possible. The aesthetic is flat-with-warmth, not material design.

When elevation is necessary (sheets, modals, floating action elements), use a **warm, soft, low-opacity shadow** rather than a neutral grey one:

```
shadow-soft:  0 2px 8px rgba(65, 19, 61, 0.06)
shadow-card:  0 4px 16px rgba(65, 19, 61, 0.08)
shadow-lift:  0 12px 32px rgba(65, 19, 61, 0.12)
```

Prefer separation by **colour contrast** (cream → cream-sunk) over separation by shadow.

---

## 6. Component primitives

### Buttons

- **Primary:** aubergine background, cream text, pill shape, `body` weight 600, 16px vertical / 28px horizontal padding minimum. No shadow. No gradient. No border.
- **Secondary:** transparent background, aubergine text, 1.5px aubergine border, pill shape, same padding.
- **Accent:** accent (`#ec3d2c`) background, cream text. Reserved for one CTA per screen maximum.
- **Ghost:** transparent, aubergine text, no border. For tertiary actions only.
- Buttons span their content plus padding — they do not stretch full-width except in bottom sheets and forms.

### Cards

- Background: `cream-sunk`.
- Radius: `radius-md` (20).
- Padding: 20px minimum, 24px preferred.
- No border. No shadow (unless floating).
- Title uses `title` token. Metadata uses `body-sm` in `aubergine-soft`.

### Tags / chips

- Pill shape, always.
- 8px vertical / 14px horizontal padding.
- `micro` token (10px uppercase tracked).
- Default: aubergine border + aubergine text on transparent.
- Active/selected: aubergine fill + cream text.
- The "wavy" tag specifically uses the accent colour as fill.

### Inputs

- Background: `cream-sunk`.
- Radius: `radius-sm` (12).
- 16px padding all sides.
- No border by default. On focus, 1.5px aubergine border.
- Placeholder text in `mute`.

### Section headers

The signature pattern. Every list section in the app should be preceded by:

```
[label token, uppercase, tracked, aubergine-soft]
NEARBY
[24px space]
[content]
```

No icons next to section headers. No "see all" buttons inline with them — put those underneath.

---

## 7. Layout patterns

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

### Lists

- Vertical spacing between list items: 16px minimum.
- Dividers are optional and discouraged. Use whitespace instead. If a divider is necessary, use `cream-deep` at 1px, never grey.

### Bottom sheets

- Radius `radius-lg` (28) on the top corners only.
- Background `cream` (not `cream-sunk` — sheets sit above the world).
- 32px top padding, 24px horizontal, 32px bottom padding (above safe area).
- A 4px wide, 36px long, fully rounded `cream-deep` handle centred at the top.

---

## 8. What to delete

Things that signal "vibe-coded" and should be removed during refactor:

- Any drop shadow with grey or black. Replace with warm soft shadow or remove entirely.
- Any radius between 4 and 11 px. Round up to 12 or down to 0.
- Any use of pure black for text. Replace with aubergine.
- Any use of pure grey. Replace with `mute` or `aubergine-soft`.
- Any rectangular button. Make it a pill.
- Any section header that is not a tracked uppercase label.
- Any screen with less than 24px horizontal padding.
- Any use of more than two fonts.
- Any gradient. (Possible exception: a single subtle cream → cream-sunk gradient on a hero background. Nowhere else.)
- Any icon set that ships by default (Material Icons, Lucide outline, Feather). Swap for Phosphor Duotone, Iconoir, or a custom set.

---

## 9. Flutter token mapping

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

## 10. The one-screen checklist

Before shipping any screen, verify:

- [ ] Two fonts maximum, one of them heavy display used at large size.
- [ ] Background is cream. Cards are cream-sunk. No pure white anywhere.
- [ ] All text is aubergine, aubergine-soft, or mute. No black, no grey.
- [ ] Accent colour appears on zero, one, or at most two elements.
- [ ] Every button is a pill.
- [ ] Every card uses `radius-md` (20) or larger.
- [ ] Every section has a tracked uppercase label header.
- [ ] Horizontal screen padding is at least 24px.
- [ ] The headline feels too big. (If it feels right, it's too small.)
- [ ] Vertical space between sections is at least 48px.
- [ ] No drop shadows except warm soft ones on floating elements.
