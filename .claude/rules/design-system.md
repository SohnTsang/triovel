---
description: UX/UI design rules for minimalist, calm, offline-safe iOS interface
globs: "**/DesignSystem/**,**/Views/**,**/*View.swift,**/*Sheet.swift,**/*Card.swift"
---

# Design System — Visual Contracts

## Core Feel
- Fast, calm, trustworthy, offline-safe, not cluttered
- No hidden state, no ambiguous privacy, no form-heavy flows
- No tiny unreadable parallel cards, no fake precision in money or time

## Group vs Personal Visual Contract
- Group blocks: neutral/default card style, full-width, main timeline spine
- Personal blocks: clear `Personal · Name` chip, subtle tint/border variation, creator identity visually obvious
- Personal means "mainly this person's moment" — NOT "nobody else may see it"

## Privacy Visual Contract
- New draft default: Shared is always active when composer opens
- Just Me active: segmented control changes visibly, composer environment shifts subtly, placeholder may say "Add a private note…"
- Leaving draft resets next draft to Shared — never sticky
- Private posts: invisible to others, absent from shared counts, no placeholder leakage

## Time & Clusters
- Time is real — never distort timestamps for layout convenience
- Same-time moments: single shared time label with multiple readable cards stacked vertically
- Never use tiny side-by-side mini blocks
- If too many blocks in one slot, use compact stack with expand affordance

## Add Moment Sheet
- Half-sheet UI, keyboard opens immediately, focus in title field
- Limit to 3 inputs: Title, Group/Personal toggle, Time
- No map search, no member pickers, no media picker as required step

## System States
- Every state must be visible and graceful: saved, pending, syncing, uploaded, failed, retrying
- Use "Media syncing..." skeleton shell if post exists but file not ready
- Failed states show calm retry affordance — never broken image icon or silent disappearance
- Error copy is neutral: "Media failed to sync. Tap to retry." not "ERROR!"

## Empty States
- Home (no trips): friendly onboarding text + Create Trip + Join Trip
- Timeline day (sparse): ghost blocks provide default structure — no dead blank void
- Summary (no bills): calm "No shared expenses yet"
- Archived (none): simple empty state, never blank screen

## Typography & Spacing
- Use SF Pro / system font for consistency
- Maintain generous touch targets (min 44pt)
- Keep information density calm — whitespace is a feature

## Loading & Transition States
- Never show a blank screen while loading — always show skeleton placeholders or cached content
- Skeleton shimmer for cards: use rounded rects matching the card layout with a subtle pulse animation
- Skeleton shimmer for text: use rounded rects at approximate text height and width
- Use SwiftUI .redacted(reason: .placeholder) for simple skeleton states where appropriate
- Prefer skeletons over spinners — spinners feel slower and draw attention to the wait
- Only use a spinner for short, focused actions (sign in, creating a trip, sending a post) — centered, no blocking overlay
- Never use full-screen blocking loaders — the app should always feel interactive
- Sheet presentations: use SwiftUI .sheet with smooth spring animation, no custom hacks
- Navigation transitions: use default SwiftUI push/pop — do not override with custom transitions in V1
- Content that loads progressively should fade in with .opacity animation (0.2s ease)
- Pull-to-refresh: use native SwiftUI .refreshable — no custom pull indicators
- Optimistic UI: after a user action (create trip, add post, add bill), show the result immediately from local data — don't wait for server confirmation
- If a network request fails silently (non-critical), don't interrupt the user — retry in background
- If a network request fails critically (auth, trip creation), show a calm inline error — never an alert unless user action is needed

## Animation Rules
- Keep animations under 0.3s — anything longer feels sluggish
- Use spring(response: 0.3, dampingFraction: 0.8) as the default spring
- Only animate meaningful state changes — don't animate decoratively
- Respect user's Reduce Motion setting — wrap animations in UIAccessibility.isReduceMotionEnabled check
- No bouncing, no elastic overshoot, no playful physics — calm and smooth only

## Adaptive Layout — iPhone + iPad
Apple rejects apps that look broken on iPad. Every screen must work on both.

### Layout Rules
- Never use fixed widths — use relative sizing (percentage, flexible frames, maxWidth)
- Use .frame(maxWidth: 600) on main content containers to prevent ultra-wide stretching on iPad
- Cards and list rows should have a max width and center on wider screens, not stretch edge-to-edge
- Use GeometryReader sparingly — prefer SwiftUI's built-in adaptive layout
- Use .dynamicTypeSize to support all text sizes — never hardcode font sizes with fixed points
- NavigationSplitView: use on iPad for master-detail (trip list -> timeline), NavigationStack on iPhone
- Use horizontalSizeClass environment variable to adapt layout between compact (iPhone) and regular (iPad)

### Common Rejection Traps to Avoid
- Text or buttons that overflow on iPad landscape — always test both orientations
- Sheets and popovers that render full-screen on iPad when they should be popover-sized
- Tiny centered content with massive empty margins — fill the space meaningfully
- Tab bars or toolbars that look absurdly spaced out on 12.9" screens
- Keyboard avoidance that breaks on iPad floating keyboard

### Testing Checklist
- Test every screen on: iPhone SE (small), iPhone 16 (standard), iPad (regular width)
- Test both portrait and landscape on iPad
- Test with Dynamic Type at largest accessibility size
- Test with Split View / Slide Over on iPad
- Sheets must use .presentationDetents appropriately — half-sheet on iPhone, popover on iPad

### Implementation Pattern
```swift
@Environment(\.horizontalSizeClass) private var sizeClass

var body: some View {
    content
        .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
}
```
