ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS generated_collections timestamp with time zone;
