-- Cashew Creek Villa V15.1 Master Menu Correction
-- Updates current menu selling prices only. Historical order_items are not changed.
-- Run only if the live database still contains the old prototype prices.

begin;

update public.menu_items set selling_price = 70 where lower(btrim(name_en)) = 'sabudana khichdi';
update public.menu_items set selling_price = 70 where lower(btrim(name_en)) = 'ghavane chatani';
update public.menu_items set selling_price = 30 where lower(btrim(name_en)) = 'single omlet';
update public.menu_items set selling_price = 45 where lower(btrim(name_en)) = 'poha';
update public.menu_items set selling_price = 45 where lower(btrim(name_en)) = 'upma';
update public.menu_items set selling_price = 70 where lower(btrim(name_en)) = 'poori bhaji';
update public.menu_items set selling_price = 70 where lower(btrim(name_en)) = 'idli sambar chutney';
update public.menu_items set selling_price = 20 where lower(btrim(name_en)) = 'tea';
update public.menu_items set selling_price = 25 where lower(btrim(name_en)) = 'coffee';
update public.menu_items set selling_price = 20 where lower(btrim(name_en)) = 'milk';
update public.menu_items set selling_price = 40 where lower(btrim(name_en)) = 'omelet pav';
update public.menu_items set selling_price = 50 where lower(btrim(name_en)) = 'burji pav';
update public.menu_items set selling_price = 70 where lower(btrim(name_en)) = 'misal pav';
update public.menu_items set selling_price = 50 where lower(btrim(name_en)) = 'kanda bhaji';
update public.menu_items set selling_price = 50 where lower(btrim(name_en)) = 'batata bhaji';
update public.menu_items set selling_price = 50 where lower(btrim(name_en)) = 'mix bhaji';
update public.menu_items set selling_price = 80 where lower(btrim(name_en)) = 'pav bhaji';
update public.menu_items set selling_price = 25 where lower(btrim(name_en)) = 'extra pav';
update public.menu_items set selling_price = 300 where lower(btrim(name_en)) = 'bombil thali';
update public.menu_items set selling_price = 400 where lower(btrim(name_en)) = 'prawns thali';
update public.menu_items set selling_price = 300 where lower(btrim(name_en)) = 'bangda thali';
update public.menu_items set selling_price = 450 where lower(btrim(name_en)) = 'surmai thali';
update public.menu_items set selling_price = 450 where lower(btrim(name_en)) = 'pomfret thali';
update public.menu_items set selling_price = 320 where lower(btrim(name_en)) = 'chicken thali';
update public.menu_items set selling_price = 500 where lower(btrim(name_en)) = 'mutton thali';
update public.menu_items set selling_price = 280 where lower(btrim(name_en)) = 'veg thali';
update public.menu_items set selling_price = 150 where lower(btrim(name_en)) = 'dal khichdi';
update public.menu_items set selling_price = 15 where lower(btrim(name_en)) = 'chapati';
update public.menu_items set selling_price = 30 where lower(btrim(name_en)) = 'tandul bhakari';
update public.menu_items set selling_price = 30 where lower(btrim(name_en)) = 'modak';
update public.menu_items set selling_price = 40 where lower(btrim(name_en)) = 'puranpoli';
update public.menu_items set selling_price = 1000 where lower(btrim(name_en)) = 'veg biryani';
update public.menu_items set selling_price = 1200 where lower(btrim(name_en)) = 'chicken biryani';
update public.menu_items set selling_price = 2000 where lower(btrim(name_en)) = 'mutton biryani';
update public.menu_items set selling_price = 600 where lower(btrim(name_en)) = 'egg biryani';
update public.menu_items set selling_price = 1400 where lower(btrim(name_en)) = 'prawns biryani';
update public.menu_items set selling_price = 900 where lower(btrim(name_en)) = 'veg pulao';
update public.menu_items set selling_price = 1800 where lower(btrim(name_en)) = 'popti veg';
update public.menu_items set selling_price = 2000 where lower(btrim(name_en)) = 'popti nonveg';

commit;
