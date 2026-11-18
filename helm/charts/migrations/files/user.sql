--liquibase formatted sql

--changeset swiftbite:user-001
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT ''
);
CREATE TABLE addresses (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label TEXT NOT NULL DEFAULT 'Home',
  street TEXT NOT NULL,
  area TEXT NOT NULL DEFAULT '',
  city TEXT NOT NULL DEFAULT 'Lagos'
);
CREATE INDEX idx_addresses_user ON addresses(user_id);
--rollback DROP TABLE addresses; DROP TABLE users;

--changeset swiftbite:user-002 context:dev
INSERT INTO users (id, name, email, phone) VALUES (1, 'Promise', 'promise@example.com', '+2348000000000');
INSERT INTO addresses (user_id, label, street, area, city) VALUES (1, 'Home', '12 Bode Thomas St', 'Surulere', 'Lagos');
--rollback DELETE FROM users WHERE id = 1;
