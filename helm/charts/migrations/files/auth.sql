--liquibase formatted sql

--changeset swiftbite:auth-001
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
--rollback DROP TABLE users;

--changeset swiftbite:auth-002 context:dev
INSERT INTO users (id, email, password_hash) VALUES (1, 'promise@example.com', 'swiftbite$1fd574cd918f687b41bbee86f8c4f57b351ae2fb295e3e5db0513c9c84048bfc');
SELECT setval(pg_get_serial_sequence('users', 'id'), 100);
--rollback DELETE FROM users WHERE id = 1;
