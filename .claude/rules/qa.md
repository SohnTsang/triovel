# QA & Edge-Case Rules

## Assume the Worst
- User has terrible network, switches timezones mid-trip, and tries to break ledger math
- App may be backgrounded or killed during media upload at any time
- Multiple users may create same-time blocks simultaneously

## Network & Offline Testing
- Verify every user action works fully offline (create block, write post, add bill, attach media)
- Force-test app kill during media upload → app must recover gracefully on relaunch
- Verify ghost attachment rule: post text synced but media pending → show skeleton shell, never crash
- Test auth token expiry during long offline → must refresh and resume without data loss

## Privacy Leakage Testing
- Private posts must NEVER appear in another user's local SQLite database
- Private posts must be excluded from shared memory counts and any UI indicators
- Switching Just Me → Shared → send must produce a Shared post, not private
- Verify composer always resets to Shared after send/cancel/leave

## Ledger & Currency Testing
- Attempt to blend JPY and AUD — fail the test if app produces a combined total
- Test bill with subset of members — verify shares calculate correctly
- Test payment recording — verify Summary balances update correctly
- Test zero-amount edge case, single-member trip bill, self-payment

## Time & Timezone Testing
- Create blocks in different timezones — verify timeline sorts by trip display timezone
- Test same-time block creation → UI must cluster them, never silently mutate timestamps
- Test day boundary edge case (block at 23:59 vs 00:01)
- Verify sticky day ribbon updates correctly on scroll

## Empty State Validation
- Home with no trips: shows onboarding, not blank screen
- Timeline day with no blocks: shows ghost blocks
- Summary with no bills: shows "No shared expenses yet"
- Archived trips section when empty: simple empty state

## Filter Testing
- Set filter to Personal → leave trip → reopen → filter must reset to All
- Kill app with filter active → relaunch → filter must reset to All
- Verify Personal filter shows person chips when multiple people have personal blocks
