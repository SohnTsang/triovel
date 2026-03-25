---
description: Visual design language and UI polish rules for Triovel — every screen must meet this standard
globs: "**/*View.swift,**/*Sheet.swift,**/*Card.swift,**/DesignSystem/**,**/*Button.swift,**/*Row.swift,**/*Cell.swift"
---

# Visual Design — Triovel Identity

## Brand Personality
Triovel is a travel companion, not a productivity tool. It should feel like opening a beautiful journal, not a spreadsheet. The app is warm, confident, and understated — like a well-designed boutique hotel lobby, not a tech startup dashboard.

Keywords: warm, trustworthy, effortless, tactile, human, unhurried
Anti-keywords: corporate, clinical, gamified, flashy, AI-generated, template-ish

## Color Palette
- Primary: a warm teal or muted ocean blue — evokes travel, calm, trust
- Accent: a warm coral or terracotta — for interactive elements, FABs, CTAs
- Backgrounds: use system colors (systemBackground, secondarySystemBackground) for light/dark auto-adapt
- Cards: slightly elevated with ultra-subtle shadow (radius: 8, opacity: 0.06, y: 2) — never flat and lifeless, never heavy drop shadow
- Text: primary for titles, secondary for subtitles, tertiary for metadata — use the full hierarchy
- Avoid pure black text on white — use Color(.label) which is slightly softer
- Never use more than 3 colors on one screen — restraint is premium

## Typography Hierarchy (strictly enforced)
- Screen titles: .title2 bold — one per screen, establishes context
- Section headers: .headline — groups content, not shouty
- Card titles: .body bold or .callout bold — readable at a glance
- Body text: .body — comfortable reading size
- Metadata (dates, timestamps, member count): .caption or .footnote in secondary color
- Never use .largeTitle inside the app (reserve for onboarding/splash only)
- Never use ALL CAPS except for very short labels (e.g., "JPY", "AUD")
- Letter spacing: default only — never manually track text

## Spacing System (8pt grid)
- Use multiples of 4 and 8 exclusively: 4, 8, 12, 16, 24, 32, 40, 48
- Card internal padding: 16pt
- Space between cards: 12pt
- Section spacing: 24pt
- Screen edge padding: 20pt (iPhone), auto-centered with maxWidth on iPad
- Never eyeball spacing — always use the grid values

## Component Standards

### Buttons
- Primary action (Save, Create, Send): filled style with accent color, 14pt corner radius, min height 50pt, full width or generous width — finger-friendly
- Secondary action (Cancel, Skip): plain text style in accent color, no border
- Destructive (Delete, Sign Out): plain text style in .red, no border — never a big red filled button
- Sign in with Apple: always use native ASAuthorizationAppleIDButton — never custom-draw it
- Button labels: sentence case, concise verbs ("Create trip", not "CREATE NEW TRIP")
- Disabled state: 0.4 opacity, no interaction — never hide buttons, just disable

### Cards
- Corner radius: 16pt — consistent everywhere
- Background: Color(.secondarySystemBackground)
- Shadow: color .black.opacity(0.06), radius 8, x 0, y 2
- Content padding: 16pt all sides
- Never use borders on cards — the shadow and background contrast are enough
- Trip cards: cover image at top (aspect ratio 16:9, clipped to card corners), content below
- Block cards: no image, clean text hierarchy with time on the left or top

### Text Fields
- Rounded border style with 12pt corner radius
- Background: Color(.tertiarySystemBackground)
- Padding: 12pt horizontal, 14pt vertical
- Placeholder: .secondary color, descriptive but short
- Focused state: subtle accent color border (1pt)
- Never use underline-style text fields — always enclosed/rounded

### Lists and Sections
- Use List with .insetGrouped style for settings-type screens
- Use LazyVStack with custom cards for content-type screens (timeline, block detail)
- Section headers: .footnote uppercase secondary color with 8pt bottom padding
- Never mix List and ScrollView+VStack styles on the same screen

### Avatars
- Circle clip, 36pt for inline, 48pt for profile, 24pt for stacked chips
- Show initials on colored background when no photo (generate color from user ID for consistency)
- Stacked avatars: overlap by 8pt, max 4 visible + overflow "+N" chip
- Initials: .caption2 bold, white text on colored circle

### Sheets
- Use .presentationDetents([.medium, .large]) — let user pull to expand
- Corner radius: system default (don't override)
- Add a subtle drag indicator: .presentationDragIndicator(.visible)
- Content starts 16pt below the drag indicator
- Never put critical actions at the very bottom of a sheet — they get hidden by home indicator

### Navigation
- Use system navigation bar — never custom-build one
- Title: .inline display mode for most screens, .large only for Home
- Toolbar items: SF Symbols only, no text buttons in toolbar (except "Save" / "Done" for edit modes)

### Icons
- Use SF Symbols exclusively — never custom icons in V1
- Weight: .medium for toolbar, .regular for inline
- Size: match text size they're next to — never oversized decorative icons
- Accent color for interactive icons, secondary color for informational ones

## Screen-Specific Design Direction

### Auth Screen
- Top 40% of screen: app name "Triovel" in .title bold + tagline in .body secondary
- Centered, generous whitespace above — breathe
- Sign in with Apple button: native, full-width, .large style, prominent
- Divider with "or continue with email" text centered
- Email/password fields: rounded, stacked with 12pt gap
- Sign In / Sign Up: segmented control or underline toggle at bottom
- No background images, no gradients, no illustrations — clean and confident

### Home Screen
- Large title "Trips" with .large display mode
- Trip cards as visual-first elements — cover image dominates if available
- Empty state: centered vertically, illustration-free, just text + 2 buttons (Create / Join)
- FAB: 56pt circle, accent color, subtle shadow, SF Symbol plus icon

### Timeline
- Day ribbon: horizontally scrolling pills, selected day has filled accent background
- Block cards: clean, readable, time aligned left, title prominent
- Ghost blocks: dashed border, 0.4 opacity, system tertiary background
- FAB: same style as Home

### Block Detail
- Header: title large and bold, context chip as small pill, time in secondary
- Post stream: cards with author avatar + name + timestamp in header row, content below
- Composer pinned at bottom: rounded text field + send button, Shared/Just Me as small segmented control above

### Settings
- .insetGrouped List, no custom styling
- Profile section at top: avatar (large, 64pt) + name + email
- Sections: Account, Legal, Danger Zone (delete account)
- Each row: SF Symbol icon + label, chevron for navigation rows
- Sign out: .red text, no icon, bottom of list

## Quality Gate — Every Screen Must Pass These
1. Does it look good in a screenshot? Would you put it on the App Store page?
2. Would a non-technical person feel comfortable using it immediately?
3. Is there enough whitespace? If anything feels cramped, add space.
4. Are there more than 3 colors visible? If yes, remove one.
5. Does it feel human and warm, or does it feel like a developer's test screen?
6. Does it look equally polished in dark mode?
7. Could you tell an AI made it? If yes, it needs more personality.

## Anti-Patterns — Never Do These
- Gray borders on everything — makes the app feel like a wireframe
- Perfectly symmetrical layouts with no visual hierarchy — boring and hard to scan
- Using system blue (Color.accentColor default) without customizing it — screams "default app"
- Putting too much on one screen — when in doubt, remove elements
- Drop shadows heavier than opacity 0.1 — looks dated
- Rounded rectangles with thick borders — feels like a form, not an app
- Stock photo or illustration placeholders — better to leave empty than look fake
- Centered text for everything — left-align body content, center only titles and CTAs
