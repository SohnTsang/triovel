# Triovel — Project Status

## Project Overview

| Field | Value |
|---|---|
| App name | Triovel |
| One-liner | Plan the anchors. Capture the reality. Share the trip. |
| Stack | SwiftUI (iOS 17+), Supabase (Postgres, Auth, Storage), PowerSync (local-first SQLite sync) |
| Repo | https://github.com/SohnTsang/triovel |
| Current phase | Phase 2 (in progress) |
| Current branch | `feature/p2-sync` |
| Latest tag | `v0.1.0-phase1` |
| Bundle ID | com.triovel.app |
| Languages | English, Japanese, Chinese Traditional, Chinese Simplified |

---

## Architecture

### Folder Structure

```
Triovel/
├── App/
│   ├── TriovelApp.swift              — @main entry, creates AppState, renders RootView
│   ├── AppState.swift                — Central auth + sync state manager (@Observable @MainActor)
│   ├── RootView.swift                — Routes auth status to AuthView / HomeView / VerificationView
│   ├── Router.swift                  — NavigationStack path manager with Destination enum
│   └── DependencyContainer.swift     — Lightweight DI container (holds AuthService)
├── Core/
│   ├── Auth/
│   │   ├── AuthService.swift         — Sign-in (Apple + email), session restore, token refresh, verification
│   │   ├── AuthView.swift            — Auth screen with Apple button, email form, mode toggle
│   │   ├── AppleSignInCoordinator.swift — ASAuthorizationController delegate, nonce generation
│   │   ├── EmailVerificationView.swift — Post-signup verification screen with resend
│   │   └── SupabaseConfig.swift      — Supabase client singleton (URL + anon key)
│   ├── Models/
│   │   ├── Trip.swift                — Trip container with dayCount computed property
│   │   ├── Block.swift               — Timeline moment + BlockContext enum (group/personal)
│   │   ├── Post.swift                — Memory post + PostVisibility enum (shared/private)
│   │   ├── PostMedia.swift           — Media attachment + MediaType + UploadStatus enums
│   │   ├── Bill.swift                — Expense record (amount as integer, smallest unit)
│   │   ├── BillShare.swift           — Per-person split of a bill
│   │   ├── Payment.swift             — Real-world repayment between two people
│   │   ├── TripMember.swift          — User-trip junction with Role enum (owner/member)
│   │   └── User.swift                — AppUser profile (displayName, avatarPath)
│   ├── Networking/
│   │   ├── TripRepository.swift      — Trip CRUD: local-first reads/writes, Supabase for joinTrip
│   │   ├── BlockRepository.swift     — Block CRUD: local-first reads/writes, reactive watch
│   │   └── PostRepository.swift      — Post CRUD: local-first with privacy filter (defense-in-depth)
│   └── Sync/
│       ├── AppSchema.swift           — PowerSync SQLite schema (9 tables with indexes)
│       ├── PowerSyncConfig.swift     — PowerSync endpoint URL
│       ├── SupabaseConnector.swift   — JWT auth + CRUD upload with type-correct encoding
│       └── SyncManager.swift         — Database singleton + connect/disconnect lifecycle
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift            — NavigationStack root with destination routing
│   │   ├── HomeViewModel.swift       — Reactive trip watch, 30-trip limit, TripMemberDisplay model
│   │   ├── HomeContentView.swift     — Trip list, FAB, toolbar (settings + archive), sheets
│   │   ├── HomeEmptyStateView.swift  — Empty state: airplane icon + create/join buttons
│   │   ├── TripCardView.swift        — Trip card with cover, dates, stacked member avatars
│   │   └── ArchivedTripsView.swift   — Archived trips list with empty state
│   ├── Timeline/
│   │   ├── TripTimelineView.swift    — Day ribbon + filter bar + block list + FAB + offline indicator
│   │   ├── TripTimelineViewModel.swift — Day generation, block grouping, time-slot clustering
│   │   ├── DayRibbonView.swift       — Horizontal scrolling day selector with auto-scroll
│   │   ├── DaySectionView.swift      — Day header + time-slot groups with ghost block placeholders
│   │   ├── FilterBarView.swift       — All/Group/Personal segmented picker + TimelineFilter enum
│   │   └── BlockCardView.swift       — Block card with context chip, sync indicator, location + time
│   ├── AddMoment/
│   │   └── AddMomentView.swift       — Half-sheet: title + context toggle + time picker (3 inputs only)
│   ├── BlockDetail/
│   │   ├── BlockDetailView.swift     — Unified post stream + composer, auto-scroll, error states
│   │   ├── BlockDetailViewModel.swift — Block/post CRUD, reactive post watch, header permissions
│   │   ├── BlockDetailHeaderView.swift — Display/edit mode for title, context chip, time, location
│   │   ├── PostCardView.swift        — Post card: avatar, author, time, body, visibility badge, delete
│   │   ├── PostComposerView.swift    — Shared/Just Me toggle + text input + send (visibility resets)
│   │   ├── PostSkeletonView.swift    — Skeleton shimmer matching PostCardView layout
│   │   └── FailedPostCardView.swift  — Failed draft card with retry + discard affordance
│   ├── TripSetup/
│   │   ├── TripSetupView.swift       — Create trip: title + dates, auto-fill timezone/currency
│   │   └── JoinTripView.swift        — Join by invite code (network required)
│   ├── TripMembers/
│   │   └── TripMembersView.swift     — Member list with roles, copy invite link, toast
│   ├── Bills/
│   │   └── BillEntryView.swift       — Placeholder for Phase 4 bill entry
│   ├── Summary/
│   │   └── TripSummaryView.swift     — Placeholder for Phase 4 money dashboard
│   └── Settings/
│       ├── SettingsView.swift        — Account, legal, danger zone (sign out + delete account)
│       ├── ProfileHeaderView.swift   — 64pt avatar + name + email
│       └── SignInMethodRow.swift     — Shows Apple/Email sign-in method from JWT metadata
├── DesignSystem/
│   ├── ColorTokens.swift             — Semantic colors: background, text, personal, sync states
│   ├── TypographyTokens.swift        — Font presets: largeTitle through caption
│   └── Components/
│       ├── ContextChip.swift         — "Group" / "Personal · Name" capsule chip
│       ├── SyncStateIndicator.swift  — Subtle sync state icons (synced/pending/syncing/failed)
│       └── PlainToolbarModifier.swift — Replaces iOS 26 Liquid Glass back button with plain chevron
├── Utilities/
│   └── DateExtensions.swift          — startOfDay(in:) and dayNumber(from:in:) timezone helpers
└── Resources/
    ├── Assets.xcassets               — App icon, accent color, asset catalog
    ├── LaunchScreen.storyboard       — Simple launch screen (system background)
    └── Localizable.xcstrings         — String Catalog with 4 languages (en, ja, zh-Hans, zh-Hant)

supabase/
├── migrations/
│   └── 20260324144221_initial_schema.sql — All 9 tables, RLS policies, triggers, helper functions
└── seed.sql                              — Test data: 2 users, 1 trip, 3 blocks, 3 posts, 1 bill, 1 payment

docs/
├── blueprint.md                      — Full UI/UX contract (19 sections)
├── plan.md                           — Full build spec (21 sections)
├── examples.md                       — Canonical flow examples (6 scenarios)
├── powersync-sync-rules.yaml         — PowerSync Sync Streams configuration reference
└── STATUS.md                         — This file
```

### Key Patterns

| Pattern | Usage |
|---|---|
| **MVVM** | View → ViewModel (@Observable @MainActor) → Repository → PowerSync/Supabase |
| **@Observable** | All ViewModels use iOS 17+ @Observable (not @ObservableObject/@Published) |
| **Reactive watches** | ViewModels use PowerSync `watch()` streams — UI auto-updates on data changes |
| **Local-first** | All reads from local SQLite, writes save locally first, PowerSync uploads to Supabase |
| **Sendable models** | All domain models are struct, Identifiable, Codable, Hashable, Sendable |
| **Task cancellation** | All ViewModels cancel Tasks in deinit, use `[weak self]` in closures |
| **500ms loading minimum** | Loading states show for at least 500ms to prevent flash (per feedback rule) |
| **Router navigation** | Single Router with NavigationPath, enum-based Destinations |
| **Stable IDs** | ForEach uses database IDs (never UUID()), LazyVStack for performance |

---

## Completed Features

### Auth

**What it does**: Apple Sign-In (primary) + email/password (secondary), session restore on launch, email verification flow, deep link handling.

| Aspect | Details |
|---|---|
| Key files | `AuthService.swift`, `AuthView.swift`, `AppleSignInCoordinator.swift`, `EmailVerificationView.swift`, `AppState.swift` |
| Sign in with Apple | `signInWithApple(idToken:nonce:)` via ASAuthorizationController, nonce hashing with SHA-256 |
| Email auth | `signUp(email:password:)` returns SignUpResult with needsVerification flag; `signIn(email:password:)` |
| Session restore | `restoreSession()` → Supabase SDK auto-refreshes expired tokens → connect PowerSync |
| Email verification | Dedicated screen with resend button, auto-dismiss success toast (2s), back navigation |
| Deep links | `triovel://auth-callback` (email verification), `triovel://trip/{code}` (join trip, placeholder) |
| Error handling | Classifies Supabase errors into AuthError variants (emailTaken, weakPassword, wrongCredentials, emailNotVerified, networkError, verificationExpired) |
| UI | Fixed-height buttons (50pt, never resize on loading), animated mode toggle, inline error messages |
| Localization | All error messages + UI strings in 4 languages |
| Performance | Deferred loading with isLoading flag, no main thread blocking |

### Home

**What it does**: Shows active trips as cards, archived trips access, create/join trip actions, 30-trip ownership limit.

| Aspect | Details |
|---|---|
| Key files | `HomeView.swift`, `HomeViewModel.swift`, `HomeContentView.swift`, `HomeEmptyStateView.swift`, `TripCardView.swift`, `ArchivedTripsView.swift` |
| Trip cards | Cover image placeholder, title, date range, stacked member avatars (max 5 + "+N" chip) |
| Empty state | Airplane icon + "Create your first trip" + "Join a trip" buttons |
| FAB | 56pt accent circle with plus icon, fixed bottom-right |
| Trip limit | 30 active owned trips; shows alert when limit reached |
| Archived | Separate screen via toolbar, ContentUnavailableView if empty |
| Reactive | `watchTrips()` stream updates trip list when local data changes |
| Error handling | Prints errors, continues showing existing data |
| UI | `.refreshable` pull-to-refresh, `.large` navigation title, maxWidth 600 on iPad |
| Localization | All strings in 4 languages |
| Performance | LazyVStack, 500ms minimum loading, Task cancellation in deinit |

### Trip Setup

**What it does**: Create trip (3 required inputs), join trip by invite code.

| Aspect | Details |
|---|---|
| Key files | `TripSetupView.swift`, `JoinTripView.swift` |
| Create inputs | Title (required, max 100 chars), start date, end date (must be >= start) |
| Auto-fill | Display timezone from device, base currency from device locale (fallback "USD") |
| Join trip | Invite code field, requires network (Supabase direct call) |
| Post-create | 300ms delay → callback → navigates into trip timeline |
| Error handling | Inline error messages, sheet stays open on failure |
| UI | Form layout, fixed-height buttons, auto-focus on title |
| Localization | All strings in 4 languages |

### Trip Members

**What it does**: Shows member list with roles, copy invite link to clipboard.

| Aspect | Details |
|---|---|
| Key files | `TripMembersView.swift` |
| Member list | Sorted: owners first, then alphabetical. Shows initials avatar + name + role label |
| Invite link | Copy button → copies to pasteboard → brief toast "Copied" (auto-dismiss 2s) |
| Error handling | None needed (read-only from local data) |
| UI | List (.insetGrouped), plain back button |
| Localization | All strings in 4 languages |

### Timeline

**What it does**: Day-based trip timeline with sticky day ribbon, filter bar, ghost blocks, same-time clustering, offline indicator.

| Aspect | Details |
|---|---|
| Key files | `TripTimelineView.swift`, `TripTimelineViewModel.swift`, `DayRibbonView.swift`, `DaySectionView.swift`, `FilterBarView.swift`, `BlockCardView.swift` |
| Day ribbon | Horizontal scroll pills; tap = jump to day; scroll = auto-highlight |
| Filters | All / Group / Personal segmented picker; session-only (resets on leave) |
| Ghost blocks | Inline dashed placeholders (Breakfast/Lunch/Dinner); tap converts to real block |
| Same-time clusters | Shared time label + stacked full-width cards; group first, then personal, then by createdAt |
| Block cards | Title, context chip, location, time, sync state indicator |
| Offline indicator | Subtle "Offline" label in toolbar title when disconnected but has cached data |
| Reactive | `watchBlocks()` stream auto-updates timeline when blocks change |
| Error handling | Prints errors, keeps showing existing data |
| UI | FAB for Add Moment, plain toolbar buttons, maxWidth 600 on iPad |
| Localization | All strings in 4 languages |
| Performance | LazyVStack with pinnedViews, generateDays only recalculates when blocks change |

### Blocks (Add Moment + Block Detail)

**What it does**: Create blocks via half-sheet (3 inputs), view/edit block headers, unified post stream.

| Aspect | Details |
|---|---|
| Key files | `AddMomentView.swift`, `BlockDetailView.swift`, `BlockDetailViewModel.swift`, `BlockDetailHeaderView.swift` |
| Add Moment | Half-sheet: title (auto-focus) + Group/Personal toggle + time picker |
| Day inheritance | Inherits day from visible timeline position or tapped ghost block |
| After create | Navigates directly into new block detail (never back to timeline) |
| Header editing | Only block creator or trip owner can edit (pencil icon → inline fields) |
| Header fields | Title (max 150 chars), location (max 100 chars), with save/cancel controls |
| Error handling | Inline error messages, keeps sheet open on failure |
| UI | Fixed button heights, .presentationDetents, auto-focus |
| Localization | All strings in 4 languages |

### Posts

**What it does**: Shared/Just Me composer, unified chronological stream, delete own posts, failed post retry queue.

| Aspect | Details |
|---|---|
| Key files | `PostComposerView.swift`, `PostCardView.swift`, `PostSkeletonView.swift`, `FailedPostCardView.swift`, `BlockDetailViewModel.swift` |
| Composer | Shared/Just Me segmented toggle + multiline text (1-6 lines) + send button |
| Visibility reset | Every new draft starts Shared; after send/cancel/leave, resets to Shared. Never sticky. |
| Post cards | Avatar initials, author name, timestamp, body text, visibility badge (lock icon for private) |
| Private posts | Subtle orange tint, "Just Me" badge, invisible to other users |
| Delete | Own posts only, confirmation dialog, optimistic removal |
| Failed drafts | FailedPostCardView with retry + discard buttons, calm red tint |
| Skeleton | 3 shimmer cards matching PostCardView layout (pulse animation) |
| Reactive | `watchPosts()` stream auto-updates when posts change locally |
| Privacy | Server-side RLS + PowerSync sync rules + client-side SQL filter (defense-in-depth) |
| Error handling | Failed posts queued as FailedDraft with retry affordance |
| UI | Auto-scroll to newest post, pinned composer at bottom |
| Localization | All strings in 4 languages |

### PowerSync (Local-First Sync)

**What it does**: Local SQLite database syncs with Supabase Postgres. All reads instant from local DB. Writes save locally first, upload to Supabase in background.

| Aspect | Details |
|---|---|
| Key files | `AppSchema.swift`, `PowerSyncConfig.swift`, `SupabaseConnector.swift`, `SyncManager.swift` |
| Schema | 9 tables mirroring Supabase, with indexes on foreign keys and composite (trip_id + start_at) |
| Connector | `fetchCredentials()` returns Supabase JWT; `uploadData()` processes CRUD queue |
| Type conversion | `TypedCrudData` converts PowerSync string values to proper JSON types for PostgREST (boolean, integer) |
| Lifecycle | Connect on sign-in, disconnect + clear on sign-out |
| Sync status | `isSyncConnected`, `hasSynced`, `lastSyncedAt` exposed on AppState |
| Sync rules | Deployed on PowerSync dashboard; private posts sync only to owner |
| Reactive queries | `watch()` returns AsyncThrowingStream; ViewModels consume for live UI updates |
| Error handling | Print errors, graceful fallback |
| joinTrip exception | Direct Supabase call (trip not in local DB until user is a member) |

### Settings

**What it does**: Profile display, sign-in method info, legal placeholders, sign out with confirmation, delete account placeholder.

| Aspect | Details |
|---|---|
| Key files | `SettingsView.swift`, `ProfileHeaderView.swift`, `SignInMethodRow.swift` |
| Profile | 64pt avatar with initials, display name, email (truncated middle) |
| Sign-in method | Detects Apple vs Email from JWT metadata |
| Sign out | Confirmation dialog → disconnects sync → clears local data → navigates to auth |
| Delete account | Confirmation dialog (placeholder — full implementation in Phase 5) |
| Legal | Privacy Policy + Terms of Service button placeholders |
| UI | List (.insetGrouped), plain back button |
| Localization | All strings in 4 languages |

### Design System

**What it does**: Shared visual tokens and components for consistent styling.

| Component | Details |
|---|---|
| `ColorTokens` | System backgrounds, text hierarchy, personal tint (orange), sync state tints |
| `TypographyTokens` | Font presets: largeTitle (bold) → caption (regular), consistent hierarchy |
| `ContextChip` | Capsule showing "Group" or "Personal · Name" with appropriate tint |
| `SyncStateIndicator` | Subtle icons: synced (empty), pending (clock), syncing (spinner), failed (triangle) |
| `PlainToolbarModifier` | Replaces iOS 26 Liquid Glass back button with plain chevron via `.plainBackButton()` |

### Localization

**What it does**: Full 4-language support via Xcode String Catalog.

| Aspect | Details |
|---|---|
| File | `Localizable.xcstrings` (String Catalog format, Xcode 15+) |
| Languages | English (en), Japanese (ja), Chinese Traditional (zh-Hant), Chinese Simplified (zh-Hans) |
| Key groups | auth.*, home.*, trip.*, timeline.*, block.*, post.*, bill.*, summary.*, settings.*, state.*, common.* |
| Tone | EN: calm/friendly, JA: polite (です/ます), zh-Hant: clear/professional, zh-Hans: clear/professional |
| Date/number | Foundation formatters (auto-localized), never hardcoded patterns |

### Performance

**What it does**: Built-in performance optimizations following performance.md rules.

| Optimization | Details |
|---|---|
| @Observable migration | All ViewModels use iOS 17+ @Observable (not @ObservableObject/@Published) |
| LazyVStack | All scrollable lists use LazyVStack with stable database IDs |
| Task cancellation | All ViewModels cancel Tasks in deinit, store as nonisolated(unsafe) |
| [weak self] | All async closures use weak self to prevent retain cycles |
| 500ms loading minimum | Loading states hold for 500ms to prevent flash |
| Local-first reads | UI reads from local SQLite — never waits for network |
| Pagination | Repositories support limit/offset parameters |
| onAppear guards | Loading functions check if data already exists before showing spinner |

---

## Supabase Configuration

### Tables (9)

| Table | Purpose | Key constraints |
|---|---|---|
| users | Profile linked to auth.users | ON DELETE CASCADE from auth.users |
| trips | Top-level container | end_date >= start_date, unique invite_link |
| trip_members | User-trip junction | unique (trip_id, user_id), role IN (owner, member) |
| blocks | Timeline moments | context IN (group, personal) |
| posts | Memory entries | visibility IN (shared, private) |
| post_media | Attached media | media_type IN (photo, video), upload_status IN (queued, uploading, uploaded, failed) |
| bills | Expense records | amount >= 0, integer (smallest currency unit) |
| bill_shares | Per-person splits | share_amount >= 0, unique (bill_id, user_id) |
| payments | Repayments | amount > 0, payer_id <> receiver_id |

### RLS Policies

- **users**: Any authenticated reads; users edit own profile only
- **trips**: Trip members read; any auth creates; owner updates
- **trip_members**: Members see members; self or member inserts; self or owner deletes
- **blocks**: Members read; member + creator inserts; creator or owner updates/deletes
- **posts**: Members read shared; only owner reads private (NEVER leak); owner inserts/updates/deletes
- **post_media**: Follows parent post visibility
- **bills**: Members read; payer inserts/updates/deletes
- **bill_shares**: Members read; bill creator manages
- **payments**: Members read; payer inserts/updates/deletes

### Triggers

| Trigger | Action |
|---|---|
| `on_auth_user_created` | Auto-creates public.users profile from auth metadata |
| `on_trip_created` | Auto-adds creator as owner in trip_members |

### Helper Functions

| Function | Purpose |
|---|---|
| `is_trip_member(trip_id)` | Checks if current user is a member (used by all RLS policies) |
| `trip_id_for_block(block_id)` | Lookup for post/media policies |
| `trip_id_for_bill(bill_id)` | Lookup for bill_shares policies |
| `is_trip_owner(trip_id)` | Checks owner role |

### PowerSync Connection

| Setting | Value |
|---|---|
| Endpoint | `https://69c73e69a112d86b20541c05.powersync.journeyapps.com` |
| Auth | JWKS URI from Supabase (`/auth/v1/.well-known/jwks.json`) |
| Database | Direct Postgres connection from Supabase |
| Publication | `powersync` (all 9 tables) |
| Sync rules | Deployed — private posts sync only to owner, trip-scoped data to members |

---

## Known Issues / Technical Debt

| Issue | Location | Notes |
|---|---|---|
| Supabase credentials hardcoded | `SupabaseConfig.swift` | Should use xcconfig per environment (Dev/Staging/Prod) |
| PowerSync URL hardcoded | `PowerSyncConfig.swift` | Same — should be xcconfig |
| No PaymentEntrySheet | `Features/Bills/` | Referenced in blueprint but not created (Phase 4) |
| BillEntryView is placeholder | `BillEntryView.swift` | Shows placeholder text only (Phase 4) |
| TripSummaryView is placeholder | `TripSummaryView.swift` | Shows empty state only (Phase 4) |
| Delete account is placeholder | `SettingsView.swift` | Confirmation dialog exists but no backend implementation (Phase 5) |
| No media upload queue | — | PostMedia model exists but no upload pipeline (Phase 3) |
| No real-time member updates | ViewModels | Members fetched once on load, not watched reactively |
| post_media not in sync rules | `powersync-sync-rules.yaml` | Removed due to subquery limitation; will need trip_id denormalization (Phase 3) |
| trip_id added to posts/bill_shares | Supabase migration | Denormalized for PowerSync sync rules; needs corresponding app code update for post creation |
| Ghost blocks not persisted | `DaySectionView.swift` | Pure UI scaffolding — intentional per blueprint, not a bug |

---

## Phase Status

| Phase | Status | Tag | Details |
|---|---|---|---|
| Phase 1 | Complete | `v0.1.0-phase1` | Auth, Home, Trip Setup, Trip Members, Timeline shell, Blocks, Group/Personal, Ghost blocks, Add Moment |
| Phase 2 | In progress | — | Posts (done), Shared/Just Me composer (done), PowerSync sync (done), Filters (done), Same-time clusters (done) |
| Phase 3 | Not started | — | Media metadata, media upload queue, upload states, placeholders, retry handling |
| Phase 4 | Not started | — | Bills, bill shares, payments, summary screen, multi-currency balances |
| Phase 5 | Not started | — | Archive, empty states polish, pending indicators, cost controls, instrumentation, beta testing |

### Phase 2 Commit History

```
2b8e413 [Phase 2] Add PowerSync local-first sync integration
e3a75f4 [Phase 2] UI polish: inline ghost blocks, header edits, toolbar cleanup
0a2054a [Phase 2] Performance audit: migrate to @Observable, fix ForEach IDs, add Task cancellation
da672d7 [Phase 2] Rename Add Moment to Activity across all UI labels
c1dd315 [Phase 2] Add post system with composer, stream, and CRUD
```

---

## Rule Files Summary

| File | Purpose |
|---|---|
| `.claude/rules/CLAUDE.md` | Project structure, stack, build phases, git workflow, conventions |
| `.claude/rules/backend.md` | Supabase schema, RLS policies, auth, storage, PowerSync integration |
| `.claude/rules/compliance.md` | App Store requirements, privacy manifests, account deletion, permissions |
| `.claude/rules/copy-analytics.md` | Copywriting tone, privacy labels, beta analytics metrics |
| `.claude/rules/design-system.md` | Visual contracts: Group vs Personal, privacy, time clusters, empty states |
| `.claude/rules/devops.md` | Entitlements, environments, TestFlight, cost controls, Xcode settings |
| `.claude/rules/frontend.md` | SwiftUI patterns, offline-first, timeline, composer, money handling |
| `.claude/rules/localization.md` | 4 languages, String Catalogs, key naming, tone per language |
| `.claude/rules/performance.md` | View optimization, memory management, CPU/battery, app launch, Instruments |
| `.claude/rules/qa.md` | Edge cases: network, privacy leakage, ledger, timezone, empty states |
| `.claude/rules/scope-control.md` | Phase gates, feature rejection list, numeric limits, cost controls |
| `.claude/rules/sync.md` | Data vs media sync, ghost attachment rule, auth refresh flow, cost controls |
| `.claude/rules/user-flows.md` | Every user action's 4 states (success/loading/error/edge), error catalog |
| `.claude/rules/visual-design.md` | Brand identity, color palette, typography, spacing, component standards |
