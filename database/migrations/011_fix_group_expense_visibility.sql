-- Migration 011 — fix shared-group expense visibility.
--
-- Symptom this fixes: when one member adds a shared expense, other members of
-- the same group can't see it. That happens when the "group expenses - select"
-- policy from migration 009 isn't active in the live database (e.g. 009 was only
-- partially applied, or schema.sql was re-run afterwards). The member who added
-- the expense still sees it (it's their own row via "own expenses - all"), but
-- nobody else can — exactly the reported behaviour.
--
-- Safe to run any number of times. Run it in the Supabase SQL editor.

-- 1. Membership check (SECURITY DEFINER avoids RLS recursion on group_members).
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

-- 2. The policy that lets every group member read the group's expenses.
drop policy if exists "group expenses - select" on public.expenses;
create policy "group expenses - select" on public.expenses
  for select using (group_id is not null and public.is_group_member(group_id));

-- 3. Diagnostic — after running the above, this should list the policy:
--    select policyname, cmd from pg_policies
--    where schemaname = 'public' and tablename = 'expenses';
--    You should see BOTH "own expenses - all" and "group expenses - select".
