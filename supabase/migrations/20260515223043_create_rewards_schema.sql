create schema if not exists rewards;

revoke all on schema rewards from public;
grant usage on schema rewards to authenticated, service_role;

create or replace function rewards.set_updated_at()
returns trigger
language plpgsql
as $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

create or replace function rewards.generate_referral_code(
  p_owner_user_id uuid,
  p_seed_text text default null
)
returns text
language plpgsql
immutable
as $function$
declare
  v_seed text;
begin
  v_seed := left(
    coalesce(
      nullif(
        regexp_replace(
          upper(coalesce(nullif(btrim(p_seed_text), ''), 'PIN')),
          '[^A-Z0-9]+',
          '',
          'g'
        ),
        ''
      ),
      'PIN'
    ),
    10
  );

  return format(
    '%s-%s',
    v_seed,
    upper(replace(p_owner_user_id::text, '-', ''))
  );
end;
$function$;

create table rewards.referral_codes (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.users (supabase_id) on delete cascade,
  code text not null check (btrim(code) <> ''),
  normalized_code text generated always as (
    upper(regexp_replace(code, '[^a-zA-Z0-9]+', '', 'g'))
  ) stored,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id),
  unique (normalized_code),
  unique (id, owner_user_id),
  check (normalized_code <> '')
);

create trigger referral_codes_set_updated_at
before update on rewards.referral_codes
for each row
execute function rewards.set_updated_at();

create table rewards.referrals (
  id uuid primary key default gen_random_uuid(),
  referral_code_id uuid not null,
  inviter_user_id uuid not null references public.users (supabase_id) on delete cascade,
  invitee_user_id uuid not null references public.users (supabase_id) on delete cascade,
  entered_code text not null check (btrim(entered_code) <> ''),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'voided')),
  entered_at timestamptz not null default now(),
  accepted_at timestamptz,
  voided_at timestamptz,
  acceptance_trigger text,
  metadata jsonb not null default '{}'::jsonb,
  unique (invitee_user_id),
  check (inviter_user_id <> invitee_user_id),
  foreign key (referral_code_id, inviter_user_id)
    references rewards.referral_codes (id, owner_user_id)
    on delete restrict,
  check (
    (status = 'pending' and accepted_at is null and voided_at is null) or
    (status = 'accepted' and accepted_at is not null and voided_at is null) or
    (status = 'voided' and accepted_at is null and voided_at is not null)
  )
);

create table rewards.vouchers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (supabase_id) on delete cascade,
  source_referral_id uuid references rewards.referrals (id) on delete set null,
  source_type text not null check (source_type in ('inviter_reward', 'invitee_reward')),
  campaign_key text not null default 'imperial_farmers_market_10pct_selected_stores',
  title text not null check (btrim(title) <> ''),
  description text,
  merchant_name text not null check (btrim(merchant_name) <> ''),
  terms_text text,
  discount_percent integer not null default 10 check (discount_percent = 10),
  status text not null default 'available' check (status in ('available', 'redeemed', 'expired', 'voided')),
  issued_at timestamptz not null default now(),
  redeemed_at timestamptz,
  expires_at timestamptz,
  redemption_token text,
  metadata jsonb not null default '{}'::jsonb
);

create unique index vouchers_source_referral_user_type_unique_idx
  on rewards.vouchers (source_referral_id, user_id, source_type)
  where source_referral_id is not null;

revoke all on all tables in schema rewards from public;
revoke all on all tables in schema rewards from anon;
revoke all on all tables in schema rewards from authenticated;

grant select on rewards.referral_codes to authenticated;
grant select on rewards.referrals to authenticated;
grant select on rewards.vouchers to authenticated;

grant all on all tables in schema rewards to service_role;
revoke all on function rewards.generate_referral_code(uuid, text) from public;
grant execute on function rewards.generate_referral_code(uuid, text) to service_role;

alter table rewards.referral_codes enable row level security;
alter table rewards.referrals enable row level security;
alter table rewards.vouchers enable row level security;

create policy "Users can read their own referral codes"
on rewards.referral_codes
for select
to authenticated
using (owner_user_id = auth.uid());

create policy "Users can read their own referral activity"
on rewards.referrals
for select
to authenticated
using (inviter_user_id = auth.uid() or invitee_user_id = auth.uid());

create policy "Users can read their own vouchers"
on rewards.vouchers
for select
to authenticated
using (user_id = auth.uid());

insert into rewards.referral_codes (
  owner_user_id,
  code
)
select
  u.supabase_id,
  rewards.generate_referral_code(
    u.supabase_id,
    coalesce(
      nullif(btrim(u.username), ''),
      nullif(btrim(u.name), ''),
      split_part(nullif(btrim(u.email), ''), '@', 1)
    )
  )
from public.users u
on conflict (owner_user_id) do nothing;
