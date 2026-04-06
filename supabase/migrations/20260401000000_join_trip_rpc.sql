-- RPC function to join a trip by invite code.
-- Runs as SECURITY DEFINER to bypass RLS (the user isn't a member yet,
-- so they can't SELECT from trips to look up the invite code).
-- Returns the trip UUID. Raises exception if code is invalid.

create or replace function public.join_trip_by_invite(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_trip_id uuid;
begin
    -- Look up trip by invite code (bypasses RLS)
    select id into v_trip_id
    from public.trips
    where invite_link = p_invite_code;

    if v_trip_id is null then
        raise exception 'Trip not found' using errcode = 'P0002';
    end if;

    -- Add user as member (idempotent — no error if already joined)
    insert into public.trip_members (trip_id, user_id, role)
    values (v_trip_id, auth.uid(), 'member')
    on conflict (trip_id, user_id) do nothing;

    return v_trip_id;
end;
$$;
