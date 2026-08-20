# Part 2 — MongoDB drafted queries

PyMongo queries drafted here, mirrored into the actual Udacity notebook once finalized.

**Final version, authored by the user (2026-08-19)** — superseded an earlier Claude-drafted version that used fictional "Alice Chen/aerospace" data; see `notes.md` for the full revision history (why it changed, twice).

## Customer collection — document creation (final)

```python
customer_1 = {
    "customer_id": 1,
    "first_name": "Alice",
    "last_name": "Wonderland",
    "email": "alice@wonderland.fake",
    "phone": "555-0101",
    "address": "1 Rabbit Hole Lane",
    "customer_industry": "industrial manufacturing",

    "purchases": [
        {
            "purchase_id": 1,
            "product_id": 1,
            "product_name": "A Large Gear",
            "quantity": 2,
            "unit_price": 450.0,
            "total_price": 900.0,
            "purchase_date": "2026-08-19",
            "status": "completed"
        },
        {
            "purchase_id": 2,
            "product_id": 2,
            "product_name": "B Large Gear",
            "quantity": 2,
            "unit_price": 450.0,
            "total_price": 900.0,
            "purchase_date": "2026-08-19",
            "status": "completed"
        }
    ],

    "products": [
        {
            "product_id": 1,
            "product_name": "A Large Gear",
            "product_intended_industry": "industrial manufacturing",
            "material": "A steel",
            "color": "white"
        },
        {
            "product_id": 2,
            "product_name": "B Large Gear",
            "product_intended_industry": "industrial manufacturing",
            "material": "B steel",
            "weight_in_pounds": 300.0
        }
    ]
}
```

Note the embedded field names are `purchases`/`products` (renamed from the earlier `recent_purchases`/`industry_products` draft) — a deliberate choice, accepting the readability tradeoff of sharing a name with the top-level collections (discussed and accepted).

## Products collection — document creation (final)

```python
product_1 = {
    "product_id": 1,
    "product_name": "A Large Gear",
    "product_intended_industry": "industrial manufacturing",
    "price": 450.0,
    "stock_quantity": 120,
    "material": "A steel",
    "weight_in_pounds": 100.0,
    "dimensions": "10x10x10",
    "color": "black"
}

product_2 = {
    "product_id": 2,
    "product_name": "B Large Gear",
    "product_intended_industry": "industrial manufacturing",
    "price": 450.0,
    "stock_quantity": 120,
    "material": "B steel",
    "weight_in_pounds": 200.0,
    "dimensions": "20x20x20",
    "color": "white",
    "strength": "strong"
}
```

`product_2` has a `strength` field `product_1` doesn't have — satisfies "varying attribute fields." Both `product_id` 1 and 2 exist here for real, matching what's referenced in `customer_1.purchases`/`customer_1.products` — no orphaned references (an earlier 10-product draft had this bug: only `product_id` 1-2 existed as real documents while purchases/embedded products referenced up to `product_id` 10).

## Purchases collection — document creation (final)

```python
purchase_1 = {
    "purchase_id": 1,
    "customer_id": 1,
    "product_id": 1,
    "quantity": 2,
    "unit_price": 450.0,
    "total_price": 900.0,
    "purchase_date": "2026-08-19",
    "status": "completed"
}

purchase_2 = {
    "purchase_id": 2,
    "customer_id": 1,
    "product_id": 2,
    "quantity": 2,
    "unit_price": 450.0,
    "total_price": 900.0,
    "purchase_date": "2026-08-19",
    "status": "completed"
}
```

Lean — only `customer_id`/`product_id` as references, no embedded product name/details — in contrast to the richer embedded copy in `customer_1.purchases` (which does include `product_name`). That contrast is what demonstrates referencing is actually being used, not just claimed. `unit_price`/`total_price` match `product_2`'s real price (450.0) — an earlier draft had `purchase_2` referencing `product_id: 2` while using `product_id: 1`'s price, a math/data bug now fixed.

## Loading Collections into MongoDB (the ONE place inserts happen)

The notebook has a separate "Loading Collections into MongoDB" cell after the three document-definition cells above — same pattern as Part 1's DDL cell → Loading Test Data cell split. **Insert calls belong only here**, not inside the Customer/Product/Purchases Collection cells — putting `insert_many(...)` in both places caused a real `BulkWriteError: E11000 duplicate key error` the first time through, because PyMongo stamps an `_id` onto a dict after inserting it, so re-running the same dict through `insert_many` a second time tries to insert that same `_id` again.

If the collections are already in a partially-inserted state from a failed run, reset first:
```python
db.customers.drop()
db.products.drop()
db.purchases.drop()
print("Dropped existing collections — ready for a clean reload")
```

Then, after re-running the (insert-free) Customer/Product/Purchases cells to redefine the dicts fresh, run the actual load exactly once:
```python
# Load Customer Collection
db.customers.insert_many([customer_1])
print(f"Inserted {db.customers.count_documents({})} customer documents")

# Load Product Collection
db.products.insert_many([product_1, product_2])
print(f"Inserted {db.products.count_documents({})} product documents")

# Load Purchases Collection
db.purchases.insert_many([purchase_1, purchase_2])
print(f"Inserted {db.purchases.count_documents({})} purchase documents")
```

## Query section (find/filter demos) — drafted, needs field-name update

⚠️ These still reference the old `recent_purchases` field name — needs updating to `purchases` (and adjusting `customer_id: 1`'s data, which is now Alice Wonderland, not Alice Chen) before running.

```python
# 1. Orders Page — find_one with a filter + projection
customer_orders = db.customers.find_one(
    {"customer_id": 1},
    {"_id": 0, "first_name": 1, "purchases": 1}
)
print("Orders Page data:", customer_orders)

# 2. Catalog Page — find() with a comparison operator filter
catalog_results = db.products.find({"price": {"$lt": 500}})
print("Catalog Page (products under $500):")
for product in catalog_results:
    print(f"  {product['product_name']} — ${product['price']}")
```

Query 2's threshold changed from `$lt: 100` to `$lt: 500` since both real products are now priced at 450.0 (the old `$lt: 100` filter would return zero results against the current product prices). Query 2's filter, `{"price": {"$lt": 500}}`, is a nested dict: the outer dict's `"price"` key maps to *another* dict, `{"$lt": 500}}`, where `$lt` is MongoDB's "less than" operator — this is how PyMongo expresses comparisons instead of plain equality.
