-- Seed data for local development.
-- Requires two test users to already exist in auth.users.
-- Run after: supabase start && create test users via dashboard or CLI.

-- Test user IDs (replace with actual auth.users UUIDs after creation)
-- User A: 00000000-0000-0000-0000-000000000001
-- User B: 00000000-0000-0000-0000-000000000002

-- Insert user profiles (normally done by trigger, but seed needs explicit inserts)
insert into public.users (id, display_name) values
    ('00000000-0000-0000-0000-000000000001', 'Sohn'),
    ('00000000-0000-0000-0000-000000000002', 'Alex')
on conflict (id) do nothing;

-- Create a test trip
insert into public.trips (id, title, start_date, end_date, display_timezone, base_currency, created_by) values
    ('10000000-0000-0000-0000-000000000001', 'Tokyo Trip 2026', '2026-07-14', '2026-07-18', 'Asia/Tokyo', 'JPY', '00000000-0000-0000-0000-000000000001')
on conflict (id) do nothing;

-- Add members (trigger adds owner, but seed is explicit)
insert into public.trip_members (trip_id, user_id, role) values
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'owner'),
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'member')
on conflict (trip_id, user_id) do nothing;

-- Create test blocks
insert into public.blocks (id, trip_id, title, context, created_by, start_at, display_timezone) values
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Ramen in Shibuya', 'group', '00000000-0000-0000-0000-000000000001', '2026-07-15T12:00:00+09:00', 'Asia/Tokyo'),
    ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'My airport transfer', 'personal', '00000000-0000-0000-0000-000000000002', '2026-07-14T07:00:00+09:00', 'Asia/Tokyo'),
    ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'Dinner at Gonpachi', 'group', '00000000-0000-0000-0000-000000000001', '2026-07-15T19:00:00+09:00', 'Asia/Tokyo')
on conflict (id) do nothing;

-- Create test posts (shared + private)
insert into public.posts (id, block_id, user_id, body, visibility) values
    ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Best ramen of my life', 'shared'),
    ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'The broth was amazing', 'shared'),
    ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Quiet moment at the temple', 'private')
on conflict (id) do nothing;

-- Create a test bill: ¥12,000 dinner split 2 ways
insert into public.bills (id, block_id, trip_id, amount, currency, payer_id) values
    ('40000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 12000, 'JPY', '00000000-0000-0000-0000-000000000001')
on conflict (id) do nothing;

insert into public.bill_shares (bill_id, user_id, share_amount) values
    ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 6000),
    ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 6000)
on conflict (bill_id, user_id) do nothing;

-- Create a test payment
insert into public.payments (trip_id, payer_id, receiver_id, amount, currency, note) values
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 6000, 'JPY', 'Dinner payback')
on conflict do nothing;
