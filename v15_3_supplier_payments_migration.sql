-- Cashew Creek Villa V15.3
-- Supplier payable workflow
-- Run after v15_security_and_rpc_migration.sql and v15_supplier_bill_fix.sql.
-- Adds owner-controlled supplier payment tracking without changing customer prices.

begin;

alter table public.supplier_bills
  add column if not exists paid_by uuid references public.profiles(id) on delete set null;

alter table public.supplier_bills
  add column if not exists payment_method text;

alter table public.supplier_bills
  add column if not exists payment_reference text;

-- Keep supplier payment method limited to the two methods used by the application.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'supplier_bills_payment_method_check'
      and conrelid = 'public.supplier_bills'::regclass
  ) then
    alter table public.supplier_bills
      add constraint supplier_bills_payment_method_check
      check (payment_method is null or payment_method in ('cash','upi'));
  end if;
end $$;

-- Rebuild the supplier-bill RPC so re-running it does NOT reset an already-paid bill to Pending.
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
    do update set total_amount = excluded.total_amount
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

-- Owner-only action to mark a supplier payable as paid.
create or replace function public.mark_supplier_bill_paid(
  p_supplier_bill_id uuid,
  p_payment_method text,
  p_payment_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  b record;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_owner() then
    raise exception 'Only the owner can mark supplier bills as paid';
  end if;

  if lower(coalesce(p_payment_method,'')) not in ('cash','upi') then
    raise exception 'Payment method must be Cash or UPI';
  end if;

  select id, status into b
  from public.supplier_bills
  where id = p_supplier_bill_id
  for update;

  if not found then
    raise exception 'Supplier bill not found';
  end if;

  if b.status = 'cancelled' then
    raise exception 'Cancelled supplier bills cannot be marked as paid';
  end if;

  if b.status = 'paid' then
    return jsonb_build_object('ok', true, 'already_paid', true);
  end if;

  update public.supplier_bills
  set status = 'paid',
      paid_at = now(),
      paid_by = auth.uid(),
      payment_method = lower(p_payment_method),
      payment_reference = nullif(btrim(p_payment_reference), '')
  where id = p_supplier_bill_id;

  return jsonb_build_object('ok', true, 'already_paid', false);
end;
$$;

grant execute on function public.mark_supplier_bill_paid(uuid,text,text) to authenticated;

commit;
