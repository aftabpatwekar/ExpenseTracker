-- Migration 002 — allow an "annual" budget period (in addition to weekly/monthly).
-- Run in Supabase → SQL Editor. Safe to re-run.

alter table public.budgets drop constraint if exists budgets_period_check;

alter table public.budgets
  add constraint budgets_period_check
  check (period in ('weekly', 'monthly', 'annual'));
