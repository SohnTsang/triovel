# Group Travel OS

## Product
Offline-first iOS app for group trip timelines, shared memories, and contextual expense splitting.
One-liner: Plan the anchors. Capture the reality. Share the trip.

## Stack
- SwiftUI (iOS 17+, iPhone + iPad)
- Supabase: Postgres, Auth (Apple Sign-In + Email/Password), Storage
- PowerSync: local-first SQLite sync
- Background URLSession: media upload queue (separate from data sync)

## Auth Methods
- Primary: Sign in with Apple (required for App Store if offering any social login)
- Secondary: Email + password (for users without Apple devices in the group)
- Both methods link to the same Supabase Auth user record
- Session restore + token refresh on app launch (see sync.md for full flow)

## Project Structure
```
Triovel/
├── App/                  # App entry, root navigation, DI
├── Features/
│   ├── Home/             # Global home, active/archived trips
│   ├── TripSetup/        # Create/join trip flows
│   ├── Timeline/         # Day ribbon, filter bar, block cards, ghost blocks
│   ├── AddMoment/        # Half-sheet block creation
│   ├── BlockDetail/      # Unified post/bill stream, composer
│   ├── Bills/            # Bill entry, payment entry
│   └── Summary/          # Money dashboard, archive
├── Core/
│   ├── Models/           # Domain models, enums
│   ├── Sync/             # PowerSync config, sync rules, conflict handling
│   ├── MediaQueue/       # Background upload queue, retry, state machine
│   ├── Auth/             # Supabase auth, session restore, token refresh
│   ├── Storage/          # Supabase Storage wrappers, compression
│   └── Networking/       # API clients, offline detection
├── DesignSystem/         # Shared UI components, tokens, styles
├── Utilities/            # Extensions, helpers, formatters
└── Resources/            # Assets, localization
supabase/
├── migrations/           # Numbered SQL migration files
├── functions/            # Edge Functions if needed
└── seed.sql              # Test seed data
```

## Core Tables
users, trips, trip_members, blocks, posts, post_media, bills, bill_shares, payments

## Build Phases (strict order)
- Phase 1: Auth -> Home -> Trip Setup -> Trip Members -> Timeline shell -> Blocks -> Group/Personal context -> Ghost blocks -> Add Moment
- Phase 2: Posts -> Shared/Just Me composer -> Local-first sync (PowerSync) -> Filters -> Same-time clusters
- Phase 3: Media metadata -> Media upload queue -> Upload states -> Placeholders -> Retry handling
- Phase 4: Bills -> Bill shares -> Payments -> Summary screen -> Multi-currency balances
- Phase 5: Archive -> Empty states -> Pending indicators -> Cost controls -> Instrumentation -> Beta testing

## Locked Rules (never violate these)
1. Trip is the only access boundary -- no block-level invites
2. Data sync and media sync are always separate systems
3. Private posts never sync to other users' devices
4. Every new composer draft defaults to Shared -- never sticky
5. Same-time blocks cluster in UI -- never mutate timestamps to force sort
6. Never combine mixed currencies into one fake total
7. Bills and Payments are explicit source-of-truth records
8. Every important action saves locally first, syncs later
9. All system states (saved/pending/syncing/uploaded/failed) must be visible and graceful
10. Schema is treated as stable from day one -- prefer additive changes only

## V1 Exclusions (reject any code or ideas involving these)
- Attendance tracking or block-level invites
- Live location sharing or map-first creation
- Algorithmic highlights or public spectator web links
- Live FX conversion or OCR receipt scanning
- Merge conflict UI theater
- Deep branching UI or enterprise permission matrices
- Co-editing of rich content objects

## Git Workflow
- Repo: https://github.com/SohnTsang/triovel
- Branch strategy: feature branches off main
- Branch naming: feature/p<phase>-<short-description> (e.g. feature/p1-auth, feature/p1-home, feature/p1-timeline)
- After each completed task: commit with clear message, push the feature branch
- Commit message format: [Phase X] Short description (e.g. [Phase 1] Set up Supabase Auth with Apple Sign-In)
- Merge to main: when a feature is complete and working, merge feature branch to main
- Tags: tag main after each phase completion (e.g. v0.1.0-phase1, v0.2.0-phase2)
- Never commit directly to main -- always use a feature branch

## Commands
- Build: xcodebuild -scheme Triovel -destination 'platform=iOS Simulator,name=iPhone 16'
- Supabase local: supabase start
- Supabase migration: supabase migration new <name>
- Supabase push: supabase db push
- Git new feature: git checkout -b feature/p1-<name>
- Git commit: git add . && git commit -m "[Phase X] description"
- Git push: git push -u origin feature/p1-<name>

## Conventions
- Use Swift strict concurrency
- Prefer value types (structs/enums) over classes where possible
- Name files after their primary type: TripTimeline.swift, BlockDetailView.swift
- Use MVVM: View -> ViewModel -> Repository -> Sync/API layer
- All currency amounts stored as integers (cents/smallest unit) -- never floating point
- All timestamps stored as UTC, displayed in trip display timezone
- Keep each SwiftUI view file under 200 lines -- extract subviews aggressively

## Docs
- Full blueprint: @docs/blueprint.md
- Full build plan: @docs/plan.md
- Canonical examples for tricky flows: @docs/examples.md
