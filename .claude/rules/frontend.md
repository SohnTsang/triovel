---
description: Frontend SwiftUI rules for offline-first iOS development
globs: "**/*.swift"
---

# Frontend — SwiftUI / Offline-First

## Offline-First Reality
- Every user action must write to local PowerSync SQLite first, then sync
- Users must be able to open cached trips, create blocks, write posts, add bills, and attach media fully offline
- Never block UI on a network request — use optimistic local writes

## Data Sync vs Media Sync
- PowerSync handles structured data sync (trips, blocks, posts, bills)
- Background URLSession handles media uploads — completely separate pipeline
- A post can exist locally before its media finishes uploading — always handle this

## Timeline Implementation
- Build a sticky day ribbon that updates highlighted day on vertical scroll
- Tap day in ribbon → jump to that day section
- Filters (All / Group / Personal) are session-only — reset on app relaunch or leaving trip
- If Personal filter is active and multiple people exist, show person chips
- Ghost blocks are faded/dashed — tapping one converts it to a real block instantly
- Same-time blocks use time-slot clusters (shared time label, stacked cards) — never tiny side-by-side cards

## Add Moment Sheet
- Half-sheet with keyboard open immediately, cursor in title field
- Only 3 inputs: Title, Group/Personal toggle, Time
- Inherit day from currently visible timeline day or tapped ghost block
- After create → push directly into new Block Detail (never back to timeline first)
- Do NOT include: map search, member picker, bill setup, required media selection

## Block Detail View
- Single unified chronological stream: posts + bills + syncing shells + failed states
- Composer: Shared/Just Me toggle → text input → media preview → actions (camera/library/bill/send)
- Every new draft starts Shared — after send/cancel/leave, next draft resets to Shared
- Private posts visible only to owner — no placeholder or count leakage to others

## Money Handling
- Group balances strictly by currency in Summary — never merge JPY and AUD
- Store all amounts as integers (smallest currency unit)
- Bill defaults: payer = current user, all trip members included, equal split
- Payments are trip-level (not block-level)

## Data Inheritance
- Add Moment inherits day from visible timeline position
- Block Detail inherits trip context (members, currency, timezone)

## State Indicators
- Every block card may show: normal / pending / syncing / failed media inside
- Every post/media may show: saved / syncing / uploaded / failed / retrying
- Show "Media syncing..." skeleton shell if post text synced but file not ready
- Failed uploads must have visible retry affordance — never silent disappearance
