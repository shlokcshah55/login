-- Fix profile photo uploads failing with:
-- StorageException(... new row violates row-level security policy ...)
--
-- Root cause:
-- - Client uploads with `upsert: true`, which can perform UPDATE when the file
--   path already exists (e.g. user changes avatar).
-- - Existing policies only allowed INSERT for `profile_photos`, not UPDATE.
--
-- Additionally, tighten INSERT/UPDATE/DELETE to only allow users to write
-- inside their own folder: `<auth.uid()>/<...>`.

-- Replace the overly-broad insert policy with a folder-scoped one.
drop policy if exists "Authenticated users can upload 1kxk1qw_0" on storage.objects;

create policy "Users can upload own profile photos"
on storage.objects
as permissive
for insert
to authenticated
with check (
  bucket_id = 'profile_photos'
  and split_part(name, '/', 1) = auth.uid()::text
);

-- Allow updating (required for `upsert: true` overwrites).
drop policy if exists "Users can update own profile photos" on storage.objects;
create policy "Users can update own profile photos"
on storage.objects
as permissive
for update
to authenticated
using (
  bucket_id = 'profile_photos'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'profile_photos'
  and split_part(name, '/', 1) = auth.uid()::text
);

-- Allow deleting own avatars (useful for account deletion / removing photo).
drop policy if exists "Users can delete own profile photos" on storage.objects;
create policy "Users can delete own profile photos"
on storage.objects
as permissive
for delete
to authenticated
using (
  bucket_id = 'profile_photos'
  and split_part(name, '/', 1) = auth.uid()::text
);

