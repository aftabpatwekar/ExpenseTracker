-- Migration 009 — shared groups (collaborative budgets across devices/users).
-- Safe to re-run. Run after 002–008.
--
-- Model: a group has members, a shared budget, and shared expenses. An expense
-- with group_id = NULL is personal; with a group_id it's visible to every member
-- of that group. Personal ledgers stay private.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  owner_id    uuid not null references auth.users (id) on delete cascade,
  invite_code text not null unique,
  currency    text not null default 'INR',
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table if not exists public.group_members (
  id        uuid primary key default gen_random_uuid(),
  group_id  uuid not null references public.groups (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  role      text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  unique (group_id, user_id)
);
create index if not exists idx_group_members_user on public.group_members (user_id);
create index if not exists idx_group_members_group on public.group_members (group_id);

create table if not exists public.group_budgets (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups (id) on delete cascade,
  period     text not null default 'monthly' check (period in ('monthly','weekly')),
  amount     numeric(14,2) not null check (amount >= 0),
  created_at timestamptz not null default now(),
  unique (group_id, period)
);

-- Link expenses to an optional group.
alter table public.expenses
  add column if not exists group_id uuid references public.groups (id) on delete set null;
create index if not exists idx_expenses_group on public.expenses (group_id);

-- ---------------------------------------------------------------------------
-- Membership check as SECURITY DEFINER so policies can call it without causing
-- infinite RLS recursion on group_members.
-- ---------------------------------------------------------------------------
create or replace function public.is_group_member(gid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = gid and m.user_id = auth.uid()
  );
$$;

-- Lets a member read the profile (name) of anyone sharing a group with them.
create or replace function public.shares_group_with(other uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members a
    join public.group_members b on a.group_id = b.group_id
    where a.user_id = auth.uid() and b.user_id = other
  );
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_budgets enable row level security;

-- groups: members can read; owner manages.
drop policy if exists "groups - select" on public.groups;
create policy "groups - select" on public.groups
  for select using (public.is_group_member(id) or owner_id = auth.uid());

drop policy if exists "groups - insert" on public.groups;
create policy "groups - insert" on public.groups
  for insert with check (owner_id = auth.uid());

drop policy if exists "groups - update" on public.groups;
create policy "groups - update" on public.groups
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "groups - delete" on public.groups;
create policy "groups - delete" on public.groups
  for delete using (owner_id = auth.uid());

-- group_members: you can see your own row and (via the definer fn) fellow members.
-- Inserts happen only through the RPCs below (which are SECURITY DEFINER).
drop policy if exists "group_members - select" on public.group_members;
create policy "group_members - select" on public.group_members
  for select using (user_id = auth.uid() or public.is_group_member(group_id));

drop policy if exists "group_members - delete" on public.group_members;
create policy "group_members - delete" on public.group_members
  for delete using (
    user_id = auth.uid()
    or group_id in (select id from public.groups where owner_id = auth.uid())
  );

-- group_budgets: any member can view and set.
drop policy if exists "group_budgets - all" on public.group_budgets;
create policy "group_budgets - all" on public.group_budgets
  for all using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

-- profiles: allow reading fellow group members' names (adds to own-profile policy).
drop policy if exists "profiles - group members select" on public.profiles;
create policy "profiles - group members select" on public.profiles
  for select using (public.shares_group_with(id));

-- ---------------------------------------------------------------------------
-- expenses: broaden visibility to group members; tighten inserts so you can
-- only attach an expense to a group you actually belong to.
-- ---------------------------------------------------------------------------
drop policy if exists "own expenses - all" on public.expenses;
create policy "own expenses - all" on public.expenses
  for all
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and (group_id is null or public.is_group_member(group_id))
  );

drop policy if exists "group expenses - select" on public.expenses;
create policy "group expenses - select" on public.expenses
  for select using (group_id is not null and public.is_group_member(group_id));

-- ---------------------------------------------------------------------------
-- RPCs: create / join / leave  (SECURITY DEFINER = they bypass RLS internally)
-- ---------------------------------------------------------------------------
create or replace function public.create_group(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  gid  uuid;
  code text;
begin
  code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  insert into public.groups (name, owner_id, invite_code)
    values (coalesce(nullif(trim(p_name), ''), 'My Group'), auth.uid(), code)
    returning id into gid;
  insert into public.group_members (group_id, user_id, role)
    values (gid, auth.uid(), 'owner');
  return gid;
end;
$$;

create or replace function public.join_group(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
begin
  select id into gid from public.groups
    where invite_code = upper(trim(p_code)) and deleted_at is null;
  if gid is null then
    raise exception 'Invalid invite code';
  end if;
  insert into public.group_members (group_id, user_id, role)
    values (gid, auth.uid(), 'member')
    on conflict (group_id, user_id) do nothing;
  return gid;
end;
$$;

create or replace function public.leave_group(p_group uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.group_members
    where group_id = p_group and user_id = auth.uid();
end;
$$;
