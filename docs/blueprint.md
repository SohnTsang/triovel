
# Group Travel OS — Full Blueprint (AI-Friendly UI / UX Contract)

## 1. Global UX Principles

### The app must feel:
- Fast
- Calm
- Trustworthy
- Offline-safe
- Not cluttered

### The app must avoid:
- Hidden state
- Ambiguous privacy
- Tiny unreadable parallel cards
- Form-heavy creation flows
- Fake precision in money or time
- Noisy notifications and visual clutter

---

## 2. Global Navigation Structure

### App Launch
1. Restore session
2. Restore local cached app state
3. Land on Home

### Main screens
1. Global Home
2. Trip Setup / Join Trip
3. Trip Timeline
4. Add Moment Sheet
5. Block Detail
6. Bill Entry Sheet
7. Payment Entry Sheet
8. Trip Summary

---

## 3. Global Home Blueprint

### Purpose
Main launchpad for all trips.

### Layout
- Top bar: app title or logo + settings/profile icon
- Main section: Active Trips
- Secondary section or access point: Archived Trips
- Floating action button: `+ New Trip`

### Active trip card
Each card should show:
- cover image
- trip title
- dates
- member avatars

### Actions
- tap trip card → open trip timeline
- tap `+ New Trip` → Trip Setup
- tap `Join Trip` / paste invite → join flow
- tap `Archived Trips` → archived trip list

### Empty state
If user has no trips:
- friendly onboarding text
- Create Trip button
- Join Trip secondary option

### Rules
- Home must feel light
- Archived data must never feel lost
- Free user active trip ownership limit should apply here quietly

---

## 4. Trip Setup Blueprint

### Purpose
Create a trip with the least friction possible.

### Required inputs
- Trip title
- Start date
- End date

### Auto-filled defaults
- Display timezone = device timezone
- Base currency = device locale currency if available

### Editable later
- Cover image
- Base currency
- Display timezone
- Members

### Actions
- Create Trip
- Cancel

### Rules
- Do not require member invites upfront
- Do not require map/location selection
- Do not overload this screen

---

## 5. Trip Timeline Blueprint

### Purpose
The main screen and emotional spine of the app.

### Header
- Back button
- Trip title
- Trip Summary button/icon

### Sticky day ribbon
Position: under header

Shows:
- Day 1 / Day 2 / Day 3...
- short dates

Behavior:
- tap day → jump vertically to that day
- vertical scrolling → highlighted day updates automatically

### Filter bar
Position: under day ribbon

Controls:
- All
- Group
- Personal

If Personal selected:
- show person chips if more than one relevant person exists

Rules:
- filters are temporary session-only
- leaving trip or relaunching app resets filters to All

### Day section body
Each day can contain:
- ghost blocks
- real blocks
- same-time clusters

### Ghost blocks
Visual style:
- faded
- dashed outline or subtle ghost appearance

Labels:
- Breakfast
- Lunch
- Dinner

Behavior:
- tap ghost block → open Add Moment with inherited day and suggested title
- if never tapped, it never becomes real content

### Real Group block card
Visual style:
- full-width standard card
- main timeline visual

Contains at minimum:
- title
- time
- maybe small member avatars / cover thumbnail
- subtle state icon if pending/syncing

### Real Personal block card
Visual style:
- full-width card
- clear `Personal · Name` chip
- subtle tint/border variation
- creator visually primary

### Same-time cluster
Visual style:
- single shared time label
- multiple block cards under it
- cards remain readable and tappable
- never tiny side-by-side mini blocks

Behavior:
- if too many in one slot, use compact stack with expansion

### Timeline state indicators
Each block card may show subtle state icons:
- pending
- syncing
- failed media inside

### Floating action button
`+ Add Moment`

Behavior:
- opens Add Moment sheet
- inherits current visible day by default

---

## 6. Add Moment Sheet Blueprint

### Purpose
Fastest creation interaction in the app.

### Container
- half sheet or modal sheet
- keyboard opens immediately
- focus in title field

### Field order
1. Title
2. Group / Personal toggle
3. Time

### Title
- large text field
- placeholder: “What’s happening?” or “Where to?”

### Context toggle
- segmented control
- Group default
- Personal as explicit override

### Time
- simple time picker or quick time button
- current day default: Now (rounded)
- future day default: midday neutral value

### Inheritance
The sheet should inherit:
- day from currently visible timeline day
- or day from tapped ghost block
- or time slot context if relevant

### Explicitly not shown here
- map search
- online location search
- participant picker
- bill inputs
- media picker as a required first step

### Actions
- Save / Create
- Cancel

### After create
Immediately push into the newly created Block Detail screen.

---

## 7. Block Detail Blueprint

### Purpose
The place where users actually capture the trip.

### Header section
Shows:
- title
- context chip (Group / Personal)
- time
- optional location text

### Header edit rules
- block creator or trip owner can edit header
- others can view only

### Main stream
One unified chronological stream containing:
- shared memory posts
- owner-only private posts
- bill cards
- media syncing shells
- failed upload states

### Shared memory post style
- standard card
- visible to trip members

### Private memory post style
- only visible to owner
- subtle visual difference
- labeled Just Me if needed inside owner UI
- no trace shown to others

### Bill card style
- visually distinct from posts
- amount
- currency
- payer
- included people summary

### Media card style
- image grid, single image, or video preview
- must support syncing placeholder and failure state

### Ghost attachment shell
If text/data row exists but file not ready:
- show skeleton / media syncing shell
- never attempt to load missing remote file directly
- give retry affordance on failure

### Composer area
Order:
1. Shared | Just Me segmented control
2. text input
3. attached media preview
4. actions row: camera / library / add bill / send

### Composer rules
- every new draft starts Shared
- if user switches to Just Me, it applies only to current draft
- after send/cancel/leave, next draft resets to Shared
- app never remembers last visibility choice

### Post permissions
- any trip member can add to visible block
- user edits/deletes only own posts
- no one edits others’ posts

### System states inside block
Each post/media may show:
- saved
- syncing
- uploaded
- failed
- retrying

UI must be graceful, not alarming.

---

## 8. Bill Entry Sheet Blueprint

### Purpose
Simple, explicit ledger entry tied to a block.

### Layout
- amount field
- currency selector
- payer selector
- included members checklist
- save button

### Defaults
- payer = current user
- all trip members included by default

### Logic
- equal split across checked users
- create bill + bill shares

### Rules
- bill is always shared
- no privacy toggle
- no OCR
- no attendance assumptions

### After save
Return to Block Detail and show the bill in the stream.

---

## 9. Payment Entry Sheet Blueprint

### Purpose
Reflect real-world repayment.

### Layout
- payer selector
- receiver selector
- amount
- currency
- optional note
- save button

### Rules
- tied to trip, not to a specific block
- payment affects summary balances immediately after sync/local calculation

### After save
Return to Trip Summary.

---

## 10. Trip Summary Blueprint

### Purpose
Calm money/admin dashboard.

### Header
- cover image
- trip title
- dates
- member avatars

### Money section
Grouped by currency:
- JPY section
- AUD section
- etc.

Each section shows:
- my balance
- who owes whom
- Record Payment button

### Empty state
If no expenses:
- “No shared expenses yet”
- no charts
- no noisy empty widgets

### Admin section
- Archive Trip

### Archive behavior
- Archive hides trip from Active Trips
- Archived Trips remain accessible from Home

### Explicit exclusions
Do not put here:
- timeline posts
- highlight reels
- public export link
- receipt feed by default

Summary = filtered closure, not feed exploration.

---

## 11. Group vs Personal Visual Contract

### Group block
- neutral/default card style
- main trip spine
- visually primary

### Personal block
- clear `Personal · Name` chip
- subtle tint/border difference
- creator identity visually obvious

### UX implication
Personal means:
- “mainly this person’s moment”
not:
- “nobody else may see it”

---

## 12. Privacy Visual Contract

### New draft default
Shared is active every time a new draft starts.

### Just Me visual state
When Just Me is active:
- segmented control changes visibly
- composer environment can subtly shift
- placeholder text may change to “Add a private note…”

### Reset rule
Leaving the draft resets the next draft to Shared.

### Privacy guarantee
Private posts:
- invisible to others
- absent from shared counts
- no placeholder leakage

---

## 13. Time and Timezone Visual Contract

### Timeline ordering
Always based on trip display timezone.

### Local label
If different timezone applies:
- show small local timezone label in subtitle

### Same-time moments
Represent visually as clusters.
Do not distort actual time values for layout convenience.

---

## 14. System State Visual Contract

### Global principle
Every system state must be visible and graceful.

### Timeline card states
Possible subtle indicators:
- pending
- syncing
- failed media inside

### Block-level media states
Possible visible states:
- saved
- syncing
- uploaded
- failed
- retrying

### Never do
- broken image icon as primary state
- silent disappearance
- hidden failure with no retry path

---

## 15. Offline Behavior Contract

### Must work offline
User must be able to:
- open cached trip
- view days/blocks
- create block
- write post
- add bill
- add payment
- attach media

### User experience rule
Every action should feel like:
- saved locally first
- synced later

---

## 16. Empty States Contract

### Home
No trips yet:
- friendly onboarding text
- Create Trip
- Join Trip

### Timeline day
If little or no content:
- ghost blocks provide the default structure
- no dead blank void

### Summary
If no bills:
- calm “No shared expenses yet”

### Archived Trips
If none:
- simple empty state, not a blank screen

---

## 17. Excluded UI / Feature Bloat

Do not design or build in V1:
- attendance matrix
- per-block invites
- live location sharing
- map-led Add Moment flow
- public web spectator mode
- algorithmic highlights
- merge conflict UI theater
- live FX conversion
- OCR receipt scan
- deep branch tree UI
- enterprise-style admin matrix

---

## 18. QA / Acceptance Criteria (UI)

### Timeline
- day ribbon updates correctly
- filters reset correctly
- same-time blocks remain readable
- ghost blocks do not become real unless tapped

### Add Moment
- keyboard auto-focus works
- inherited day is correct
- save routes directly into block

### Block Detail
- new post always starts Shared
- private post invisible to others
- media placeholder appears if file not ready
- failed upload has retry path

### Bills / Payments
- bill defaults to all members checked
- payment updates summary correctly
- mixed currencies never collapse into fake one-line total

### Summary
- no bills empty state works
- archive hides from active and shows in archived access point
- record payment flow accessible and simple

---

## 19. Final UI Rules

1. Home must feel calm and obvious
2. Trip Setup must stay light
3. Timeline is the main surface
4. Add Moment must be a 3-second flow
5. Group vs Personal must be visually clear
6. Shared vs Just Me must be explicit and non-sticky
7. Same-time blocks must cluster, not shrink into unreadable cards
8. Summary must be money/admin only
9. Every important state must be visible
10. Privacy and sync trust matter more than clever animations
