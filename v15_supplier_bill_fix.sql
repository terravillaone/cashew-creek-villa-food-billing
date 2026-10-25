-- Cashew Creek Villa V15.1 Supplier Bill Repair
-- Run this in Supabase SQL Editor once.
-- It safely cleans duplicate supplier bills, recreates the RPC, and makes
-- supplier-bill creation deterministic for customer bill generation.

begin;

-- 1) Remove duplicate supplier bills left by older V11/V12/V13/V14 versions.
-- Keep the oldest bill for each order + supplier and let its child rows remain.
with ranked as (
  select id,
         row_number() over (partition by order_id, supplier_id order by created_at, id) as rn
  from public.supplier_bills
  where order_id is not null
), duplicates as (
  select id from ranked where rn > 1
)
delete from public.supplier_bill_items
where supplier_bill_id in (select id from duplicates);

with ranked as (
  select id,
         row_number() over (partition by order_id, supplier_id order by created_at, id) as rn
  from public.supplier_bills
  where order_id is not null
), duplicates as (
  select id from ranked where rn > 1
)
delete from public.supplier_bills
where id in (select id from duplicates);

create unique index if not exists supplier_bills_order_supplier_unique
on public.supplier_bills(order_id, supplier_id);

-- 2) Recreate the RPC. SECURITY DEFINER lets waiters create supplier bills
-- without exposing supplier costs through normal table permissions.
create or replace function public.create_supplier_bills_for_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_created_by uuid;
  v_supplier_count integer := 0;
  v_bill_id uuid;
  grp record;
begin
  if auth.uid() is null then
    raise exception using message = 'Not authenticated', errcode = '42501';
  end if;

  select o.created_by
    into v_created_by
  from public.orders o
  where o.id = p_order_id;

  if not found then
    raise exception using message = 'Order not found', errcode = 'P0002';
  end if;

  if v_created_by is distinct from auth.uid() and not public.is_owner() then
    raise exception using message = 'Not allowed to create supplier bills for this order', errcode = '42501';
  end if;

  -- One supplier bill per supplier actually assigned to the ordered items.
  for grp in
    select sic.supplier_id,
           sum(oi.quantity * sic.supplier_rate)::numeric(12,2) as total_amount
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
    do update set
      total_amount = excluded.total_amount,
      status = 'pending'
    returning id into v_bill_id;

    delete from public.supplier_bill_items
    where supplier_bill_id = v_bill_id;

    insert into public.supplier_bill_items(
      supplier_bill_id, menu_item_id, item_name_en, item_name_mr,
      quantity, supplier_rate
    )
    select
      v_bill_id,
      oi.menu_item_id,
      oi.item_name_en,
      oi.item_name_mr,
      oi.quantity,
      sic.supplier_rate
    from public.order_items oi
    join public.supplier_item_costs sic
      on sic.menu_item_id = oi.menu_item_id
     and sic.supplier_id = grp.supplier_id
     and sic.active = true
    where oi.order_id = p_order_id;

    v_supplier_count := v_supplier_count + 1;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'supplier_bills', v_supplier_count
  );
exception
  when others then
    raise exception using
      message = format('Supplier bill RPC failed: %s', sqlerrm),
      errcode = sqlstate;
end;
$$;

grant execute on function public.create_supplier_bills_for_order(uuid) to authenticated;

commit;
