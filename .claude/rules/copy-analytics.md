---
description: In-app copy, empty states, error messages, and analytics instrumentation
globs: "**/Strings/**,**/*Localizable*,**/*Copy*,**/*Analytics*,**/*Tracking*,**/*Onboarding*"
---

# Copy & Analytics

## Copywriting Tone
- Neutral, administrative, calm — never alarming or marketing-heavy
- Error states: "Media failed to sync. Tap to retry." not "ERROR!" or "Oops!"
- Empty states: "No shared expenses yet" not "Start tracking money!"
- Placeholder text: "What's happening?" or "Where to?" for block title
- Private composer: "Add a private note…" when Just Me is active

## Privacy Copy
- "Shared" and "Just Me" must be the exact labels — no ambiguity
- Toggle text must feel psychologically safe — user should never worry about accidental exposure
- Never use "Public" or "Private" as labels — use "Shared" and "Just Me"

## Onboarding Copy
- Home empty state: friendly, not pushy — "Create your first trip" + "Join a trip"
- Trip Setup: require only Title and Dates — timezone and currency default silently from device
- Do not explain features during creation — let the timeline speak for itself

## Beta Analytics (Phase 5)
Instrument these metrics only — lightweight, privacy-safe:
- Storage GB per trip
- Ratio of Group vs Personal blocks created
- Usage frequency of "Record Payment" feature
- Number of active trips per user (for cost control)
- Media upload success/failure rate
- Average posts per block

## Analytics Rules
- No user-identifiable data in analytics events
- No tracking of post content or bill amounts
- Analytics must not affect app performance or offline functionality
- Defer all analytics implementation to Phase 5
