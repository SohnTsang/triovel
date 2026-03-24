-- Initial schema for Group Travel OS (Triovel)
-- All 9 core tables with constraints, indexes, and RLS policies.
-- Amounts are always integers in smallest currency unit (cents). Never float.
-- Timestamps are always UTC. Display timezone is a separate field.

-- ============================================================
-- 1. USERS (profile data, linked to Supabase Auth)
-- ============================================================
create table public.users (
    id          uuid primary key references auth.users(id) on delete cascade,
    display_name text not null default '',
    avatar_path  text,
    created_at   timestamptz not null default now()
);

comment on table public.users is 'User profiles linked to Supabase Auth.';

-- ============================================================
-- 2. TRIPS
-- ============================================================
create table public.trips (
    id               uuid primary key default gen_random_uuid(),
    title            text not null,
    start_date       date not null,
    end_date         date not null,
    cover_image_path text,
    invite_link      text unique,
    display_timezone text not null default 'UTC',
    base_currency    text not null default 'USD',
    archived         boolean not null default false,
    created_by       uuid not null references public.users(id) on delete cascade,
    created_at       timestamptz not null default now(),

    constraint trips_dates_valid check (end_date >= start_date)
);

comment on table public.trips is 'Top-level trip container. The only access boundary.';

create index idx_trips_created_by on public.trips(created_by);

-- ============================================================
-- 3. TRIP_MEMBERS
-- ============================================================
create table public.trip_members (
    id        uuid primary key default gen_random_uuid(),
    trip_id   uuid not null references public.trips(id) on delete cascade,
    user_id   uuid not null references public.users(id) on delete cascade,
    role      text not null default 'member' check (role in ('owner', 'member')),
    joined_at timestamptz not null default now(),

    constraint trip_members_unique unique (trip_id, user_id)
);

comment on table public.trip_members is 'Junction table: users belong to trips.';

create index idx_trip_members_trip on public.trip_members(trip_id);
create index idx_trip_members_user on public.trip_members(user_id);

-- ============================================================
-- 4. BLOCKS (moments on the timeline)
-- ============================================================
create table public.blocks (
    id               uuid primary key default gen_random_uuid(),
    trip_id          uuid not null references public.trips(id) on delete cascade,
    title            text not null,
    context          text not null default 'group' check (context in ('group', 'personal')),
    created_by       uuid not null references public.users(id) on delete cascade,
    start_at         timestamptz not null,
    end_at           timestamptz,
    location_text    text,
    display_timezone text not null default 'UTC',
    local_timezone   text,
    untimed_rank     integer,
    cover_media_id   uuid,
    created_at       timestamptz not null default now()
);

comment on table public.blocks is 'A moment on the trip timeline (group or personal).';

create index idx_blocks_trip on public.blocks(trip_id);
create index idx_blocks_trip_start on public.blocks(trip_id, start_at);

-- ============================================================
-- 5. POSTS (memory entries inside a block)
-- ============================================================
create table public.posts (
    id         uuid primary key default gen_random_uuid(),
    block_id   uuid not null references public.blocks(id) on delete cascade,
    user_id    uuid not null references public.users(id) on delete cascade,
    body       text,
    visibility text not null default 'shared' check (visibility in ('shared', 'private')),
    created_at timestamptz not null default now()
);

comment on table public.posts is 'Append-only memory posts inside blocks. Private posts never sync to others.';

create index idx_posts_block on public.posts(block_id);
create index idx_posts_user on public.posts(user_id);

-- ============================================================
-- 6. POST_MEDIA (attached photos/videos)
-- ============================================================
create table public.post_media (
    id             uuid primary key default gen_random_uuid(),
    post_id        uuid not null references public.posts(id) on delete cascade,
    storage_path   text,
    media_type     text not null check (media_type in ('photo', 'video')),
    upload_status  text not null default 'queued' check (upload_status in ('queued', 'uploading', 'uploaded', 'failed')),
    thumbnail_path text,
    created_at     timestamptz not null default now()
);

comment on table public.post_media is 'Media attachments for posts. Post can exist before media finishes uploading.';

create index idx_post_media_post on public.post_media(post_id);

-- ============================================================
-- 7. BILLS (contextual expense records)
-- ============================================================
create table public.bills (
    id         uuid primary key default gen_random_uuid(),
    block_id   uuid not null references public.blocks(id) on delete cascade,
    trip_id    uuid not null references public.trips(id) on delete cascade,
    amount     integer not null check (amount >= 0),
    currency   text not null,
    payer_id   uuid not null references public.users(id) on delete cascade,
    created_at timestamptz not null default now()
);

comment on table public.bills is 'Explicit bill records. Amount in smallest currency unit. Never float.';

create index idx_bills_trip on public.bills(trip_id);
create index idx_bills_block on public.bills(block_id);

-- ============================================================
-- 8. BILL_SHARES (per-person split of a bill)
-- ============================================================
create table public.bill_shares (
    id           uuid primary key default gen_random_uuid(),
    bill_id      uuid not null references public.bills(id) on delete cascade,
    user_id      uuid not null references public.users(id) on delete cascade,
    share_amount integer not null check (share_amount >= 0),

    constraint bill_shares_unique unique (bill_id, user_id)
);

comment on table public.bill_shares is 'Individual share of a bill. Amount in smallest currency unit.';

create index idx_bill_shares_bill on public.bill_shares(bill_id);
create index idx_bill_shares_user on public.bill_shares(user_id);

-- ============================================================
-- 9. PAYMENTS (real-world repayments)
-- ============================================================
create table public.payments (
    id          uuid primary key default gen_random_uuid(),
    trip_id     uuid not null references public.trips(id) on delete cascade,
    payer_id    uuid not null references public.users(id) on delete cascade,
    receiver_id uuid not null references public.users(id) on delete cascade,
    amount      integer not null check (amount > 0),
    currency    text not null,
    note        text,
    created_at  timestamptz not null default now(),

    constraint payments_not_self check (payer_id <> receiver_id)
);

comment on table public.payments is 'Explicit repayment records. Amount in smallest currency unit.';

create index idx_payments_trip on public.payments(trip_id);

-- ============================================================
-- FOREIGN KEY: blocks.cover_media_id -> post_media.id
-- Added after both tables exist to avoid circular dependency.
-- ============================================================
alter table public.blocks
    add constraint blocks_cover_media_fk
    foreign key (cover_media_id) references public.post_media(id) on delete set null;

-- ============================================================
-- HELPER: check if current user is a member of the given trip.
-- Used by all RLS policies below.
-- ============================================================
create or replace function public.is_trip_member(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.trip_members
        where trip_id = p_trip_id
          and user_id = auth.uid()
    );
$$;

-- Helper: get trip_id from a block_id (for posts/post_media policies)
create or replace function public.trip_id_for_block(p_block_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select trip_id from public.blocks where id = p_block_id limit 1;
$$;

-- Helper: get trip_id from a bill_id (for bill_shares policies)
create or replace function public.trip_id_for_bill(p_bill_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select trip_id from public.bills where id = p_bill_id limit 1;
$$;

-- Helper: check if user is trip owner
create or replace function public.is_trip_owner(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.trip_members
        where trip_id = p_trip_id
          and user_id = auth.uid()
          and role = 'owner'
    );
$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- -------- USERS --------
alter table public.users enable row level security;

-- Any authenticated user can read profiles (for member lists)
create policy "users_select" on public.users
    for select to authenticated
    using (true);

-- Users can only insert their own profile
create policy "users_insert" on public.users
    for insert to authenticated
    with check (id = auth.uid());

-- Users can only update their own profile
create policy "users_update" on public.users
    for update to authenticated
    using (id = auth.uid())
    with check (id = auth.uid());

-- -------- TRIPS --------
alter table public.trips enable row level security;

-- Trip members can read the trip
create policy "trips_select" on public.trips
    for select to authenticated
    using (public.is_trip_member(id));

-- Any authenticated user can create a trip
create policy "trips_insert" on public.trips
    for insert to authenticated
    with check (created_by = auth.uid());

-- Only trip owner can update trip settings
create policy "trips_update" on public.trips
    for update to authenticated
    using (public.is_trip_owner(id))
    with check (public.is_trip_owner(id));

-- -------- TRIP_MEMBERS --------
alter table public.trip_members enable row level security;

-- Trip members can see who else is in the trip
create policy "trip_members_select" on public.trip_members
    for select to authenticated
    using (public.is_trip_member(trip_id));

-- Trip members can add others (invite), or join via invite link
create policy "trip_members_insert" on public.trip_members
    for insert to authenticated
    with check (
        user_id = auth.uid()
        or public.is_trip_member(trip_id)
    );

-- Members can remove themselves; owners can remove anyone
create policy "trip_members_delete" on public.trip_members
    for delete to authenticated
    using (
        user_id = auth.uid()
        or public.is_trip_owner(trip_id)
    );

-- -------- BLOCKS --------
alter table public.blocks enable row level security;

-- Trip members can read all blocks in their trip
create policy "blocks_select" on public.blocks
    for select to authenticated
    using (public.is_trip_member(trip_id));

-- Trip members can create blocks
create policy "blocks_insert" on public.blocks
    for insert to authenticated
    with check (
        created_by = auth.uid()
        and public.is_trip_member(trip_id)
    );

-- Only block creator or trip owner can update block header
create policy "blocks_update" on public.blocks
    for update to authenticated
    using (
        created_by = auth.uid()
        or public.is_trip_owner(trip_id)
    )
    with check (
        created_by = auth.uid()
        or public.is_trip_owner(trip_id)
    );

-- Only block creator or trip owner can delete
create policy "blocks_delete" on public.blocks
    for delete to authenticated
    using (
        created_by = auth.uid()
        or public.is_trip_owner(trip_id)
    );

-- -------- POSTS --------
alter table public.posts enable row level security;

-- Shared posts: visible to trip members.
-- Private posts: visible ONLY to the owner. Never leak to others.
create policy "posts_select" on public.posts
    for select to authenticated
    using (
        public.is_trip_member(public.trip_id_for_block(block_id))
        and (
            visibility = 'shared'
            or (visibility = 'private' and user_id = auth.uid())
        )
    );

-- Trip members can insert posts into blocks in their trip
create policy "posts_insert" on public.posts
    for insert to authenticated
    with check (
        user_id = auth.uid()
        and public.is_trip_member(public.trip_id_for_block(block_id))
    );

-- Users can only update their own posts
create policy "posts_update" on public.posts
    for update to authenticated
    using (user_id = auth.uid())
    with check (user_id = auth.uid());

-- Users can only delete their own posts
create policy "posts_delete" on public.posts
    for delete to authenticated
    using (user_id = auth.uid());

-- -------- POST_MEDIA --------
alter table public.post_media enable row level security;

-- Follows same visibility as the parent post
create policy "post_media_select" on public.post_media
    for select to authenticated
    using (
        exists (
            select 1 from public.posts p
            where p.id = post_id
              and public.is_trip_member(public.trip_id_for_block(p.block_id))
              and (
                  p.visibility = 'shared'
                  or (p.visibility = 'private' and p.user_id = auth.uid())
              )
        )
    );

-- Only the post owner can attach media
create policy "post_media_insert" on public.post_media
    for insert to authenticated
    with check (
        exists (
            select 1 from public.posts p
            where p.id = post_id
              and p.user_id = auth.uid()
        )
    );

-- Only the post owner can update media (e.g. upload_status)
create policy "post_media_update" on public.post_media
    for update to authenticated
    using (
        exists (
            select 1 from public.posts p
            where p.id = post_id
              and p.user_id = auth.uid()
        )
    );

-- Only the post owner can delete media
create policy "post_media_delete" on public.post_media
    for delete to authenticated
    using (
        exists (
            select 1 from public.posts p
            where p.id = post_id
              and p.user_id = auth.uid()
        )
    );

-- -------- BILLS --------
alter table public.bills enable row level security;

-- Trip members can view bills
create policy "bills_select" on public.bills
    for select to authenticated
    using (public.is_trip_member(trip_id));

-- Trip members can create bills
create policy "bills_insert" on public.bills
    for insert to authenticated
    with check (
        payer_id = auth.uid()
        and public.is_trip_member(trip_id)
    );

-- Only bill creator can update
create policy "bills_update" on public.bills
    for update to authenticated
    using (payer_id = auth.uid())
    with check (payer_id = auth.uid());

-- Only bill creator can delete
create policy "bills_delete" on public.bills
    for delete to authenticated
    using (payer_id = auth.uid());

-- -------- BILL_SHARES --------
alter table public.bill_shares enable row level security;

-- Trip members can see bill shares
create policy "bill_shares_select" on public.bill_shares
    for select to authenticated
    using (public.is_trip_member(public.trip_id_for_bill(bill_id)));

-- Bill creator can manage shares (checked via bill ownership)
create policy "bill_shares_insert" on public.bill_shares
    for insert to authenticated
    with check (
        exists (
            select 1 from public.bills b
            where b.id = bill_id
              and b.payer_id = auth.uid()
        )
    );

create policy "bill_shares_update" on public.bill_shares
    for update to authenticated
    using (
        exists (
            select 1 from public.bills b
            where b.id = bill_id
              and b.payer_id = auth.uid()
        )
    );

create policy "bill_shares_delete" on public.bill_shares
    for delete to authenticated
    using (
        exists (
            select 1 from public.bills b
            where b.id = bill_id
              and b.payer_id = auth.uid()
        )
    );

-- -------- PAYMENTS --------
alter table public.payments enable row level security;

-- Trip members can view payments
create policy "payments_select" on public.payments
    for select to authenticated
    using (public.is_trip_member(trip_id));

-- Trip members can create payments (payer must be current user)
create policy "payments_insert" on public.payments
    for insert to authenticated
    with check (
        payer_id = auth.uid()
        and public.is_trip_member(trip_id)
    );

-- Only payment creator can update
create policy "payments_update" on public.payments
    for update to authenticated
    using (payer_id = auth.uid())
    with check (payer_id = auth.uid());

-- Only payment creator can delete
create policy "payments_delete" on public.payments
    for delete to authenticated
    using (payer_id = auth.uid());

-- ============================================================
-- AUTO-CREATE USER PROFILE ON SIGNUP
-- Trigger: when a new auth.users row is created, insert into public.users
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.users (id, display_name)
    values (
        new.id,
        coalesce(
            new.raw_user_meta_data ->> 'full_name',
            new.raw_user_meta_data ->> 'name',
            split_part(new.email, '@', 1)
        )
    );
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ============================================================
-- AUTO-ADD TRIP CREATOR AS OWNER
-- Trigger: when a trip is created, add the creator as owner in trip_members
-- ============================================================
create or replace function public.handle_new_trip()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.trip_members (trip_id, user_id, role)
    values (new.id, new.created_by, 'owner');
    return new;
end;
$$;

create trigger on_trip_created
    after insert on public.trips
    for each row execute function public.handle_new_trip();
