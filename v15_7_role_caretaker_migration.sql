-- Cashew Creek Villa V15.7 - Rename role waiter -> caretaker
-- Run once in Supabase SQL Editor as project owner.
-- This migration preserves existing manager/accounts roles for backward compatibility,
-- while replacing the legacy waiter role with caretaker and supporting guest/owner.

begin;

-- 1) Rename existing users whose role is waiter.
update public.profiles
set role = 'caretaker'
where lower(btrim(role)) = 'waiter';

-- 2) Replace any legacy role CHECK constraint that still requires waiter.
-- Constraint names can differ between installations, so inspect definitions dynamically.
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%waiter%'
  loop
    execute format('alter table public.profiles drop constraint if exists %I', c.conname);
  end loop;
end $$;

-- 3) Add the canonical allowed-role constraint.
-- manager/accounts are retained so older records are not invalidated.
alter table public.profiles
drop constraint if exists profiles_role_check;

alter table public.profiles
add constraint profiles_role_check
check (role in ('owner','caretaker','guest','manager','accounts'));

commit;
