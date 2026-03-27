---
description: iOS app performance rules — memory, CPU, battery, scrolling, and SwiftUI-specific optimizations
globs: "**/*.swift"
---

# Performance & Optimization

## Core Principle
Performance is not a Phase 5 task. Every screen must be built performant from day one.
Fixing performance later means rewriting — build it right the first time.

## SwiftUI View Performance

### Prevent Unnecessary Redraws
- Mark ViewModels with @Observable (iOS 17+) — NOT @ObservableObject/@Published (old pattern causes excessive redraws)
- Split large views into small subviews — SwiftUI only redraws the subview whose state changed
- Never put expensive computation inside var body — pre-compute in ViewModel
- Use @State for view-local state, @Environment for shared state — never pass everything through bindings
- Use .equatable() on views with complex content to skip unnecessary diffing
- Use let properties instead of computed properties for data that doesn't change

### Lists and Scrolling
- Always use LazyVStack/LazyHStack inside ScrollView — never plain VStack for dynamic content
- Use LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) for timeline
- Never use .id(UUID()) on list items — this forces full recreation on every update
- Use stable, persistent IDs (database IDs) for ForEach identifiers
- Set .drawingGroup() on complex card views to flatten rendering into GPU layer
- Limit visible content — don't load 1000 posts at once, paginate with 20-item batches

### Images
- Always use .resizable() + .scaledToFill() with a fixed frame — never let images determine their own size
- Use AsyncImage with placeholder for remote images — never block UI on image load
- Cache images locally — don't re-download on every scroll
- Use thumbnail-first loading: show small image immediately, load full resolution on tap/zoom
- Compress and resize images before displaying — never render a 4000px image in a 200pt frame
- Use .clipShape(RoundedRectangle) AFTER frame, not before — avoids layout recalculation

### Animations
- Never animate inside ForEach or List — animate the container, not individual items
- Use .animation(.easeInOut, value: specificValue) — never .animation(.default) (animates everything)
- Always tie animations to specific value changes — never global
- Wrap heavy animations in withAnimation { } blocks, not .animation() modifier

## Memory Management

### Prevent Leaks
- Use [weak self] in ALL closures that capture self — especially network callbacks and timers
- Use Task { @MainActor [weak self] in } for async work in ViewModels
- Cancel Tasks in deinit — store as private var task: Task<Void, Never>? and call task?.cancel()
- Never store strong references to views or view controllers in singletons
- Use Instruments > Leaks to verify before each phase merge

### Image Memory
- Never hold full-resolution images in memory for list/grid display
- Downscale to display size before storing in memory
- Release off-screen images — use LazyVStack (it does this automatically)
- For media-heavy screens (Block Detail with many photos): limit in-memory cache to ~50MB

### Data
- Fetch only what's needed — use Supabase select() with specific columns, not select("*")
- Paginate all list queries — 20 items per page default
- Don't load all trips/blocks/posts on app launch — load on demand per screen

## CPU & Battery

### Background Work
- Use Swift concurrency (async/await) for all network calls — never block main thread
- Heavy processing (image compression, video re-encoding) runs on background queue: Task.detached(priority: .utility)
- Never do JSON parsing, image processing, or file I/O on @MainActor
- Media upload queue runs on background URLSession — already separate from main app process

### Timers and Polling
- Never use Timer for periodic data refresh — use Supabase realtime subscriptions or pull-to-refresh
- If polling is unavoidable, minimum interval 30 seconds
- Stop all timers/subscriptions when app backgrounds — resume on foreground

### Location and Sensors
- V1 does not use location — do not import CoreLocation or request permissions
- No GPS, no compass, no gyroscope — zero sensor usage in V1

## Network Performance

### Requests
- Never make duplicate requests — debounce user actions by 300ms
- Cancel in-flight requests when user navigates away
- Use URLCache for GET requests — Supabase client handles this
- Batch related writes when possible (create bill + bill_shares in one transaction)

### Offline Optimization
- PowerSync handles local-first reads — UI reads from SQLite, never waits for network
- Queue all writes locally first — sync when online
- Never show a loading spinner for data that exists locally

## App Launch Performance

### Cold Start
- Target: app usable within 2 seconds of tap
- Do NOT preload all data on launch — load Home screen data only
- Defer non-critical initialization (analytics, media queue setup) to after first frame renders
- Use lightweight session check on launch — don't hit network for auth if local token exists and isn't expired

### Warm Resume
- App should resume instantly from background — no splash screen or reload
- Preserve scroll position and navigation state across background/foreground cycles

## Instruments Checklist (run before each phase merge)
- Time Profiler: no main thread work over 16ms per frame (60fps target)
- Allocations: memory should not grow unbounded during scrolling
- Leaks: zero leaks
- Network: no duplicate requests, no unnecessary fetches
- Energy: no excessive CPU usage when app is idle

## Common SwiftUI Pitfalls to Avoid
- .onAppear firing multiple times in NavigationStack — guard with a flag
- Sheet/fullScreenCover retaining dismissed view's ViewModel — use @StateObject carefully
- Large @Published arrays causing full list redraw — use @Observable or granular updates
- NavigationLink initializing destination view eagerly — use NavigationLink(value:) + .navigationDestination
- .searchable causing keyboard flicker — debounce search text with 300ms delay
