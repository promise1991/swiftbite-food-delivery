--liquibase formatted sql

--changeset swiftbite:menu-001
CREATE TABLE menu_items (
  id SERIAL PRIMARY KEY,
  restaurant_id INTEGER NOT NULL,   -- plain id on purpose: restaurants live in another service's database
  name TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL CHECK (price >= 0)
);
CREATE INDEX idx_menu_restaurant ON menu_items(restaurant_id);
--rollback DROP TABLE menu_items;

--changeset swiftbite:menu-002 context:dev
INSERT INTO menu_items (id, restaurant_id, name, price) VALUES
 (11, 1, 'Jollof rice and chicken', 3500), (12, 1, 'Pounded yam and egusi', 4200), (13, 1, 'Chapman', 1500),
 (21, 2, 'Spaghetti bolognese', 4000), (22, 2, 'Creamy chicken penne', 4500), (23, 2, 'Garlic bread', 1200),
 (31, 3, 'Double beef burger', 5000), (32, 3, 'Peppered chicken wings', 3800), (33, 3, 'Fries', 1500),
 (41, 4, 'Caesar salad', 3800), (42, 4, 'Chicken avocado bowl', 4800), (43, 4, 'Fresh smoothie', 2000),
 (51, 5, 'Meat pie', 1000), (52, 5, 'Chin chin pack', 1500), (53, 5, 'Cream doughnut', 900),
 (61, 6, 'Chicken fried rice', 4200), (62, 6, 'Beef noodles', 3900), (63, 6, 'Spring rolls', 2000);
SELECT setval(pg_get_serial_sequence('menu_items', 'id'), 1000);
--rollback DELETE FROM menu_items WHERE id < 1000;
