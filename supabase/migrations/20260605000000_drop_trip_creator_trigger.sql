-- Fix: trips / trip_members failing to sync (root cause of sign-out data loss).
--
-- The on_trip_created trigger inserted an owner row into trip_members server-side.
-- The client ALSO inserts that same owner row locally (mirrored in TripRepository)
-- and pushes it through PowerSync. The two collide on the
-- trip_members_unique (trip_id, user_id) constraint. Because trip_members has no
-- UPDATE policy, the connector's insert-then-update fallback could not reconcile the
-- collision — risking a wedged upload queue that blocked all subsequent writes.
--
-- The client is the single source of truth for the owner membership row
-- (local-first: save locally, then sync). Drop the server trigger so there is
-- exactly one writer. Existing trips keep their owner rows untouched; this only
-- affects newly created trips.

drop trigger if exists on_trip_created on public.trips;
drop function if exists public.handle_new_trip();
