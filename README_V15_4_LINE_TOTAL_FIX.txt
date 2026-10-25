Cashew Creek Villa V15.5 — Supplier line_total fix

Problem fixed:
The database defines supplier_bill_items.line_total as a generated/computed column.
V15.5 attempted to insert a value into that column, causing:
"Cannot insert a non default value into column line_total"
and therefore customer bill generation was rolled back.

Action required:
1. Run v15_4_supplier_line_total_fix.sql in Supabase SQL Editor.
2. Deploy the V15.5 website files.
3. Hard refresh the browser (Ctrl+Shift+R).

The fixed RPC inserts only:
- supplier_bill_id
- menu_item_id
- item_name_en
- item_name_mr
- quantity
- supplier_rate

The database calculates line_total itself.

V15.5 supplier payables behavior is retained:
- Pending / Paid / Cancelled supplier bill status
- Mark as Paid
- Cash / UPI supplier payment method
- paid_by / paid_at / payment_reference
- already-paid bills are not reset to pending when regenerated
