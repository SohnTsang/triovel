-- Add optional note field to bills table
ALTER TABLE public.bills ADD COLUMN IF NOT EXISTS note text;
