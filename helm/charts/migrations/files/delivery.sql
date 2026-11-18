--liquibase formatted sql

--changeset swiftbite:delivery-001
CREATE TABLE riders (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);
CREATE TABLE deliveries (
  order_id BIGINT PRIMARY KEY,       -- plain id: orders live in another service's database
  restaurant_id INTEGER,
  items_summary TEXT NOT NULL DEFAULT '',
  rider_id INTEGER NOT NULL REFERENCES riders(id),
  status TEXT NOT NULL DEFAULT 'ACCEPTED' CHECK (status IN ('ACCEPTED','PICKED_UP','DELIVERED')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
--rollback DROP TABLE deliveries; DROP TABLE riders;

--changeset swiftbite:delivery-002
INSERT INTO riders (name) VALUES ('Tunde'), ('Amaka'), ('Chidi');
--rollback DELETE FROM riders;
