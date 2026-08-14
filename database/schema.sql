-- ============================================================================
--  Expense Tracker — Supabase / PostgreSQL schema
--  Run this in your Supabase project:  SQL Editor → New query → paste → Run.
--  Safe to re-run: everything is idempotent (IF NOT EXISTS / CREATE OR REPLACE).
-- ============================================================================

-- Supabase provides gen_random_uuid() via pgcrypto (already enabled).
create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
--  updated_at helper
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================================
--  1. profiles  — one row per auth user (extra profile data lives here)
-- ============================================================================
create table if not exists public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  display_name   text,
  currency       text        not null default 'INR',   -- ISO 4217; UI shows the symbol
  locale         text        not null default 'en-IN',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated
  before update on public.profiles
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

drop policy if exists "own profile - select" on public.profiles;
create policy "own profile - select" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "own profile - update" on public.profiles;
create policy "own profile - update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "own profile - insert" on public.profiles;
create policy "own profile - insert" on public.profiles
  for insert with check (auth.uid() = id);

-- ============================================================================
--  2. categories — per-user; each carries the keywords the parser matches on
-- ============================================================================
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null,
  icon        text not null default '•',                -- emoji shown in the UI
  color       text not null default '#2a78d6',          -- hex, from the validated palette
  keywords    text[] not null default '{}',             -- spoken words that map here
  sort_order  int  not null default 0,
  is_archived boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, name)
);

create index if not exists idx_categories_user on public.categories (user_id);

drop trigger if exists trg_categories_updated on public.categories;
create trigger trg_categories_updated
  before update on public.categories
  for each row execute function public.set_updated_at();

alter table public.categories enable row level security;

drop policy if exists "own categories - all" on public.categories;
create policy "own categories - all" on public.categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================================
--  3. expenses — the core ledger
-- ============================================================================
create table if not exists public.expenses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  category_id  uuid references public.categories (id) on delete set null,
  amount       numeric(14,2) not null check (amount >= 0),
  currency     text not null default 'INR',
  note         text not null default '',
  raw_text     text,                                     -- original voice/dictation, kept for audit
  spent_at     timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_expenses_user_date on public.expenses (user_id, spent_at desc);
create index if not exists idx_expenses_category  on public.expenses (category_id);

drop trigger if exists trg_expenses_updated on public.expenses;
create trigger trg_expenses_updated
  before update on public.expenses
  for each row execute function public.set_updated_at();

alter table public.expenses enable row level security;

drop policy if exists "own expenses - all" on public.expenses;
create policy "own expenses - all" on public.expenses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================================
--  4. budgets — optional monthly caps (overall when category_id is null)
-- ============================================================================
create table if not exists public.budgets (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  category_id  uuid references public.categories (id) on delete cascade,
  period       text not null default 'monthly' check (period in ('monthly','weekly')),
  amount       numeric(14,2) not null check (amount >= 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_budgets_user on public.budgets (user_id);

drop trigger if exists trg_budgets_updated on public.budgets;
create trigger trg_budgets_updated
  before update on public.budgets
  for each row execute function public.set_updated_at();

alter table public.budgets enable row level security;

drop policy if exists "own budgets - all" on public.budgets;
create policy "own budgets - all" on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================================
--  5. New-user bootstrap: create a profile + seed the default categories
--     Fires automatically whenever Supabase Auth creates a user.
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;

  insert into public.categories (user_id, name, icon, color, keywords, sort_order) values
    (new.id, 'Food & Groceries', '🛒', '#2a78d6',
      array['grocery','groceries','vegetable','vegetables','veggie','veggies','milk','fruit','fruits','bread','egg','eggs','supermarket','kirana','bigbasket','dmart','rice','atta'], 1),
    (new.id, 'Dining Out', '🍽️', '#eb6834',
      array['restaurant','dining','dinner','lunch','breakfast','coffee','cafe','tea','snack','snacks','swiggy','zomato','food','pizza','burger','biryani','dosa'], 2),
    (new.id, 'Transport', '🚗', '#1baf7a',
      array['uber','ola','taxi','cab','auto','rickshaw','petrol','diesel','fuel','gas','bus','train','metro','flight','travel','parking','toll','rapido','fastag'], 3),
    (new.id, 'Shopping', '🛍️', '#eda100',
      array['amazon','flipkart','clothes','clothing','shoes','shopping','myntra','electronics','gadget','mobile','laptop','dress','shirt','jeans'], 4),
    (new.id, 'Bills & Utilities', '🧾', '#e87ba4',
      array['rent','bill','bills','electricity','water','internet','wifi','broadband','recharge','dth','maintenance','emi','loan','insurance','subscription','utility'], 5),
    (new.id, 'Health', '💊', '#008300',
      array['medicine','medicines','pharmacy','doctor','hospital','clinic','health','gym','fitness','dental','dentist','checkup','lab','apollo'], 6),
    (new.id, 'Entertainment', '🎬', '#4a3aa7',
      array['movie','movies','netflix','spotify','prime','hotstar','game','games','concert','entertainment','cinema','pvr','book','books','party'], 7),
    (new.id, 'Other', '•', '#e34948', array[]::text[], 99)
  on conflict (user_id, name) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
--  Done. Tables: profiles, categories, expenses, budgets — all RLS-protected.
-- ============================================================================
