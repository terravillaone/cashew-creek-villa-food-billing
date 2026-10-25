V15.5 Supplier Payables Fix

Run v15_5_supplier_payables_complete_fix.sql in Supabase SQL Editor.
This migration is idempotent and combines the supplier payment columns with the
supplier-bill line_total generated-column fix. It is safe to run after earlier
V15 migrations and does not delete customer bills or supplier bills.

The application expects supplier_bills.payment_method, paid_by, and payment_reference.
