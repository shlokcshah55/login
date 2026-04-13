alter table public.users
add column if not exists legal_consent_accepted_at timestamptz;
