V15.6 - CUSTOMER BILL PAYMENT WORKFLOW

Customer bills are now generated as Pending. The Owner can open a customer bill and use Mark as Paid.

Mark as Paid supports:
- Cash
- UPI
- Optional payment reference

After payment is recorded, the customer bill status becomes Paid. Existing bills that already have a payment remain Paid.

Supplier bill workflow is unchanged: Pending -> Mark Paid -> Paid.

Run v15_6_customer_bill_payments_migration.sql in Supabase SQL Editor before using Mark as Paid.


V15.7 role rename: Waiter is now Caretaker. Existing waiter profiles are migrated to caretaker.
