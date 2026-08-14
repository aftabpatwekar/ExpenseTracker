-- Migration 005 — accounts / payment modes (Cash, Bank, Card…) + link on expenses.
-- Run in Supabase → SQL Editor before the build that uses it. Safe to re-run.

-- Accounts table
create table if not exists public.accounts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  name            text not null,
  type            text not null default 'cash'
                    check (type in ('cash','bank','card','wallet','other')),
  icon            text not null default '💵',
  color           text not null default '#1baf7a',
  opening_balance numeric(14,2) not null default 0,
  sort_order      int  not null default 0,
  is_archived     boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (user_id, name)
);

create index if not exists idx_accounts_user on public.accounts (user_id);

drop trigger if exists trg_accounts_updated on public.accounts;
create trigger trg_accounts_updated
  before update on public.accounts
  for each row execute function public.set_updated_at();

alter table public.accounts enable row level security;
drop policy if exists "own accounts - all" on public.accounts;
create policy "own accounts - all" on public.accounts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Link expenses to an account (nullable; on delete keep the expense)
alter table public.expenses
  add column if not exists account_id uuid references public.accounts (id) on delete set null;
create index if not exists idx_expenses_account on public.expenses (account_id);

-- Seed a default "Cash" account for existing users that have none
insert into public.accounts (user_id, name, type, icon, color, sort_order)
select u.id, 'Cash', 'cash', '💵', '#1baf7a', 1
from auth.users u
where not exists (select 1 from public.accounts a where a.user_id = u.id);

-- New users get a "Cash" account too (separate trigger; leaves categories seed intact)
create or replace function public.handle_new_user_account()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.accounts (user_id, name, type, icon, color, sort_order)
  values (new.id, 'Cash', 'cash', '💵', '#1baf7a', 1)
  on conflict (user_id, name) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_account on auth.users;
create trigger on_auth_user_created_account
  after insert on auth.users
  for each row execute function public.handle_new_user_account();
