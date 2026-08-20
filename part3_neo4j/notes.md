# Part 3 — Neo4j

Design notes for ACME 3D Printing's graph schema (Customer/Product/+1 node type, PURCHASED/ALSO_BOUGHT relationships, recommendation queries).

**Revision history**: this went through 2 major rewrites as Part 2's underlying data changed. v1 used fictional data (Alice Chen/aerospace, Bob Martinez/automotive, 3 unrelated products). v2 switched to reusing Part 1's real customer (Alice Wonderland) and real products, still with 2 customers/3 industries. v3 matched the user's own final, simplified Part 2 build: 1 customer, 2 products, 1 industry, with every node/relationship property name aligned exactly to the Part 2 MongoDB document field names.

## Post-review fix (2026-08-19) — REAL SUBMISSION FAILURE, root cause found

**Verdict: ⚠️ Does Not Pass**, on first submission. Root cause: every `CREATE` Cypher string (`create_customer_nodes_query`, `create_product_nodes_query`, `create_purchased_query`, `create_purchased_query_2`, `create_also_bought_query`) was **defined but never passed to `neo4j_conn.execute_query(...)`**. Defining a Python string does nothing to the database — only calling `execute_query()` on it does. The notebook's own reset step (`MATCH (n) DETACH DELETE n`) wiped the graph and it was never repopulated, which is exactly why every later query returned "label/relationship type does not exist" warnings — the database was telling the truth, nothing had actually been created.

Two more bugs found in the same pass:
- A stray extra closing brace in `create_product_nodes_query`: `"strength": "strong"}})` should be `"strong"})`  — would have thrown a Cypher syntax error the moment it was actually executed (so simply adding the missing `execute_query()` call wasn't sufficient on its own).
- Only 2 node types existed (Customer, Product) — the rubric requires "Customer, Product, and at least one additional node type." `Industry` + a `WORKS_IN` relationship needed to be added, not just executed.

**Fix scope — deliberately trimmed to the minimum required**, not the fuller earlier design. Kept: `Customer`, `Product` (2 docs), `Industry` (1 doc) nodes; `PURCHASED` (×2), `ALSO_BOUGHT`, `WORKS_IN` relationships — all now actually run through `execute_query()`. Dropped for this fix (not required by the review, can be re-added later as standout work): `SERVES`, `SIMILAR_TO` relationships, and Cells 4/5 (the two optional standout recommendation queries). See `queries.cypher` for the exact current (minimum-fix) version.

**New standing habit, per the reviewer's own suggestion**: added a sanity-check cell right after node/relationship creation — `MATCH (n) RETURN labels(n), count(*)` — to confirm the graph actually has what's expected *before* moving on to the recommendation query, rather than discovering an empty graph 3 cells later via a confusing warning. Worth doing this on every future Cypher-writing task, not just this one.

**The lesson worth generalizing**: "I wrote the query" and "I ran the query" are two different facts, and code review (or a sanity check) is what catches the gap between them — the graph design/reasoning itself was never wrong, only the execution step was silently skipped.

## Graph built (current version)

```
   Alice (customer_id 1, industrial manufacturing)
      │
      ├──PURCHASED (qty 2, $450, purchase_id 1)──▶ A Large Gear (product_id 1)
      │                                                    │  ▲
      │                                          ALSO_BOUGHT (1.0)  SIMILAR_TO
      │                                                    ▼  │
      └──PURCHASED (qty 2, $450, purchase_id 2)──▶ B Large Gear (product_id 2)

   Alice ──WORKS_IN──▶ [industrial manufacturing] ◀──SERVES── A Large Gear
                                                    ◀──SERVES── B Large Gear
```

Nodes: `Customer` (Alice Wonderland only), `Product` (A Large Gear / product_id 1, B Large Gear / product_id 2), `Industry` (industrial manufacturing — the required "≥1 additional node type"). No standalone `Purchase` node — the instructions explicitly say purchases are relationships here, not nodes, unlike Part 1's table or Part 2's collection.

Relationships: `PURCHASED` (Customer→Product, required), `ALSO_BOUGHT` (Product→Product, required, both directions), `WORKS_IN` (Customer→Industry, standout), `SERVES` (Product→Industry, standout, both products), `SIMILAR_TO` (Product↔Product, standout, both directions).

## Exact property names (aligned to Part 2's MongoDB documents)

- **Customer**: `customer_id`, `first_name`, `last_name`, `email`, `phone`, `address`, `customer_industry` — matches `customer_1` exactly.
- **Product**: `product_id`, `product_name`, `product_intended_industry`, `price`, `stock_quantity`, `material`, `weight_in_pounds`, `dimensions`, `color`, (+`strength` on product 2 only) — matches `product_1`/`product_2` exactly, including that they deliberately have different attribute sets.
- **PURCHASED relationship**: `purchase_id`, `quantity`, `unit_price`, `total_price`, `purchase_date`, `status` — matches `purchase_1`/`purchase_2`'s fields, **except** `customer_id`/`product_id` are deliberately *not* repeated as relationship properties, since the relationship's own endpoints (which two nodes it connects) already express that — repeating them would be redundant, relational-style data, which the instructions explicitly warn against ("do not set up or configure the key relationships as node properties").

## How this was designed (methodology)

1. **Reused Part 2's entities, not new ones** — Part 3's own instructions explicitly invite this ("re-use sample data from the MongoDB section as needed"). Whatever Part 2 ends up being, Part 3 mirrors it exactly, including through Part 2's own revisions.
2. **Node types: Customer + Product (required) + Industry (the "≥1 more").** Picked `Industry` specifically because `customer_industry`/`product_intended_industry` were *already* fields on the Part 2 documents — promoting an existing property into its own node is the same hub-node pattern from Module 4 (Category/CustomerSegment hubs in the Neo4j exercise), not a new concept invented here.
3. **`PURCHASED` reused the real purchase records from Part 2** (`purchase_1`/`purchase_2`), not new numbers — same quantities/prices/dates.
4. **`ALSO_BOUGHT` confidence is genuinely computed, not looked up or fabricated.** With only 1 customer (Alice) who bought both products, confidence is 1.0 in *both* directions — 100% of the customers who bought product 1 also bought product 2, and vice versa, because there's only one buyer total. This is a real consequence of the small dataset, not an error — worth being able to explain if asked, since it looks suspiciously "too clean" without the reasoning behind it.
5. **`WORKS_IN`/`SERVES` exist so the industry query never needs a property filter.** Without them, "products in my industry" would require `WHERE p.product_intended_industry = c.customer_industry` — exactly the relational-style comparison the instructions warn against. With them, it's a pure two-hop traversal: Customer→Industry←Product.
6. **`SIMILAR_TO` is still hand-written even though it could now be derived via traversal.** Since both products share the same industry now (unlike the earlier 3-industry version), a same-industry traversal could technically compute "similar" automatically. Kept it as an explicit relationship anyway because `SIMILAR_TO` as its own relationship *type* is itself listed as standout work in the instructions, not just the query pattern that uses it.
7. **The required query traverses `PURCHASED` then `ALSO_BOUGHT`, deliberately, not `PURCHASED` twice.** Reusing the *precomputed* `ALSO_BOUGHT` edge is the actual point of storing it: compute the co-purchase stat once at data-build time, then every future recommendation query traverses one relationship instead of recomputing it live. Same payoff as index-free adjacency from Module 4 — expensive work happens once, not per query.
8. **Property names were audited field-by-field against the Part 2 documents**, not assumed — this caught a real mismatch (`date` vs. the MongoDB docs' `purchase_date`) and several missing Product attributes (`product_intended_industry`, `stock_quantity`, `weight_in_pounds`, `dimensions`, `color`, `strength`) that had been silently dropped in an earlier draft.

## Graph design questions (notebook answers)

**3. What properties did you add to relationships and why?**

`PURCHASED` carries `purchase_id`, `quantity`, `unit_price`, `total_price`, `purchase_date`, `status` — facts about that specific transaction, not about the customer or product in general. `unit_price`/`total_price` specifically snapshot the price *at the time of purchase*, since a catalog price could change later but a past order shouldn't retroactively change with it. Deliberately excludes `customer_id`/`product_id` as properties, since the relationship's own endpoints already express that — repeating it would be relational-style redundancy.

`ALSO_BOUGHT` carries `confidence`/`support_count` — not raw stored facts, but a calculated statistic derived by analyzing purchase patterns across customers (support_count = how many customers bought both; confidence = what fraction of one product's buyers also bought the other). Precomputed and stored so future recommendation queries traverse it directly instead of recalculating live.

`SIMILAR_TO` carries a `reason` property, documenting *why* two products are considered similar, so the judgment is explainable, not opaque.

`WORKS_IN`/`SERVES` carry no extra properties — simple categorical facts that don't need further detail beyond the connection existing.

**4. How would you handle graph growth as more customers and products are added?**

Query performance is proportional to traversal length (hop count), not total graph size — index-free adjacency means adding more customers/products doesn't slow down a query like "what did this customer buy," since each hop is a direct pointer-follow regardless of how much else exists in the graph.

That said, real scaling considerations:
- **Uniqueness constraints on IDs** — currently uses `CREATE`, which would make duplicate nodes if re-run; at scale, add `CREATE CONSTRAINT FOR (p:Product) REQUIRE p.product_id IS UNIQUE` and switch to `MERGE` for ingesting new data.
- **Indexes on lookup properties** — `MATCH (c:Customer {customer_id: 1})` needs to locate the starting node among potentially millions; index-free adjacency speeds up hops *after* that, but finding the starting node still benefits from a normal index, same as relational.
- **Recompute `ALSO_BOUGHT` as a periodic batch job**, not live — with thousands of purchases the confidence/support_count stats would go stale; re-run the co-purchase analysis on a schedule and update in bulk, rather than recalculating on every query.
- **Hub nodes (`Industry`) keep paying off at scale** — "all products in an industry" stays one hop away instead of a full property scan, and that advantage grows rather than shrinks as more customers/products get added.
