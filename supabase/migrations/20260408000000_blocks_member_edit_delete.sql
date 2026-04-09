-- Allow any trip member to update/delete blocks (not just creator/owner).
-- This matches the app behavior where group collaboration means anyone can
-- manage the shared timeline.

DROP POLICY IF EXISTS "blocks_update" ON public.blocks;
CREATE POLICY "blocks_update" ON public.blocks
    FOR UPDATE TO authenticated
    USING (public.is_trip_member(trip_id))
    WITH CHECK (public.is_trip_member(trip_id));

DROP POLICY IF EXISTS "blocks_delete" ON public.blocks;
CREATE POLICY "blocks_delete" ON public.blocks
    FOR DELETE TO authenticated
    USING (public.is_trip_member(trip_id));

-- Allow any trip member to update trips (not just owner).
-- Delete remains owner-only.

DROP POLICY IF EXISTS "trips_update" ON public.trips;
CREATE POLICY "trips_update" ON public.trips
    FOR UPDATE TO authenticated
    USING (public.is_trip_member(id))
    WITH CHECK (public.is_trip_member(id));
