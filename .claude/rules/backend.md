---
description: Backend rules for Supabase Postgres, Auth, Storage, and RLS
globs: "supabase/**,**/migrations/**,**/seed.sql,**/functions/**"
---

# Backend — Supabase / Postgres / RLS

## Schema (V1 Core Tables)
Implement these tables exactly:
- `users` — profile data, linked to Supabase Auth
- `trips` — title, start_date, end_date, cover_image, invite_link, display_timezone, base_currency, archived
- `trip_members` — user_id, trip_id, role, joined_at
- `blocks` — trip_id, title, context (group/personal), created_by, start_at, end_at, location_text, display_timezone, local_timezone, untimed_rank, cover_media_id
- `posts` — block_id, user_id, body, visibility (shared/private), created_at
- `post_media` — post_id, storage_path, media_type, upload_status, thumbnail_path
- `bills` — block_id, trip_id, amount (integer, smallest unit), currency, payer_id, created_at
- `bill_shares` — bill_id, user_id, share_amount
- `payments` — trip_id, payer_id, receiver_id, amount, currency, note, created_at

## Schema Stability
- Treat V1 schema as highly stable from day one
- Prefer additive changes — new columns, new tables
- Never rename or remove columns once shipped
- All amounts as integers (cents/smallest unit) — never float/decimal

## RLS Policies (non-negotiable)
- Only trip members can SELECT/INSERT/UPDATE on trip-scoped data (blocks, posts, bills, payments)
- Users can only UPDATE/DELETE their own posts
- Only block creator or trip owner can UPDATE block header fields
- Private posts (visibility = 'private') must NEVER be readable by other users — enforce in RLS, not just UI
- Only trip members can create bills and payments within that trip

## Data Model Rules
- Posts are append-only — no co-editing of shared content
- Bills and Payments are explicit source-of-truth records — never rely on summary counters alone
- A post record can exist before its media finishes uploading — post_media.upload_status tracks this
- Block metadata stays small and patchable (title, context, time, location_text)

## Auth
- Use Supabase Auth with JWT
- Implement session restore → auth refresh → data sync resume → media queue resume flow
- Handle long offline periods gracefully — refresh tokens before resuming sync

## Storage
- Server-side safety net: reject any single photo over 5MB or video over 60MB (client should never hit this — abuse prevention only)
- Video cap: max 60 seconds duration
- Validate client-side compression occurred — photos should arrive ≤1.5MB, videos ≤30MB in normal mode
- Organize storage paths: `trips/{trip_id}/posts/{post_id}/{filename}`
- Track total storage per trip — expose via query for client to check against soft/hard ceilings

## PowerSync Integration
- Configure sync rules so private posts only sync to the owning user's bucket
- Trip-scoped data syncs to all trip members
- Ensure JWT handshake between Supabase Auth and PowerSync is automated
