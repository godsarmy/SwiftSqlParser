CREATE TABLE public.order_items (order_id INT, item_id INT, CONSTRAINT order_items_pk PRIMARY KEY (order_id, item_id));
CREATE UNIQUE INDEX order_items_sku_idx ON public.order_items (order_id, item_id);
CREATE VIEW active_entities AS SELECT id FROM users UNION ALL SELECT id FROM service_accounts;
ALTER TABLE public.order_items ADD CONSTRAINT order_items_check CHECK (order_id > 0);
DROP TABLE public.order_items;
TRUNCATE TABLE public.order_items;
