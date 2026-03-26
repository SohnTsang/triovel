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
- Primary: warm teal — evokes travel, calm, trust
- Accent: warm coral or terracotta — for interactive elements, FABs, CTAs
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
- Never use ALL CAPS except for very short labels like currency codes
- Letter spacing: default only — never manually track text

## Spacing System (8pt grid)
- Use multiples of 4 and 8 exclusively: 4, 8, 12, 16, 24, 32, 40, 48
- Card internal padding: 16pt
- Space between cards: 12pt
- Section spacing: 24pt
- Screen edge padding: 20pt (iPhone), auto-centered with maxWidth on iPad
- Never eyeball spacing — always use the grid values

## Component Standards

### Buttons — Fixed Size, No Layout Shift
- Primary action: filled style, accent color, 14pt corner radius, FIXED height 50pt, FIXED width (full-width or explicit width) — size must NEVER change between normal and loading states
- When loading: replace label text with a ProgressView INSIDE the same fixed frame — button dimensions stay identical
- Implementation: use .frame(height: 50) and .frame(maxWidth: .infinity) OUTSIDE any conditional content
- Secondary action: plain text style in accent color, no border, no background
- Destructive: plain text in .red, no border — never a big red filled button
- Sign in with Apple: always native ASAuthorizationAppleIDButton — never custom
- Button labels: sentence case, concise verbs ("Create trip" not "CREATE NEW TRIP")
- Disabled state: 0.4 opacity — never hide buttons, just disable
- NEVER let a spinner or state change cause a button to resize or jump

### Toolbar and Navigation Bar Icons — No Circles, No Shadows
- Use .plain buttonStyle on ALL toolbar buttons — this removes the system circle background
- Apply .buttonStyle(.plain) to every Button inside .toolbar {}
- Never use the default button style in toolbars — it adds a circular tinted background
- Icons: SF Symbols only, .medium weight for toolbar, .regular for inline
- Color: accent for interactive, secondary for informational
- Size: 17-20pt for toolbar icons — match system convention
- Implementation pattern for toolbar buttons:
  Button(action: { }) { Image(systemName: "icon.name") }
    .buttonStyle(.plain)

### Cards
- Corner radius: 16pt — consistent everywhere
- Background: Color(.secondarySystemBackground)
- Shadow: color .black.opacity(0.06), radius 8, x 0, y 2
- Content padding: 16pt all sides
- Never use borders on cards — shadow and background contrast are enough
- Trip cards: cover image at top (16:9 aspect, clipped to top corners), content below
- Block cards: no image, clean text hierarchy

### Text Fields
- Rounded border style with 12pt corner radius
- Background: Color(.tertiarySystemBackground)
- Padding: 12pt horizontal, 14pt vertical
- Placeholder: .secondary color
- Focused state: subtle accent color border (1pt)
- Never use underline-style text fields — always enclosed/rounded

### Confirmation Dialogs and Destructive Actions
- Sign out, delete account, delete post — ALWAYS use .confirmationDialog (action sheet style)
- Never use inline buttons that appear in the list for destructive actions
- Never use .alert for destructive actions — .confirmationDialog is the correct iOS pattern
- Pattern:
  .confirmationDialog("Sign out?", isPresented: $showSignOut) {
      Button("Sign out", role: .destructive) { signOut() }
      Button("Cancel", role: .cancel) { }
  } message: {
      Text("You can sign back in anytime.")
  }
- Delete account: same pattern but with stronger warning message
- The destructive button is ALWAYS red automatically with role: .destructive

### Auth Screen — Must Feel Premium, Not Default
- Top section (40% of screen): large vertical spacing, app name "Triovel" in .title bold, tagline in .subheadline secondary — centered, breathe
- Sign in with Apple: native button, full-width, .signIn style, large corner radius — this is the PRIMARY action and should be visually dominant
- Divider: horizontal line with "or" text centered on it — HStack { line, Text("or"), line }
- Email section: MUST be clearly different between Sign In and Sign Up modes:
  - Sign In mode: email field + password field + "Sign in" button + "Don't have an account? Sign up" link
  - Sign Up mode: email field + password field + confirm password field + "Create account" button + "Already have an account? Sign in" link
  - The transition between modes should feel like a real screen change, not just a text swap
  - Use .animation(.easeInOut(duration: 0.2)) on the form section
  - The confirm password field appearing/disappearing is the visual cue that mode changed
- Error messages: .caption in red, below the relevant field, with fade-in animation
- No border around the entire auth form — let it breathe against the background

### Lists and Sections
- Use List with .insetGrouped for settings-type screens
- Use LazyVStack with custom cards for content-type screens
- Section headers: .footnote uppercase secondary with 8pt bottom padding
- Never mix List and ScrollView+VStack on same screen

### Avatars
- Circle clip, 36pt inline, 48pt profile, 24pt stacked chips, 64pt settings profile
- Initials on colored background (color generated from user ID for consistency)
- Stacked: overlap by 8pt, max 4 visible + "+N" chip
- Initials: .caption2 bold, white text on colored circle

### Sheets
- .presentationDetents([.medium, .large]) — let user expand
- .presentationDragIndicator(.visible)
- Content starts 16pt below drag indicator
- Never put critical actions at very bottom — home indicator overlap

### Navigation
- System navigation bar — never custom
- Title: .inline for most screens, .large only for Home
- Toolbar items: SF Symbols + .buttonStyle(.plain) — ALWAYS

## Screen-Specific Notes

### Home
- .large navigation title "Trips"
- Trip cards: visual-first, cover image dominates
- Empty state: centered, no illustrations, text + 2 buttons
- FAB: 56pt circle, accent color, subtle shadow, plus icon

### Timeline
- Day ribbon: horizontal pills, selected = filled accent background
- Ghost blocks: dashed border, 0.4 opacity, tertiary background
- FAB: same as Home

### Block Detail
- Header: title prominent, context chip as small pill, time secondary
- Post stream: avatar + name + time in row, content below
- Composer pinned at bottom

### Settings
- .insetGrouped List
- Profile at top: 64pt avatar + name + email
- Sections: Account, Legal, Danger Zone
- Destructive actions via .confirmationDialog — never inline buttons

## Quality Gate
1. Would you screenshot this for the App Store page?
2. Would a non-technical person feel comfortable immediately?
3. Enough whitespace? If cramped, add space.
4. More than 3 colors visible? Remove one.
5. Does it feel human, or like a dev test screen?
6. Equally polished in dark mode?
7. Can you tell an AI made it? If yes, more personality needed.
8. Do any buttons change size during loading? If yes, fix the frame.
9. Are there circle backgrounds on toolbar icons? If yes, add .buttonStyle(.plain).
10. Do destructive actions use .confirmationDialog? If inline button, fix it.

## Anti-Patterns
- Gray borders on everything — wireframe feel
- Symmetrical layouts with no visual hierarchy — boring
- Default system blue without customizing — screams "default app"
- Too much on one screen — remove elements
- Shadows heavier than opacity 0.1 — dated
- Thick-bordered rounded rects — form, not app
- Centered text for everything — left-align body, center only titles/CTAs
- Buttons that resize when loading — amateur, use fixed frames
- System circle backgrounds on toolbar icons — add .buttonStyle(.plain)
- Destructive actions as inline list buttons — use .confirmationDialog
- Sign in/up toggle that only changes button text — make mode switch obvious
