--liquibase formatted sql

--changeset swiftbite:payment-001
CREATE TABLE payments (
  id SERIAL PRIMARY KEY,
  payment_id TEXT NOT NULL,
  reference TEXT NOT NULL UNIQUE,
  order_id BIGINT NOT NULL UNIQUE,   -- plain id: orders live in another service's database
  amount NUMERIC(10,2) NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('paystack','flutterwave')),
  currency TEXT NOT NULL DEFAULT 'NGN',
  status TEXT NOT NULL,
  paid_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
--rollback DROP TABLE payments;
