---
description: Sync architecture rules for PowerSync data sync and background media upload queue
globs: "**/Sync/**,**/MediaQueue/**,**/PowerSync**,**/*Sync*.swift,**/*Upload*.swift,**/*Queue*.swift"
---

# Sync Architecture

## Fundamental Rule
Data sync and file sync are separate systems. Never merge them.

## Data Sync (PowerSync)
- PowerSync syncs structured data into on-device SQLite
- Covers: trips, trip_members, blocks, posts (metadata), bills, bill_shares, payments
- Sync is bidirectional — local writes push up, remote changes pull down
- Private posts (visibility = 'private') sync ONLY to the owning user's PowerSync bucket
- Use PowerSync sync rules to enforce this server-side

## Media Sync (Background URLSession)
- Media uploads use Apple's background URLSession — continues when app is suspended
- Upload queue is a local state machine per media item: queued → uploading → uploaded / failed
- Retry failed uploads with exponential backoff
- Never block post creation on media upload — post can exist with upload_status = 'pending'

## Ghost Attachment Rule
- If post text/data synced but media file not ready: show skeleton placeholder
- Never attempt to render a remote image/video that hasn't been confirmed uploaded
- Show retry affordance on failure — never silent disappearance

## Conflict Avoidance
- Posts are append-only — never co-edit the same content object
- Block metadata is small and patchable (title, context, time, location_text)
- Bills are explicit records — no summary counters as source of truth
- Same-time moments: keep data honest, handle visual grouping in UI only

## Auth Refresh Flow
After long offline periods, execute in order:
1. Restore local session
2. Refresh Supabase auth token if expired
3. Resume PowerSync data sync
4. Resume / reconcile media upload queue

## Cost Controls at Sync Layer
- Compress every photo to target 1.5MB before queuing — never reject, always compress harder if needed
- Re-encode every video to H.264 1080p 30fps targeting 30MB before queuing — never reject, never show file size to user
- Video cap: 60 seconds — recorder shows countdown timer, library selection shows trimmer if over 60s
- Track cumulative trip storage locally — at 1.5GB show one-time calm notice
- Past 2GB: auto-increase compression (photo → ~800KB, video → ~15MB), uploads continue silently
- At 5GB hard ceiling: pause remote media sync, content stays safe locally
- Use thumbnail-first loading for media display
- Generate video thumbnail locally on capture for immediate display in stream
