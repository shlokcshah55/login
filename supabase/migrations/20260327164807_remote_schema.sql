drop extension if exists "pg_net";

create extension if not exists "pg_net" with schema "public";


  create policy "Allow authenticated updates"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using ((bucket_id = 'location_photos'::text))
with check ((bucket_id = 'location_photos'::text));



  create policy "Allow authenticated uploads"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check ((bucket_id = 'location_photos'::text));



  create policy "Allow public reads"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'location_photos'::text));



  create policy "Authenticated users can read 1kxk1qw_0"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using ((bucket_id = 'profile_photos'::text));



  create policy "Authenticated users can upload 1kxk1qw_0"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check ((bucket_id = 'profile_photos'::text));



