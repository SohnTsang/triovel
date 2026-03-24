# Canonical Examples — Tricky Flows

Reference examples for behaviors that span multiple layers (UI, local DB, sync, backend).
When in doubt about implementation, match these exact patterns.

---

## 1. Composer Visibility Reset

The Shared/Just Me toggle must reset to Shared after every interaction.

```
State: User opens Block Detail, taps composer
→ Toggle shows: [Shared ✓] [Just Me]

State: User switches to Just Me, types "quiet moment at the temple"
→ Toggle shows: [Shared] [Just Me ✓]
→ Placeholder changes to: "Add a private note…"

State: User taps Send
→ Post created with visibility: "private"
→ Composer clears
→ Toggle RESETS to: [Shared ✓] [Just Me]

State: User starts typing again without touching toggle
→ This new draft is Shared — not private
→ Toggle shows: [Shared ✓] [Just Me]

State: User switches to Just Me, then taps Cancel (or leaves the screen)
→ Draft discarded
→ Next time composer opens: [Shared ✓] [Just Me]
```

Rule: The app never remembers the previous visibility choice. Every new draft starts Shared. No exceptions.

---

## 2. Ghost Block Conversion

Ghost blocks are visual scaffolding that become real blocks only when tapped.

```
State: Timeline Day 2 loads
→ Ghost blocks visible: [Breakfast] [Lunch] [Dinner]
→ These are NOT in the database — pure UI scaffolding

State: User taps [Lunch] ghost block
→ Add Moment sheet opens
→ Title pre-filled: "Lunch"
→ Day inherited: Day 2
→ Time: midday default (12:00)
→ Context: Group (default)

State: User edits title to "Ramen in Shibuya", taps Save
→ New block INSERT into local SQLite:
  {
    "id": "blk_abc123",
    "trip_id": "trip_xyz",
    "title": "Ramen in Shibuya",
    "context": "group",
    "start_at": "2026-07-15T12:00:00+09:00",
    "created_by": "user_456"
  }
→ Ghost [Lunch] disappears from that time slot
→ Real block card appears in its place
→ User lands inside Block Detail for "Ramen in Shibuya"

State: User never taps [Breakfast] or [Dinner]
→ They remain ghost blocks forever — never written to DB
```

---

## 3. Media Placeholder States

A post can sync before its media finishes uploading. The UI must handle every state.

```
State: User takes a photo offline and posts it with text "sunset view"
→ Local DB: post created with body: "sunset view"
→ Local DB: post_media created with upload_status: "queued"
→ UI shows: text "sunset view" + media skeleton shell ("Media syncing...")

State: App comes online, upload starts
→ post_media.upload_status → "uploading"
→ UI shows: text + skeleton with subtle progress indicator

State: Upload completes
→ post_media.upload_status → "uploaded"
→ post_media.storage_path → "trips/trip_xyz/posts/post_789/sunset.jpg"
→ UI shows: text + actual image (thumbnail-first, then full)

State: Upload fails (network drop mid-upload)
→ post_media.upload_status → "failed"
→ UI shows: text + failed media card with "Tap to retry"
→ No broken image icon, no silent disappearance

State: User taps retry
→ post_media.upload_status → "queued" (re-enters upload queue)
→ UI shows: text + skeleton shell again
```

Key rule: The post text is always visible regardless of media state. Media state never blocks or hides the text content.

---

## 4. Same-Time Block Clustering

When multiple blocks share the same start_at time, the UI clusters them — never mutates timestamps.

```
Data: Three blocks on Day 3, all at 19:00
  { "title": "Dinner at Gonpachi",  "context": "group",    "start_at": "19:00" }
  { "title": "My pharmacy run",     "context": "personal", "start_at": "19:00" }
  { "title": "Karaoke booking",     "context": "group",    "start_at": "19:00" }

UI renders as a time-slot cluster:
  ┌─────────────────────────────┐
  │  7:00 PM                    │  ← single shared time label
  │  ┌───────────────────────┐  │
  │  │ Dinner at Gonpachi    │  │  ← full-width group card
  │  └───────────────────────┘  │
  │  ┌───────────────────────┐  │
  │  │ Personal · Sohn       │  │  ← full-width personal card with chip
  │  │ My pharmacy run       │  │
  │  └───────────────────────┘  │
  │  ┌───────────────────────┐  │
  │  │ Karaoke booking       │  │  ← full-width group card
  │  └───────────────────────┘  │
  └─────────────────────────────┘

NEVER:
  - Change "My pharmacy run" to 19:01 to force a different sort position
  - Show three tiny cards side-by-side
  - Collapse them into a "3 events" summary that requires expansion
```

Sort order within a cluster: group blocks first, then personal, then by created_at.

---

## 5. Multi-Currency Summary

Balances are always grouped by currency. Never combined.

```
Trip has expenses in JPY and AUD.

Bills:
  { "amount": 12000, "currency": "JPY", "payer": "Sohn", "split": ["Sohn", "Alex", "Kim"] }
  { "amount": 8500,  "currency": "JPY", "payer": "Alex", "split": ["Alex", "Kim"] }
  { "amount": 4500,  "currency": "AUD", "payer": "Kim",  "split": ["Sohn", "Alex", "Kim"] }

Payments:
  { "payer": "Kim", "receiver": "Sohn", "amount": 2000, "currency": "JPY" }

Summary screen renders:

  ┌─ JPY ──────────────────────┐
  │  Sohn: +2,000 yen          │  (paid 12,000, owes 4,000 share of bills, received 2,000 payment)
  │  Alex: -1,750 yen          │
  │  Kim:  -250 yen             │
  └────────────────────────────┘

  ┌─ AUD ──────────────────────┐
  │  Kim:  +3,000 AUD           │
  │  Sohn: -1,500 AUD           │
  │  Alex: -1,500 AUD           │
  └────────────────────────────┘

NEVER:
  - "Total: Sohn is owed ¥2,000 + A$1,500" ← no cross-currency totals
  - "Sohn is owed $35 equivalent" ← no FX conversion
  - Single combined balance section mixing JPY and AUD rows
```

---

## 6. Offline Write → Sync Flow

Every action saves locally first. The user never waits for network.

```
State: User is offline in a temple basement (no signal)

Action: Creates block "Tea Ceremony" at 14:00
→ Block written to local SQLite immediately
→ Block appears on timeline instantly
→ Subtle "pending" indicator on card (optional dot or icon)
→ User can tap into Block Detail right away

Action: Inside Block Detail, writes post "matcha was incredible" + attaches photo
→ Post written to local SQLite immediately
→ Post appears in stream instantly
→ Photo queued in media upload queue with status "queued"
→ UI shows: post text + media skeleton shell

Action: User adds a bill ¥3,200 split with Alex
→ Bill + bill_shares written to local SQLite immediately
→ Bill card appears in block stream
→ Summary screen (if opened) reflects the new bill immediately from local data

State: User walks outside, signal returns
→ PowerSync detects connectivity, begins syncing
→ Block, post, bill, bill_shares push to Supabase
→ "pending" indicators on timeline cards clear
→ Media upload queue starts processing the photo
→ Photo skeleton → uploading → uploaded → real image appears

The user never saw an error. They never waited. Everything felt instant.
```
