-- Migration 008 — receipt photos. Run before the build. Safe to re-run.
-- Adds a receipt path column and a PRIVATE 'receipts' storage bucket where each
-- user can only touch their own folder ({user_id}/...).

alter table public.expenses
  add column if not exists receipt_url text;

insert into storage.buckets (id, name, public)
  values ('receipts', 'receipts', false)
  on conflict (id) do nothing;

drop policy if exists "receipts read own" on storage.objects;
create policy "receipts read own" on storage.objects for select
  using (bucket_id = 'receipts'
    and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "receipts insert own" on storage.objects;
create policy "receipts insert own" on storage.objects for insert
  with check (bucket_id = 'receipts'
    and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "receipts delete own" on storage.objects;
create policy "receipts delete own" on storage.objects for delete
  using (bucket_id = 'receipts'
    and auth.uid()::text = (storage.foldername(name))[1]);
