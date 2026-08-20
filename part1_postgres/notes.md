# Part 1 — PostgreSQL

Design notes and drafted DDL for ACME's relational OLTP schema (Customers, Products, Purchases, User Ratings).

## How the schema was designed (methodology, not just the result)

1. **Ran `df.dtypes` + `df.head(3)` on all 7 dataframes first.** Every column name and pandas-inferred type came from that output — nothing was guessed blind.
2. **Translated pandas dtypes → SQL types** using a simple mapping, but checked column *names* too, not just the dtype:
   - `int64` → `INTEGER`
   - `float64` → `NUMERIC(10,2)` for money-like columns
   - `object` → `TEXT`, *unless* the column name ends in `_date`/`_at` (e.g. `created_at`), in which case it's really a timestamp that pandas just read as a string — typed as `TIMESTAMP` instead. This is what satisfies the rubric's "not all VARCHAR" requirement — it takes actually looking at each column, not a blanket rule.
3. **Picked primary keys** by finding the obvious unique `_id` column already present in each table's own dtypes (`customer_id`, `phone_id`, `product_id`, etc.).
4. **Picked foreign keys** by matching column names *across* tables — e.g. `customer_phones.customer_id` also exists in `customers`, so it's a FK back to `customers.customer_id`.
5. **Got exact table names + CREATE order for free from the notebook's own DROP TABLE cell** — it already listed all 7 real table names (confirming `user_ratings`, not `ratings`) with `CASCADE`, dropping children before parents. Reversed that logic for `CREATE`: parents first (`customers`, `products` — nothing references them), then everything with a `REFERENCES` clause.
6. **Cross-checked against the rubric and the Project Overview page**, not just the data — spotted the `purchases` repeating-group issue (`large_gear_quantity`/`small_gear_quantity` as parallel columns) by connecting the Overview's "ACME sells two types of gears" line to the rubric's explicit "no repeating groups" criterion, not from the dtypes alone.

**The reusable version of this**: dtypes tell you SQL types, column names tell you PK/FK relationships, any provided DROP/scaffold code tells you exact names and order, and the rubric tells you what to double-check for beyond what the raw data shows.

## Status: DDL run successfully, all 7 tables created and loaded

Ran the drafted DDL in the Workspace notebook — schema inspection confirms all 7 tables with correct PK/FK, and the "Loading data..." + row-count cells confirm every CSV loaded successfully (e.g. `products: 2, purchases: 21, user_ratings: 15`).

**Resolved (at the time): the `purchases` repeating-group question.** Decided to keep `large_gear_quantity`/`large_gear_unit_price` + `small_gear_quantity`/`small_gear_unit_price` as-is, mirroring `purchases.csv` exactly. Reasoning: this data shape was provided by Udacity, not chosen — it's a given constraint of the source data, not a design gap on our end.

## Post-review fix (2026-08-19) — the above decision was overturned by real grading feedback

**Verdict: ⚠️ Did not pass**, specifically on this one item — everything else (types, PKs, FKs, all 7 CSVs loading with verified row counts) was explicitly praised. The reviewer's point: "the data was provided in this shape" doesn't exempt it from 3NF — it's a real repeating-group violation regardless of where the wide shape came from, and it also duplicates `products.price` into `purchases` with no FK ever declared to `products` at all. Lesson: a design tradeoff reasoned through carefully can still be *wrong* by the actual grading criteria — reasoning something through isn't the same as it being correct.

**Fix**: split `purchases` into a lean order-level table + a new `purchase_items` line-item table, referencing `product_id` via FK — see `schema.sql` for the DDL. Also required a data-transform step, since `purchases.csv`'s wide shape can't map into the new normalized tables via a plain `.to_sql()` call:

```python
# Reshape purchases.csv (wide, one row per order) into purchases + purchase_items
# (normalized, one row per product actually bought) — fixes the 3NF issue from review.

purchases_rows = []
purchase_items_rows = []
item_id_counter = 1

for _, row in purchases_df.iterrows():
    # order-level info only
    purchases_rows.append({
        "purchase_id": row["purchase_id"],
        "customer_id": row["customer_id"],
        "purchase_date": row["purchase_date"],
        "status": row["status"]
    })

    # one line item per product actually purchased (skip if qty is 0)
    if row["large_gear_quantity"] > 0:
        purchase_items_rows.append({
            "purchase_item_id": item_id_counter,
            "purchase_id": row["purchase_id"],
            "product_id": 1,  # Industrial Large Gear
            "quantity": row["large_gear_quantity"],
            "unit_price": row["large_gear_unit_price"]
        })
        item_id_counter += 1

    if row["small_gear_quantity"] > 0:
        purchase_items_rows.append({
            "purchase_item_id": item_id_counter,
            "purchase_id": row["purchase_id"],
            "product_id": 2,  # Precision Small Gear
            "quantity": row["small_gear_quantity"],
            "unit_price": row["small_gear_unit_price"]
        })
        item_id_counter += 1

purchases_clean_df = pd.DataFrame(purchases_rows)
purchase_items_df = pd.DataFrame(purchase_items_rows)
```

Loading step (extends the notebook's existing schema-inspection + load-all cell, special-casing `purchases`/`purchase_items` instead of a direct CSV read):
```python
for table in tables:  # tables list now includes "purchase_items"
    if table == "purchases":
        purchases_clean_df.to_sql("purchases", engine, if_exists="append", index=False)
        purchase_items_df.to_sql("purchase_items", engine, if_exists="append", index=False)
    elif table == "purchase_items":
        continue  # already loaded above, alongside purchases
    else:
        df = pd.read_csv(os.path.join(csv_path, f'{table}.csv'))
        df.to_sql(table, engine, if_exists='append', index=False)
```

Two real bugs caught and fixed while wiring this in (both worth remembering as general patterns, not just this-project trivia):
- `DROP TABLE IF EXISTS purchase_items CASCADE;` had to be added to the DROP section — without it, `CASCADE` on `DROP TABLE purchases` only drops the *foreign key constraint* on `purchase_items`, not the table itself, so a second run of the DDL cell would fail with "relation already exists."
- A missing comma between two adjacent string literals in the `tables` Python list (`"purchase_items"` `"user_ratings"`) silently merged them into one garbage string via Python's implicit string concatenation — caught before it caused a confusing `RuntimeError`.
