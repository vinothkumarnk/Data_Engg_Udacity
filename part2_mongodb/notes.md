# Part 2 — MongoDB

Design notes for ACME 3D Printing's document schema (customers, products, purchases collections; embedding vs. referencing decisions).

## NoSQL Modeling Design Decisions (notebook answers)

**1. Why are recent purchases and industry products embedded in the customer document?**
Embed when data is usually read together, when you want fewer joins/lookups, and only when the embedded data stays reasonably limited in size.

**2. What are the trade-offs of embedding vs. referencing?**
Embedding = faster reads, simpler retrieval, but more duplication and bigger docs. Referencing = less duplication, easier updates, but more queries and complexity.

**3. How does this schema handle products with different attributes?**
Uses a flexible document structure where each product stores only the fields that apply to it. Unlike a fixed relational schema, NoSQL documents don't require every product to have the same columns — supports different product categories with different properties while keeping all product data in the same collection.

## Requirements recap

- 3 collections: `customers`, `products`, `purchases`. `products` needs ≥2 documents with genuinely varying attributes (flexible schema demo); `customers`/`purchases` need ≥1 each.
- **Embed** (required, specific): last 10 purchases inside the customer doc (Orders page); industry-matching product info inside the customer doc ("In Your Industry" page).
- **Reference** (required, ≥1 place): suggested spot is purchases beyond the latest 10 — by ID, not embedded, since purchase history only grows.
- ≥2 PyMongo queries, ≥1 with filtering.
- No provided sample data this time (unlike Part 1's CSVs) — we create it ourselves.

## Customer collection — design decided

Base fields carried over from Part 1 where the concept is genuinely the same entity: `customer_id`, `first_name`, `last_name`, `email`, `phone`, `address` — flat fields here (not separate phone/email/address tables like Part 1), plus a new `customer_industry` field per the Part 2 instructions.

Two embedded arrays per the Application Code Requirements:
- `recent_purchases` — up to 10 purchase objects, newest first. Each entry is a **snapshot at purchase time** (`product_name`/`unit_price` copied in, not looked up live) — a deliberate denormalization so an old order doesn't silently change if a product's price changes later.
- `industry_products` — product objects matching the customer's own `customer_industry`, embedded as a browsing convenience so the app doesn't have to search the whole `products` collection per page load.

**Purchase line-item shape — intentionally NOT copied from Part 1's `purchases` table.** Part 1 used `large_gear_quantity`/`large_gear_unit_price` (ACME Corp only ever sells 2 fixed gear types). ACME 3D Printing sells arbitrarily varied custom products, so there's no fixed list of product types to hardcode as column names — used a generic `product_id`/`quantity`/`unit_price` shape instead, one entry per product actually purchased. Closer to how `user_ratings` already references `product_id` directly in Part 1 than to `purchases`' special-cased shape.

Two sample customers created (`customer_1` = Alice Chen, aerospace; `customer_2` = Bob Martinez, automotive), each with one embedded purchase + one embedded industry product. `product_id` 301 (Titanium Bracket) and 302 (Carbon Fiber Panel) are used consistently here and need to be reused as real documents when the `products` collection is built, so the embedded snapshots aren't orphaned data pointing at nothing.

## Products collection — design decided

Base fields: `product_id`, `product_name`, `product_intended_industry`, `price`, `stock_quantity` — plus flexible attributes that genuinely differ per document, not just the same fields with different values.

3 products, chosen deliberately to make the flexible-schema requirement obvious rather than barely satisfied:
- `301` Titanium Bracket (aerospace) — adds `material`, `weight_kg`, `dimensions_cm`, `tensile_strength_mpa`
- `302` Carbon Fiber Panel (automotive) — adds `material`, `dimensions_cm`, `color`, `finish`
- `303` Custom Phone Case (consumer_goods) — adds `material`, `color`, `compatible_device`, `print_resolution_microns`

`tensile_strength_mpa` only makes sense for the bracket, `finish` only for the panel, `compatible_device`/`print_resolution_microns` only for the phone case — three genuinely different attribute sets, which is the actual point of "flexible schema" (not just technically having ≥2 documents).

`301`/`302` intentionally match the `product_id`s already embedded in `customer_1`/`customer_2`'s `industry_products` (see Customer collection notes above), so those embedded snapshots correspond to real documents. `303` isn't referenced by any customer yet — included purely to demonstrate schema flexibility.

**How this was designed (methodology):**
1. Started from the instructions' own example attribute list ("material, color, dimensions, weight, etc.") as the seed for what flexible fields to use — not invented from scratch.
2. Reused `price`/`stock_quantity` field names from Part 1's `products` table, same "same entity → same name" rule as the customer fields.
3. Read the rubric's "varying attribute fields" bar as needing to be *meaningful*, not just technically true — two products differing only in `color: red` vs `color: blue` would technically satisfy it, but wouldn't demonstrate what a flexible schema is actually for. Picked 3 unrelated domains instead, so each has at least one attribute the others lack entirely.
4. Reused `301`/`302` as IDs on purpose, matching what was already embedded in the customer documents — picking different numbers would have left those embedded snapshots pointing at nonexistent products, a real design bug (an orphaned reference), not just a cosmetic mismatch.
5. Matched `product_intended_industry` values (`"aerospace"`, `"automotive"`) exactly to the `customer_industry` strings already used, since the "In Your Industry" embedding logic depends on those strings actually matching.

## Purchases collection — design decided

Fields: `purchase_id`, `customer_id`, `product_id`, `quantity`, `unit_price`, `total_price`, `purchase_date`, `status`. Deliberately **lean** — only ID references to customer/product, no embedded customer or product details — in direct contrast to `customers.recent_purchases`, which embeds a rich snapshot including `product_name`. That contrast is what actually demonstrates the referencing requirement, not just having a 3rd collection exist.

3 documents: `purchase_1`/`purchase_2` mirror what's already embedded in `customer_1`/`customer_2` (so this collection is the real source those snapshots came from), and `purchase_3` is Alice's **older** purchase (`purchase_date: 2026-03-02`) that is not embedded anywhere on her customer doc — the actual "purchases beyond the latest 10" scenario from the instructions, scaled down from 10 to 1 to keep the sample data small while still being a real, non-trivial example (not embedded + also not identical to an embedded one).

**How this was designed (methodology):** read the instructions' own suggested example ("purchases beyond the latest 10... reference the customer and product by ID rather than being fully embedded") as a design constraint, not just a suggestion — so the standalone collection had to look meaningfully different (leaner) from the embedded copy, not just be a duplicate collection with the same shape. Reused `purchase_id`/`quantity`/`unit_price`/`total_price`/`purchase_date`/`status` field names from the already-decided `recent_purchases` shape for consistency, and reused `customer_id 1` (Alice) for `purchase_3` specifically so it's a genuine second purchase for an existing customer rather than an unrelated one-off record.
