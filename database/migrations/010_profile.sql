-- Migration 010 — richer profile fields + public avatars bucket. Safe to re-run.

alter table public.profiles add column if not exists dob date;
alter table public.profiles add column if not exists gender text;
alter table public.profiles add column if not exists address text;
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists avatar_url text;

-- Public avatars bucket: anyone can read (avatars aren't sensitive), but a user
-- can only write to their own {user_id}/ folder.
insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do nothing;

drop policy if exists "avatars read all" on storage.objects;
create policy "avatars read all" on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars write own" on storage.objects;
create policy "avatars write own" on storage.objects for insert
  with check (bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "avatars update own" on storage.objects;
create policy "avatars update own" on storage.objects for update
  using (bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "avatars delete own" on storage.objects;
create policy "avatars delete own" on storage.objects for delete
  using (bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]);
