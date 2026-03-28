-- Add optional description to blocks for planning context
-- (e.g. "Meet at lobby 6:30, reservation under Sohn")
-- This is NOT a post — it's block-level metadata visible to all trip members.
ALTER TABLE public.blocks ADD COLUMN IF NOT EXISTS description text;
