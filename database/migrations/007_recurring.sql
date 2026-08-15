-- Migration 007 — recurring / scheduled transactions. Run before the build. Safe to re-run.

create table if not exists public.recurring_transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  amount      numeric(14,2) not null check (amount >= 0),
  type        text not null default 'expense' check (type in ('expense','income')),
  category_id uuid references public.categories (id) on delete set null,
  account_id  uuid references public.accounts (id) on delete set null,
  note        text not null default '',
  frequency   text not null default 'monthly'
                check (frequency in ('daily','weekly','monthly')),
  next_run    date not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_recurring_user on public.recurring_transactions (user_id);

drop trigger if exists trg_recurring_updated on public.recurring_transactions;
create trigger trg_recurring_updated
  before update on public.recurring_transactions
  for each row execute function public.set_updated_at();

alter table public.recurring_transactions enable row level security;
drop policy if exists "own recurring - all" on public.recurring_transactions;
create policy "own recurring - all" on public.recurring_transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
