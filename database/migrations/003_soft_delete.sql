-- Migration 003 — soft deletes for expenses (deletes become recoverable).
-- Run in Supabase → SQL Editor BEFORE shipping the app build that uses it.
-- Safe to re-run.

alter table public.expenses
  add column if not exists deleted_at timestamptz;

-- Fast lookups of the user's *live* (non-deleted) expenses.
create index if not exists idx_expenses_active
  on public.expenses (user_id, spent_at desc)
  where deleted_at is null;
