-- V15.6: Customer bill payment workflow
-- Customer bills are generated as Pending. Owner marks them Paid after receiving Cash/UPI.
-- Existing customer bills that already have a payment remain effectively Paid.

BEGIN;

-- Keep payment methods limited to the two supported methods.
ALTER TABLE payments
  DROP CONSTRAINT IF EXISTS payments_payment_method_check;

ALTER TABLE payments
  ADD CONSTRAINT payments_payment_method_check
  CHECK (lower(payment_method) IN ('cash','upi'));

-- Ensure one payment per customer order for the new workflow.
-- Existing duplicates are collapsed by keeping the latest payment for each order.
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY paid_at DESC NULLS LAST, id DESC) AS rn
  FROM payments
)
DELETE FROM payments p
USING ranked r
WHERE p.id = r.id
  AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS payments_order_id_unique
  ON payments(order_id);

-- Owner-only RPC to mark a customer bill paid.
CREATE OR REPLACE FUNCTION public.mark_customer_bill_paid(
  p_order_id uuid,
  p_payment_method text,
  p_payment_reference text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
  v_total numeric := 0;
  v_existing uuid;
BEGIN
  SELECT role INTO v_role
  FROM profiles
  WHERE id = auth.uid();

  IF COALESCE(v_role, '') <> 'owner' THEN
    RAISE EXCEPTION 'Only the owner can mark customer bills as paid.';
  END IF;

  IF lower(p_payment_method) NOT IN ('cash','upi') THEN
    RAISE EXCEPTION 'Payment method must be Cash or UPI.';
  END IF;

  SELECT COALESCE(SUM(COALESCE(oi.line_total, oi.quantity * oi.selling_price)), 0)
    INTO v_total
  FROM order_items oi
  WHERE oi.order_id = p_order_id;

  IF NOT EXISTS (SELECT 1 FROM orders WHERE id = p_order_id) THEN
    RAISE EXCEPTION 'Customer bill not found.';
  END IF;

  SELECT id INTO v_existing
  FROM payments
  WHERE order_id = p_order_id
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    UPDATE orders
    SET status = 'paid'
    WHERE id = p_order_id;
    RETURN jsonb_build_object('ok', true, 'already_paid', true, 'payment_id', v_existing);
  END IF;

  INSERT INTO payments(order_id, amount, payment_method, paid_at)
  VALUES (p_order_id, v_total, lower(p_payment_method), now())
  RETURNING id INTO v_existing;

  UPDATE orders
  SET status = 'paid'
  WHERE id = p_order_id;

  -- Payment reference is intentionally optional. If your payments table has a
  -- payment_reference column, store it; otherwise the supported workflow does
  -- not require it.
  BEGIN
    IF p_payment_reference IS NOT NULL AND btrim(p_payment_reference) <> '' THEN
      EXECUTE 'UPDATE payments SET payment_reference = $1 WHERE id = $2'
        USING btrim(p_payment_reference), v_existing;
    END IF;
  EXCEPTION WHEN undefined_column THEN
    NULL;
  END;

  RETURN jsonb_build_object('ok', true, 'already_paid', false, 'payment_id', v_existing);
END;
$$;

REVOKE ALL ON FUNCTION public.mark_customer_bill_paid(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_customer_bill_paid(uuid, text, text) TO authenticated;

COMMIT;
