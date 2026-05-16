alter table public.users
  add column if not exists referral_code text;

comment on column public.users.referral_code is
  'Referral code applied by the user during onboarding before rewards unlock on wizard completion.';
