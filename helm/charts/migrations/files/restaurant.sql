--liquibase formatted sql

--changeset swiftbite:restaurant-001
CREATE TABLE restaurants (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  cuisine TEXT NOT NULL,
  area TEXT NOT NULL,
  rating NUMERIC(2,1) CHECK (rating BETWEEN 0 AND 5),
  eta TEXT NOT NULL DEFAULT '30-40 min'
);
--rollback DROP TABLE restaurants;

--changeset swiftbite:restaurant-002 context:dev
INSERT INTO restaurants (id, name, cuisine, area, rating, eta) VALUES
 (1, 'Mama Put Kitchen', 'African food', 'Surulere', 4.6, '25-35 min'),
 (2, 'Pasta Palace', 'Pasta', 'Yaba', 4.4, '30-40 min'),
 (3, 'Grill House', 'Fast food', 'Ikeja', 4.2, '20-30 min'),
 (4, 'Green Bowl', 'Salad', 'Lekki', 4.5, '25-35 min'),
 (5, 'Sweet Crumbs', 'Pastries', 'Ogudu', 4.3, '20-30 min'),
 (6, 'Wok This Way', 'Asian food', 'Yaba', 4.1, '30-45 min');
SELECT setval(pg_get_serial_sequence('restaurants', 'id'), 100);
--rollback DELETE FROM restaurants WHERE id BETWEEN 1 AND 6;
