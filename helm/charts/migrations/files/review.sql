--liquibase formatted sql

--changeset swiftbite:review-001
CREATE TABLE reviews (
  id SERIAL PRIMARY KEY,
  target_type TEXT NOT NULL CHECK (target_type IN ('restaurant','rider')),
  target_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL DEFAULT 1,
  order_id BIGINT,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reviews_target ON reviews(target_type, target_id);
--rollback DROP TABLE reviews;
