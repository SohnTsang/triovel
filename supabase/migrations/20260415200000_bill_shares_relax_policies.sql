-- Relax bill_shares policies: any trip member can manage shares,
-- not just the bill payer. Matches bills_insert relaxation.

DROP POLICY IF EXISTS "bill_shares_insert" ON public.bill_shares;
CREATE POLICY "bill_shares_insert" ON public.bill_shares
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_trip_member(trip_id)
    );

DROP POLICY IF EXISTS "bill_shares_update" ON public.bill_shares;
CREATE POLICY "bill_shares_update" ON public.bill_shares
    FOR UPDATE TO authenticated
    USING (public.is_trip_member(trip_id));

DROP POLICY IF EXISTS "bill_shares_delete" ON public.bill_shares;
CREATE POLICY "bill_shares_delete" ON public.bill_shares
    FOR DELETE TO authenticated
    USING (public.is_trip_member(trip_id));
