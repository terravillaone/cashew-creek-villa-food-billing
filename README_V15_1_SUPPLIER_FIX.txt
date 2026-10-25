V15.1 SUPPLIER BILL FIX

The live app reported HTTP 400 from create_supplier_bills_for_order.
Use v15_supplier_bill_fix.sql in Supabase SQL Editor before testing customer billing again.
It cleans duplicate supplier bills, creates the required unique index, and recreates the RPC.
Do not remove the existing V15 security migration.
