-- Part 1: ACME Relational Database Design with PostgreSQL
-- Drafted DDL, mirrored into the actual Udacity notebook once finalized.

-- Drop order matches the notebook's provided cell (CASCADE handles FK dependencies)
DROP TABLE IF EXISTS user_ratings CASCADE;
DROP TABLE IF EXISTS purchase_items CASCADE;
DROP TABLE IF EXISTS purchases CASCADE;
DROP TABLE IF EXISTS customer_addresses CASCADE;
DROP TABLE IF EXISTS customer_emails CASCADE;
DROP TABLE IF EXISTS customer_phones CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- Create order: parents first (customers, products have no dependencies)

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    first_name  TEXT NOT NULL,
    last_name   TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL
);

CREATE TABLE products (
    product_id     INTEGER PRIMARY KEY,
    product_name   TEXT NOT NULL,
    product_type   TEXT NOT NULL,
    description    TEXT,
    price          NUMERIC(10,2) NOT NULL,
    stock_quantity INTEGER NOT NULL,
    created_at     TIMESTAMP NOT NULL
);

CREATE TABLE customer_phones (
    phone_id    INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    phone       TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL
);

CREATE TABLE customer_emails (
    email_id    INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    email       TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL
);

CREATE TABLE customer_addresses (
    address_id  INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    address     TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL
);

-- POST-REVIEW FIX (2026-08-19): the original design kept large_gear_quantity/
-- large_gear_unit_price + small_gear_quantity/small_gear_unit_price as parallel
-- columns, mirroring purchases.csv exactly, on the judgment that it was a given
-- constraint of Udacity-provided source data rather than a design flaw. The
-- reviewer required it fixed anyway -- this IS a real repeating-group/3NF
-- violation regardless of where the data came from. Fixed by splitting into a
-- lean purchases table (order-level facts only) + a new purchase_items table
-- (one row per product actually purchased, referencing product_id via FK).
CREATE TABLE purchases (
    purchase_id    INTEGER PRIMARY KEY,
    customer_id    INTEGER REFERENCES customers(customer_id),
    purchase_date  TIMESTAMP NOT NULL,
    status         TEXT NOT NULL
);

CREATE TABLE purchase_items (
    purchase_item_id INTEGER PRIMARY KEY,
    purchase_id       INTEGER REFERENCES purchases(purchase_id),
    product_id         INTEGER REFERENCES products(product_id),
    quantity            INTEGER NOT NULL,
    unit_price           NUMERIC(10,2) NOT NULL
);

CREATE TABLE user_ratings (
    rating_id   INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    product_id  INTEGER REFERENCES products(product_id),
    rating      INTEGER NOT NULL,
    review_text TEXT,
    rating_date TIMESTAMP NOT NULL
);
