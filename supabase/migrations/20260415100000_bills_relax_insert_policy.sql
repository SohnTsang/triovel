-- Allow any trip member to create a bill with any payer (not just themselves).
-- Use case: "Kim logs that Sohn paid for dinner" — Kim is not the payer.
DROP POLICY IF EXISTS "bills_insert" ON public.bills;

CREATE POLICY "bills_insert" ON public.bills
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_trip_member(trip_id)
    );
