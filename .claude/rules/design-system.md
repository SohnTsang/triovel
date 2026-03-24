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
