-- Migration 006 — freeform tags on transactions. Run before the build. Safe to re-run.

alter table public.expenses
  add column if not exists tags text[] not null default '{}';

create index if not exists idx_expenses_tags
  on public.expenses using gin (tags);
