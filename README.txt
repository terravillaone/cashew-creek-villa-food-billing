CASHEW CREEK VILLA — V15.9

V15 keeps the V14 functionality and fixes the issues found during code audit.

KEY CHANGES
- Uses the supplied Cashew Creek logo artwork on the login screen and left side of the website header.
- Owner has two submenus: Menu and User.
- Menu Management remains under Owner > Menu.
- User creation remains under Owner > User.
- Order search and Owner Menu search are retained.
- Customer Bills now have a search box.
- Existing Marathi names are editable in Owner > Menu.
- Generate Bill button now correctly disables while saving.
- Fixed Repair / Load Master Menu category reset bug.
- Dashboard's "Today" uses Asia/Kolkata rather than the browser timezone.
- Supplier payable screens show the customer bill number instead of an internal UUID.
- Supplier bill creation is moved to a SECURITY DEFINER database RPC so supplier rates do not need to be exposed to waiters.
- Customer-order cleanup is moved to a SECURITY DEFINER database RPC.
- Username-based user creation is moved to a Supabase Edge Function; the service-role key is never shipped to the browser.
- Removed Excel functionality.
- V14 menu-name normalization is retained.

IMPORTANT SUPABASE STEPS
1. Run v15_security_and_rpc_migration.sql once in the Supabase SQL Editor.
2. Deploy supabase/functions/create-villa-user/index.ts as the Edge Function named create-villa-user.
3. The Edge Function uses Supabase's server-side environment variables; do NOT put a service-role key into index.html.
4. Hard-refresh the site after deployment. If the old PWA is still visible, unregister the old service worker once in Chrome DevTools > Application > Service Workers.

The V15 frontend is ready for GitHub Pages. The bundled Supabase function must be deployed separately because GitHub Pages cannot host a server-side Supabase service-role function.

CATEGORY DATABASE RENAME (V15.1)
Run v15_category_rename_migration.sql once in Supabase SQL Editor. It changes the actual menu_categories.name_en values to:
- Thali
- Desserts
- Biryani by Kilo
Existing menu_items remain linked because their category_id values are unchanged.

V15.5 SUPPLIER PAYABLES
- Supplier bills start as Pending.
- Owner can mark a supplier bill as Paid using Cash or UPI and optionally record a reference.
- Paid date/time and Paid By are stored.
- Supplier Payables shows Pending and Paid totals.
- Re-running supplier-bill generation no longer resets an already-paid supplier bill to Pending.
- Run v15_3_supplier_payments_migration.sql once after the earlier V15 supplier/RPC migrations.


V15.9 CUSTOMER PAID STATUS FIX
- Run v15_9_customer_paid_sync.sql once after the earlier customer-payment migrations.
- Deploy the V15.9 frontend to GitHub Pages.
- Hard refresh with Ctrl+Shift+R if the old cached page remains.
