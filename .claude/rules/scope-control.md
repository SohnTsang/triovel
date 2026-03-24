# Scope Control & Phase Enforcement

## Phase Gate Rules
- Do NOT build Phase 2 features (posts, composer, sync, filters) until Phase 1 is locked (auth, home, trips, timeline, blocks, ghost blocks, add moment)
- Do NOT build Phase 3 features (media upload, states, placeholders) until Phase 2 is locked
- Do NOT build Phase 4 features (bills, payments, summary) until Phase 3 is locked
- Do NOT build Phase 5 features (archive, empty states, cost controls, instrumentation) until Phase 4 is locked
- If a feature spans phases, implement only the current-phase portion

## Feature Rejection (actively reject any code involving these)
- Attendance tracking or block-level invites
- Live location sharing or map-first creation flows
- Algorithmic highlights or public spectator web links
- Live FX conversion or OCR receipt scanning
- Co-editing of rich content objects
- Merge conflict UI theater
- Deep branching UI or enterprise permission matrices
- Public web export or embedded timeline in Summary
- Charts or noisy widgets in empty states
- Notification system beyond basic sync status

## Scope Creep Signals (push back if you see these)
- Adding a 4th input to Add Moment sheet
- Making filters persist across sessions
- Adding a map search to any creation flow
- Building a separate notes tab or photo tab in Block Detail
- Adding attendance assumptions to bill splitting
- Making the Summary screen show timeline content
- Any "wouldn't it be cool if..." that isn't in the blueprint

## Locked Numeric Limits
- Free user active trip ownership: 30 trips
- Photo compression target: 1.5MB (always compress client-side, never reject)
- Video duration cap: 60 seconds (enforce client-side — show countdown timer in recorder, show trimmer if selecting from library)
- Video compression target: 30MB (H.264, 1080p 30fps, medium quality — never reject, never show file size to user)
- Trip storage soft ceiling: 2GB (warn at 1.5GB, auto-increase compression past 2GB)
- Trip storage hard ceiling: 5GB (pause syncing, calm message, content stays local)

## Cost Control — Error-Free Approach
- The user only ever sees ONE limit: the 60-second duration indicator. All compression is invisible.
- Photo uploads must NEVER fail due to file size — always compress down to target
- Video uploads must NEVER fail — always re-encode to target silently
- If user selects a library video longer than 60s, show trimmer UI — never silently cut
- At 75% storage (1.5GB): show one-time calm notice, no action required from user
- Past 100% storage (2GB): silently increase compression (photo → ~800KB, video → ~15MB), uploads continue
- At hard ceiling (5GB): pause remote sync, show "Trip storage is full" — content stays safe locally
- Track storage/egress per trip — this is infrastructure, not optional
