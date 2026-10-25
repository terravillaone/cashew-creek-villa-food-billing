-- Cashew Creek Villa V15
-- Run once in Supabase SQL Editor as the project owner.
-- This migration:
-- 1) adds/normalizes profiles.username for username login;
-- 2) provides the username -> internal Auth email resolver;
-- 3) enforces owner-only access to supplier rates/payables and menu administration;
-- 4) moves supplier-bill creation and customer-order cleanup into SECURITY DEFINER RPCs;
-- 5) keeps waiter/guest access limited to normal ordering and their own order creation.

begin;

alter table public.profiles add column if not exists username text;

update public.profiles p
set username = lower(split_part(u.email, '@', 1))
from auth.users u
where u.id = p.id
  and nullif(btrim(coalesce(p.username, '')), '') is null
  and u.email is not null;

create unique index if not exists profiles_username_unique
on public.profiles (lower(btrim(username)))
where username is not null;

create or replace function public.resolve_login_email(p_username text)
returns text
language sql
security definer
set search_path = public
as $$
  select u.email
  from auth.users u
  join public.profiles p on p.id = u.id
  where lower(btrim(coalesce(p.username, ''))) = lower(btrim(p_username))
  limit 1;
$$;

grant execute on function public.resolve_login_email(text) to anon, authenticated;

create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where id = auth.uid() and role = 'owner'
  );
$$;

grant execute on function public.is_owner() to authenticated;

-- Supplier-bill uniqueness is required for idempotency.
create unique index if not exists supplier_bills_order_supplier_unique
on public.supplier_bills(order_id, supplier_id);

-- Move supplier-bill creation into a single database transaction.
create or replace function public.create_supplier_bills_for_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  ord record;
  grp record;
  bill_id uuid;
  created_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select id, created_by into ord
  from public.orders
  where id = p_order_id;

  if not found then
    raise exception 'Order not found';
  end if;

  if ord.created_by <> auth.uid() and not public.is_owner() then
    raise exception 'Not allowed to create supplier bills for this order';
  end if;

  for grp in
    select
      sic.supplier_id,
      coalesce(sum(sic.supplier_rate * oi.quantity), 0) as total_amount
    from public.order_items oi
    join public.supplier_item_costs sic
      on sic.menu_item_id = oi.menu_item_id
     and sic.active = true
    where oi.order_id = p_order_id
    group by sic.supplier_id
  loop
    insert into public.supplier_bills(order_id, supplier_id, total_amount, status)
    values (p_order_id, grp.supplier_id, grp.total_amount, 'pending')
    on conflict (order_id, supplier_id)
    do update set total_amount = excluded.total_amount, status = 'pending'
    returning id into bill_id;

    delete from public.supplier_bill_items
    where supplier_bill_id = bill_id;

    insert into public.supplier_bill_items(
      supplier_bill_id, menu_item_id, item_name_en, item_name_mr,
      quantity, supplier_rate, line_total
    )
    select
      bill_id,
      oi.menu_item_id,
      oi.item_name_en,
      oi.item_name_mr,
      oi.quantity,
      sic.supplier_rate,
      sic.supplier_rate * oi.quantity
    from public.order_items oi
    join public.supplier_item_costs sic
      on sic.menu_item_id = oi.menu_item_id
     and sic.supplier_id = grp.supplier_id
     and sic.active = true
    where oi.order_id = p_order_id;

    created_count := created_count + 1;
  end loop;

  return jsonb_build_object('ok', true, 'supplier_bills', created_count);
end;
$$;

grant execute on function public.create_supplier_bills_for_order(uuid) to authenticated;

-- Safe rollback/owner-delete function for customer bills.
create or replace function public.delete_customer_order_cascade(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  ord record;
  owner_access boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select id, created_by into ord
  from public.orders
  where id = p_order_id;

  if not found then
    return jsonb_build_object('ok', true, 'deleted', false);
  end if;

  owner_access := public.is_owner();
  if not owner_access and ord.created_by <> auth.uid() then
    raise exception 'Not allowed to delete this order';
  end if;

  delete from public.supplier_bill_items
  where supplier_bill_id in (
    select id from public.supplier_bills where order_id = p_order_id
  );
  delete from public.supplier_bills where order_id = p_order_id;
  delete from public.payments where order_id = p_order_id;
  delete from public.order_items where order_id = p_order_id;
  delete from public.orders where id = p_order_id;

  return jsonb_build_object('ok', true, 'deleted', true);
end;
$$;

grant execute on function public.delete_customer_order_cascade(uuid) to authenticated;

-- Remove existing policies so the role rules below are deterministic.
do $$
declare
  r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'profiles','menu_categories','menu_items','suppliers',
        'supplier_item_costs','orders','order_items','payments',
        'supplier_bills','supplier_bill_items'
      )
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

alter table public.profiles enable row level security;
alter table public.menu_categories enable row level security;
alter table public.menu_items enable row level security;
alter table public.suppliers enable row level security;
alter table public.supplier_item_costs enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.supplier_bills enable row level security;
alter table public.supplier_bill_items enable row level security;

-- Profiles: authenticated users may read profile display data; only owner may edit it.
create policy profiles_select_authenticated on public.profiles
for select to authenticated using (true);
create policy profiles_insert_owner on public.profiles
for insert to authenticated with check (public.is_owner());
create policy profiles_update_owner on public.profiles
for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy profiles_delete_owner on public.profiles
for delete to authenticated using (public.is_owner());

-- Categories: everyone can read active categories; owner can manage all.
create policy menu_categories_select on public.menu_categories
for select to authenticated using (active = true or public.is_owner());
create policy menu_categories_owner_insert on public.menu_categories
for insert to authenticated with check (public.is_owner());
create policy menu_categories_owner_update on public.menu_categories
for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy menu_categories_owner_delete on public.menu_categories
for delete to authenticated using (public.is_owner());

-- Menu items: normal users see available items; owner sees/edits all.
create policy menu_items_select on public.menu_items
for select to authenticated using (available = true or public.is_owner());
create policy menu_items_owner_insert on public.menu_items
for insert to authenticated with check (public.is_owner());
create policy menu_items_owner_update on public.menu_items
for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy menu_items_owner_delete on public.menu_items
for delete to authenticated using (public.is_owner());

-- Suppliers and supplier costs are owner-only.
create policy suppliers_owner_all on public.suppliers
for all to authenticated using (public.is_owner()) with check (public.is_owner());
create policy supplier_item_costs_owner_all on public.supplier_item_costs
for all to authenticated using (public.is_owner()) with check (public.is_owner());

-- Orders: all authenticated users can read; users can create their own orders; only owner can directly delete.
create policy orders_select_authenticated on public.orders
for select to authenticated using (true);
create policy orders_insert_own on public.orders
for insert to authenticated with check (created_by = auth.uid());
create policy orders_update_owner on public.orders
for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy orders_delete_owner on public.orders
for delete to authenticated using (public.is_owner());

-- Order items belong to the order creator; owner can manage all.
create policy order_items_select_authenticated on public.order_items
for select to authenticated using (true);
create policy order_items_insert_own_order on public.order_items
for insert to authenticated
with check (
  exists(select 1 from public.orders o where o.id = order_id and (o.created_by = auth.uid() or public.is_owner()))
);
create policy order_items_update_owner on public.order_items
for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy order_items_delete_owner on public.order_items
for delete to authenticated using (public.is_owner());

-- Payments are readable; users can record payments for their own orders; owner can delete.
create policy payments_select_authenticated on public.payments
for select to authenticated using (true);
create policy payments_insert_own_order on public.payments
for insert to authenticated
with check (
  exists(select 1 from public.orders o where o.id = order_id and (o.created_by = auth.uid() or public.is_owner()))
);
create policy payments_update_owner on public.payments
for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy payments_delete_owner on public.payments
for delete to authenticated using (public.is_owner());

-- Supplier payables/rates are owner-only. The SECURITY DEFINER RPC above creates them for waiters.
create policy supplier_bills_owner_all on public.supplier_bills
for all to authenticated using (public.is_owner()) with check (public.is_owner());
create policy supplier_bill_items_owner_all on public.supplier_bill_items
for all to authenticated using (public.is_owner()) with check (public.is_owner());

commit;
