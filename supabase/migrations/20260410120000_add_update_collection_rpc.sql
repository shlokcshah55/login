-- Storage bucket for user-uploaded collection cover photos
insert into storage.buckets (id, name, public)
values ('collection_covers', 'collection_covers', true)
on conflict (id) do nothing;

-- Allow authenticated users to upload cover photos
create policy "Users can upload collection covers"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'collection_covers');

-- Allow authenticated users to update/replace their cover photos
create policy "Users can update collection covers"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'collection_covers');

-- Public read access for collection cover photos
create policy "Collection covers are publicly readable"
  on storage.objects for select
  to public
  using (bucket_id = 'collection_covers');

-- RPC to update a collection's name and cover_color (photo URL)
create or replace function update_collection(
  p_collection_id uuid,
  p_name text,
  p_cover_color text
)
returns void
language plpgsql
security definer
as $$
begin
  update collections
  set
    name        = coalesce(p_name, name),
    cover_color = p_cover_color
  where collection_id = p_collection_id
    and created_by = auth.uid();
end;
$$;
