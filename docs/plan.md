
# Group Travel OS — Full Plan (AI-Friendly Build Spec)

## 1. Product Definition

### One-line product
A **Trip** is one shared container with a **day-based timeline**.
Users create or add to **blocks** for moments, then post **memories** and **bills** inside those blocks.

### Core promise
**Plan the anchors. Capture the reality. Share the trip.**

### What the app is
- A shared trip timeline
- A memory organizer tied to moments
- A light contextual group ledger
- An offline-first iPhone app

### What the app is not
- A heavy itinerary manager
- A permission-heavy collaboration tool
- A public social feed
- A live location sharing app
- An AI highlights engine
- A complex accounting tool

---

## 2. Product Philosophy

### 2.1 One trip boundary
The only access boundary is the **Trip**.
Everyone invited to the trip can see the same trip timeline.
No block-level invites.

### 2.2 Shared timeline, mixed realities
The timeline is shared, but not every block has to represent a shared group moment.

A block can be:
- **Group**
- **Personal**

This solves:
- Different origin flights
- Solo detours
- Late arrivals
- Different airport transfers
- Relocation-style journeys
- Parallel moments during the same day

### 2.3 Conflict avoidance over conflict resolution
Avoid collisions by design:
- Append posts instead of co-editing them
- Keep block metadata small
- Keep bills explicit
- Keep time honest
- Separate data sync from media upload

### 2.4 Plan lightly, capture fast, share naturally
The app should:
- Feel structured before the trip
- Feel fast during the trip
- Feel calm at the end of the trip

---

## 3. Core Objects

### 3.1 Trip
Contains:
- title
- start_date
- end_date
- cover_image
- invite_link
- members
- display_timezone
- base_currency
- archived flag

### 3.2 Day Timeline
Navigation layer only.
Contains:
- day label
- date
- ghost blocks
- real blocks
- same-time clusters

### 3.3 Block
One moment on the timeline.

Fields:
- title
- context (`group` or `personal`)
- created_by
- start_at
- end_at (optional)
- location_text (optional)
- display_timezone
- local_timezone (optional)
- untimed_rank (optional)
- cover_media_id (optional)

### 3.4 Memory Post
Can be:
- text
- photos
- video
- text + media

Visibility:
- `shared`
- `private`

### 3.5 Bill
Contains:
- amount
- currency
- payer
- included_members
- equal split default
- explicit shares

### 3.6 Payment
Represents actual repayment.
Contains:
- payer
- receiver
- amount
- currency
- optional note

---

## 4. Main User Flows

### 4.1 Plan flow
User can:
- Create a trip
- Join a trip
- Open the timeline
- Activate ghost blocks
- Create custom blocks
- Edit allowed block headers

Rule:
This is **anchor planning**, not full itinerary management.

### 4.2 Capture flow
User can:
- Open a day
- Open a block
- Add note
- Add text + photos/video
- Choose Shared or Just Me
- Add bill
- Do all of it offline

Rule:
Capturing a moment must be faster than switching between Photos, Notes, and a calculator.

### 4.3 Share flow
User can:
- See the same shared timeline
- Add to any visible block
- View others’ shared posts
- Keep private posts invisible to others
- View balances
- Record repayments

Rule:
Sharing happens by **adding to the same block**, not by posting to a noisy feed.

---

## 5. Timeline Logic

### 5.1 Sticky day ribbon
At the top of the trip timeline:
- Day 1 / Day 2 / Day 3...
- Short dates shown underneath or alongside

Behavior:
- Tap day → jump to that day
- Scroll across day boundary → ribbon updates automatically

### 5.2 Filter bar
Shown under day ribbon:
- All
- Group
- Personal

If `Personal` is selected and multiple people are relevant:
- show person chips for filtering specific people

Rules:
- Filters are temporary session state only
- Filters must not persist across app relaunch in a way that causes “missing data” confusion

### 5.3 Ghost blocks
Faded placeholders:
- Breakfast
- Lunch
- Dinner

Rules:
- Optional only
- Tapping one turns it into a real block instantly
- If untouched, it never becomes real data
- Default context = Group
- They reduce planning friction

### 5.4 Same-time block handling
Do not use tiny side-by-side cards.
Do not fake timestamps.

Use **time-slot clusters**:
- Show shared time label once
- Show multiple blocks under that slot
- Expand to readable cards if needed

### 5.5 Pending state on timeline cards
Every block card may show subtle state indicators:
- normal
- pending
- syncing
- failed media inside

This must be calm, not alarming.

---

## 6. Group vs Personal Context

### 6.1 Group block
Use for:
- Dinner together
- Hotel check-in
- Museum visit
- Shared taxi
- Reunion point

Behavior:
- Standard visual style
- Any trip member can add posts
- Feels like the main spine of the trip

### 6.2 Personal block
Use for:
- My flight
- My airport transfer
- My solo detour
- My late arrival
- My own errand connected to the trip

Behavior:
- Still visible to trip members
- Clearly labeled `Personal · Name`
- Subtle visual distinction
- Creator visually primary
- UI should not strongly encourage everyone else to pile into it

Important:
Personal is **context**, not permission.

### 6.3 Guidance rule
Personal blocks are for meaningful solo moments, not every tiny action.
Small solo details should usually be:
- a private post
- or skipped entirely

not a new standalone timeline block.

---

## 7. Add Moment Flow

### 7.1 UI container
Use a sheet / half-sheet.
Keyboard opens immediately.
Cursor starts in the title field.

### 7.2 First 3 inputs only
1. **Title**
   - Large auto-focused text input
   - Placeholder: “What’s happening?” or “Where to?”

2. **Context**
   - Segmented control: Group / Personal
   - Default = Group

3. **Time**
   - Simple time picker
   - Default = Now for current day
   - Default = neutral midday value for future day

### 7.3 Day inheritance
The block inherits the day/date from where the user launched the flow:
- current visible day
- tapped ghost block
- tapped time slot

User should not have to choose day again by default.

### 7.4 Explicit exclusions from creation flow
Do not include in the first creation step:
- map search
- online location search
- member picker
- bill setup
- required media selection before save

### 7.5 After creation
After user creates the block:
- Go directly into the new block
- Do not send them back to the timeline first

---

## 8. Block Detail Logic

### 8.1 Header
Contains:
- title
- context chip
- time
- optional location text

Permissions:
- only block creator or trip owner can edit header details
- other members can view only

### 8.2 Unified memory stream
One chronological stream that can contain:
- shared posts
- private posts (owner only)
- bills
- syncing placeholders
- failed upload states

No separate notes tab and photo tab.

### 8.3 Composer
Above the input:
- Shared | Just Me

Then:
- text input
- attached media preview
- camera
- library
- add bill
- send

### 8.4 Visibility rules
Every new post starts as **Shared**.
User can switch current draft to **Just Me**.
After send, cancel, or leaving the compose state:
- next new draft resets to Shared
- app must not remember prior visibility choice

### 8.5 Private post rules
- Private posts are invisible to others
- Private posts do not affect shared counts
- No placeholder reveals private activity to others

### 8.6 Post permissions
- Any trip member can add to a visible block
- Users can edit/delete only their own posts
- No one edits other people’s posts

---

## 9. Money Model

### 9.1 Bills
Each bill is a source-of-truth record.

Bill entry default:
- all trip members included
- split evenly

User can:
- uncheck members
- explicitly include only specific members

Rules:
- Bills are always shared
- No privacy toggle on bills
- No hidden assumptions
- No attendance system

### 9.2 Payments
Payments are source-of-truth records for actual money movement.

Need from V1 because otherwise ledger only reflects theoretical debt.

### 9.3 Balance logic
Trip balances are derived from:
- bills
- bill shares
- payments

### 9.4 Currency logic
Never combine mixed currencies into one fake total.

If trip includes JPY and AUD:
- show separate balance groups
- only show converted total if there is an explicit deliberate conversion rule

---

## 10. Summary Screen Logic

### Purpose
Summary is:
- money/admin dashboard
- filtered closure
- not another timeline feed

### Includes
- trip header
- balances grouped by currency
- my balance
- who owes whom
- Record Payment
- Archive Trip

### Empty state
If no expenses:
- show calm “No shared expenses yet”
- no charts
- no noisy empty state

### Explicit exclusions
Do not include:
- highlight algorithms
- public web export
- receipt feed by default
- embedded timeline feed

---

## 11. Time and Timezone Rules

### 11.1 Trip display timezone
Each trip has one display timezone.
Default from device; editable later.

Controls:
- day boundaries
- block ordering
- displayed chronology

### 11.2 Local timezone labels
If a block occurs in another timezone:
- show local label as secondary text

Example:
- Timeline sorted in Sydney time
- Block subtitle says “Departs 7:15 PM JST”

### 11.3 Timed block ordering
Time is real.
Dragging a timed block means a real time edit.
Never use fake times like 4:01 PM to solve sorting.

### 11.4 Untimed blocks
Use sortable rank only for untimed / draft / loose planning items.

---

## 12. Technical Architecture (Supabase-first)

### 12.1 Stack
- Supabase: backend, Postgres, Auth, Storage
- PowerSync: local-first sync into on-device SQLite
- Background media upload queue: separate from data sync

### 12.2 Core principle
**Data sync and file sync are separate systems.**

Data sync handles:
- trips
- trip members
- blocks
- posts
- bills
- payments

Media sync handles:
- photo/video upload
- retries
- upload state
- background completion

### 12.3 Why this matters
A post may sync before its media is uploaded.
The app must handle that gracefully.

---

## 13. Data Model Direction

### Tables
- users
- trips
- trip_members
- blocks
- posts
- post_media
- bills
- bill_shares
- payments

### Modeling rules
#### Posts
Append-only.
Never co-edit one big shared memory blob.

#### Block metadata
Keep small:
- title
- context
- time
- location text

#### Bills
Explicit records, not just counters.

#### Payments
Explicit records, not inferred.

#### Media
Post can exist before media finishes uploading.

---

## 14. Sync and Conflict Rules

### 14.1 Rich content
Never make multiple users co-edit the same rich content object.

### 14.2 Header edits
Keep metadata small and patchable.

### 14.3 Bills
Money truth lives in explicit bill and payment records.

### 14.4 Same-time moments
Keep data honest.
Handle grouping in UI.

### 14.5 Ghost attachment rule
If post exists but media is not ready:
- show safe placeholder shell
- do not try to render remote image/video prematurely
- allow retry if upload failed

---

## 15. Security Rules

### Backend enforcement
Must be enforced on backend, not only UI.

Rules:
- only trip members can access trip-scoped data
- only block creator or trip owner can edit block header
- users can edit/delete only their own posts
- private posts sync only to owner
- only trip members can create bills/payments

### Privacy sync rule
Private posts must never sync to other users’ devices.

---

## 16. System States and Reliability

### 16.1 Offline-first rule
Every important action should feel like:
- saved locally first
- synced later

### 16.2 Visible states
Support these visible states gracefully:
- saved
- pending
- syncing
- uploaded
- failed
- retrying

### 16.3 Auth refresh rule
After long offline periods:
1. restore session
2. refresh auth if needed
3. resume data sync
4. resume/reconcile media queue

### 16.4 Schema stability rule
Because this app uses:
- remote relational schema
- local synced schema
- local-first database

V1 schema should be treated as stable.
Prefer additive changes later.

---

## 17. Cost-Control Rules for V1

### Hard controls
- photo compression before upload
- short video cap
- limit number of owned active trips for free users

### Soft controls
- warn when one block gets too media-heavy
- thumbnail-first loading
- track storage/egress usage per trip

### Principle
Protect costs without making the product feel cheap.

---

## 18. Business Model Direction

### V1
Free beta.

Goal:
- validate real usage
- test collaboration patterns
- measure storage behavior

### Later monetization
Charge for:
- higher-fidelity media
- longer videos
- more active trips
- deeper archive/permanence

Do not charge for:
- inviting members
- basic trip collaboration
- core ledger trust

---

## 19. Explicit Exclusions

Deliberately out of V1:
- attendance tracking
- block-level invites
- live location sharing
- map-first creation flow
- public spectator web links
- algorithmic highlights
- auto-merge conflict UI
- live FX conversion
- OCR receipts
- deep branching UI
- enterprise permission matrices

---

## 20. Build Order

### Phase 1
- auth
- home
- trip setup
- trip members
- timeline shell
- blocks
- Group/Personal context
- ghost blocks
- Add Moment flow

### Phase 2
- posts
- Shared/Just Me composer
- local-first sync
- filters
- same-time clusters

### Phase 3
- media metadata
- media upload queue
- upload states
- placeholders
- retry handling

### Phase 4
- bills
- bill shares
- payments
- summary screen
- multi-currency balances

### Phase 5
- archive trip
- empty states
- pending indicators
- cost controls
- instrumentation
- real-travel beta testing

---

## 21. Final Locked Rules

1. Trip is the only access boundary
2. Timeline is the main product surface
3. Blocks are shared containers with Group or Personal context
4. Everyone can add; structure edits stay limited
5. Ghost blocks reduce planning friction
6. Every new memory post starts Shared
7. Private state never persists past the current draft
8. Bills are explicit, manual, and currency-aware
9. Payments are included from day one
10. Same-time moments cluster in UI
11. Time stays honest
12. Offline save happens before sync
13. Summary is money/admin, not feed/noise
14. No fake combined totals across currencies
15. Data sync and media sync are separate
16. Private posts never sync to other users
17. System states must be visible and graceful
18. Schema stability matters from day one
19. Cost controls are part of product design
