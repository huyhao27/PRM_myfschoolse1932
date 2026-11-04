# MyFSchool design system (source of truth for the Flutter app and the admin web)

Derived with the `ui-ux-pro-max` skill (https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): its UX rules for accessibility, touch targets, forms, feedback, tables and chips, plus its Flutter stack rules, applied to our product. Its generic "design system" generator suggested glassmorphism / claymorphism palettes; those do not fit a school portal that already has a brand, so this document keeps the FPT brand and applies only the rules.

Product: school management. Users are parents, students, teachers and school managers. Tone: trustworthy, calm, friendly. Two surfaces: a phone-first app (Flutter) and a dense desktop admin portal (ASP.NET Web Forms + Bootstrap).

## 1. Color tokens (light)

| Token | Value | Use |
|---|---|---|
| `brand` | `#F37021` | FPT orange: large surfaces, app bar, icons, accents, focus ring tint. Never as small body text on white (3.0:1) |
| `brand-strong` | `#C2410C` | Text-sized orange and fills that carry white text (5.2:1): primary buttons, links, active nav text |
| `brand-soft` | `#FFEDE0` | Tinted backgrounds, selected rows, chips |
| `navy` | `#1B2A4A` | Headings, sidebar, strong text on light |
| `ink` | `#1C1E21` | Body text |
| `muted` | `#5B616B` | Secondary text (>= 4.5:1 on white and on `surface-alt`) |
| `line` | `#D9DCE1` | Borders, dividers (visible in light and dark) |
| `surface` | `#FFFFFF` | Cards |
| `surface-alt` | `#F6F7F9` | Page background, table zebra |
| `success` / `success-soft` | `#15803D` / `#DCFCE7` | Approved, passed |
| `warning` / `warning-soft` | `#B45309` / `#FEF3C7` | Pending |
| `danger` / `danger-soft` | `#B91C1C` / `#FEE2E2` | Rejected, errors, destructive |
| `info` / `info-soft` | `#1D4ED8` / `#DBEAFE` | Neutral info |

Status is never conveyed by color alone: every status badge has an icon and a text label (Chờ duyệt, Đã duyệt, Từ chối). Dark mode is out of scope for this round; do not hard-code colors, so a dark palette can be added later by swapping tokens.

## 2. Typography

- Face: **Be Vietnam Pro** (full Vietnamese diacritics). Web loads it from Google Fonts with a system-ui fallback. The Flutter app keeps the platform font (no font download in the app); only the scale below changes.
- Scale (px / sp): 12 caption, 14 body-small, 16 body, 18 subtitle, 20 title, 24 headline, 32 display. Minimum body 14 on web tables, 16 in the app for reading text. Line-height 1.5 for body, 1.25 for headings. Weights 400 / 600 / 700.
- Numbers in tables and score columns use tabular figures.
- Headings use balanced wrapping; long text keeps a measure of about 65-72 characters.

## 3. Spacing, shape, elevation, motion

- Spacing scale 4 / 8 / 12 / 16 / 24 / 32 / 48. Page gutters 16 (phone), 24-32 (desktop).
- Radius: 8 controls and chips, 12 cards, 16 sheets and hero panels, 999 pills.
- Elevation: borders first, shadow only for floating layers (menus, dialogs, FAB). Card shadow `0 1px 2px rgba(16,24,40,.06)`.
- Motion: 150 ms for press/hover feedback, 200-250 ms for enter/exit and page transitions, ease-out. Animate opacity and transform only. Respect reduced motion (no transition when the OS asks).
- Icon sizes: 16 inline, 20 controls, 24 navigation, 40 feature tiles. One family and one style per screen: Material Icons (rounded or outlined) in Flutter, Font Awesome solid on the web. No emoji as icons.

## 4. Components

- **Buttons**: primary = `brand-strong` fill, white text, height >= 48 (app) / 40 (web); secondary = outline in `brand-strong`; destructive = `danger`. Disabled = reduced emphasis and no tap. Loading shows a spinner inside the button and blocks double submit.
- **Inputs**: visible label above the field (not placeholder-only), helper text, error text directly under the field in `danger` with an icon, 1.5 px focus ring in `brand-strong`. Field height >= 48 (app).
- **Cards and list items**: whole item tappable, >= 56 high, 16 padding, pressed state without layout shift.
- **Status badge**: pill with icon + label, soft background + strong text from the same status family.
- **Tables (web)**: sticky header, 14 px text, row height >= 44, zebra using `surface-alt`, right-aligned numbers, row actions as icon buttons with accessible names and tooltips, hover and focus-within highlight, empty state with icon, message and a primary action, horizontal scroll container on small screens (or card layout under 768 px), filter bar above the table with labels, chips that wrap.
- **Feedback**: success toast / inline alert after every write ("Đã lưu"), destructive actions confirm in-page (a modal, not `confirm()`), skeletons instead of bare spinners for list loading, retry on errors.
- **Empty states**: icon + one sentence on what will appear + the action to add the first item.

## 5. Layout

- App: single column, safe areas respected, content max width 560 centered on wide screens (the app also runs in a browser), bottom padding so floating buttons never cover the last item, bottom navigation not needed (Home grid is the hub).
- Web: left sidebar (240 px, collapsible under 992 px into an off-canvas menu with a visible toggle) + top bar with the signed-in user, role badge and logout; page header (title, short description, primary action) then content; max content width 1280. Breakpoints 375, 768, 1024, 1440. No horizontal page scroll at 375 px.

## 6. Accessibility (must keep)

- Text contrast >= 4.5:1, meaningful icons and control borders >= 3:1.
- Every interactive element reachable and operable by keyboard with a visible focus ring; never remove outlines without a replacement.
- Icon-only buttons have an accessible label; decorative icons are hidden from assistive tech.
- Touch targets >= 48 dp (app) and >= 44 px (web).
- Form errors announced next to the field; do not rely on color alone.
- `prefers-reduced-motion` respected.

## 7. Brand assets

Use the official FPT Education logo (`assets/images/fpt_education_logo.svg`, copy in the web at `Content/fpt-logo.svg`). Do not recolor or redraw it. On the orange bar it sits on a white rounded chip so it stays legible.

## 8. Pre-delivery checklist

- [ ] No hard-coded colors outside the token files
- [ ] 375 px and 1440 px checked, no horizontal page scroll
- [ ] Keyboard-only pass on web forms and tables
- [ ] Status badges have icon + text
- [ ] Loading, empty, error and success states exist for every list and form
- [ ] Reduced motion honored
- [ ] Existing automated tests and smoke scripts still pass
