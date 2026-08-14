-- Migration 004 — transaction type (expense / income / transfer).
-- Run in Supabase → SQL Editor BEFORE shipping the build that uses it.
-- Existing rows default to 'expense'. Safe to re-run.

alter table public.expenses
  add column if not exists type text not null default 'expense';

alter table public.expenses drop constraint if exists expenses_type_check;
alter table public.expenses
  add constraint expenses_type_check
  check (type in ('expense', 'income', 'transfer'));
