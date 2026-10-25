-- V15.9: Customer bill paid-status synchronization
-- Run once in Supabase SQL Editor.
-- This keeps existing payment records as the source of truth and synchronizes
-- orders.status so the Bills list and View Bill show the same status.

BEGIN;

-- Any order that has a customer payment is Paid.
UPDATE public.orders o
SET
    status = 'paid',
    completed_at = COALESCE(o.completed_at, p.paid_at, o.created_at)
FROM public.payments p
WHERE p.order_id = o.id
  AND COALESCE(lower(o.status), '') <> 'cancelled';

COMMIT;
