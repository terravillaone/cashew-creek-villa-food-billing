-- Cashew Creek Villa V15
-- Canonical category rename migration
-- Idempotent: safe to run once, or rerun after a partial execution.
-- This updates the actual menu_categories rows; menu_items.category_id is a FK,
-- so existing items and historical orders remain attached to the same category IDs.

begin;

-- First normalize any existing target rows so the rename does not create
-- duplicate category names if a previous partial run already created them.
update public.menu_categories
set name_en = 'Thali'
where lower(trim(name_en)) = lower(trim('Cashew Creek Thali'));

update public.menu_categories
set name_en = 'Desserts'
where lower(trim(name_en)) = lower(trim('Cashew Creek Sweet'));

update public.menu_categories
set name_en = 'Biryani by Kilo'
where lower(trim(name_en)) = lower(trim('Cashew Creek Special'));

-- Keep Marathi category labels consistent with the English category names.
-- These categories were previously using the English label as name_mr.
update public.menu_categories
set name_mr = 'थाळी'
where lower(trim(name_en)) = lower(trim('Thali'))
  and (name_mr is null or lower(trim(name_mr)) = lower(trim('Cashew Creek Thali')));

update public.menu_categories
set name_mr = 'डेसर्ट्स'
where lower(trim(name_en)) = lower(trim('Desserts'))
  and (name_mr is null or lower(trim(name_mr)) = lower(trim('Cashew Creek Sweet')));

update public.menu_categories
set name_mr = 'बिर्याणी बाय किलो'
where lower(trim(name_en)) = lower(trim('Biryani by Kilo'))
  and (name_mr is null or lower(trim(name_mr)) = lower(trim('Cashew Creek Special')));

commit;
