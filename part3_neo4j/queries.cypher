// Part 3: ACME graph schema and recommendation queries
// Drafted Cypher, mirrored into the actual Udacity notebook once finalized.
// Reuses the same sample entities as Part 2 (MongoDB) for consistency, per the
// instructions' own suggestion ("re-use sample data from the MongoDB section").
//
// REVISION 3 (2026-08-19) — POST-REVIEW FIX. First submission failed this
// section for a real reason, not a design flaw: every CREATE query string
// (create_customer_nodes_query, create_product_nodes_query,
// create_purchased_query, create_purchased_query_2, create_also_bought_query)
// was defined but NEVER passed to neo4j_conn.execute_query(...) — defining a
// Python string doesn't send anything to the database, only execute_query()
// does. The graph was wiped (MATCH (n) DETACH DELETE n) and never
// repopulated, hence every "label/relationship type does not exist" warning
// downstream. Also fixed: a stray extra closing brace in
// create_product_nodes_query ("strength": "strong"}}) -> }) ), and a missing
// 3rd node type (Industry) + its relationship (WORKS_IN), both now added and
// actually executed.
//
// SCOPE NOTE: this revision deliberately trims to the MINIMUM required fix
// per the reviewer's exact ask — Customer/Product/Industry nodes,
// PURCHASED x2/ALSO_BOUGHT/WORKS_IN relationships. The earlier fuller design
// (SERVES, SIMILAR_TO relationships, Cells 4-5 standout queries) is NOT part
// of this fix and was intentionally left out this round — see git history /
// earlier revision comments in this file for that fuller version if it's
// wanted back later.

// ============================================================
// Cell 1 — Node Types
// ============================================================

CREATE (c1:Customer {customer_id: 1, first_name: "Alice", last_name: "Wonderland", email: "alice@wonderland.fake", phone: "555-0101", address: "1 Rabbit Hole Lane", customer_industry: "industrial manufacturing"})

CREATE (p1:Product {product_id: 1, product_name: "A Large Gear", product_intended_industry: "industrial manufacturing", price: 450.0, stock_quantity: 120, material: "A steel", weight_in_pounds: 100.0, dimensions: "10x10x10", color: "black"})
CREATE (p2:Product {product_id: 2, product_name: "B Large Gear", product_intended_industry: "industrial manufacturing", price: 450.0, stock_quantity: 120, material: "B steel", weight_in_pounds: 200.0, dimensions: "20x20x20", color: "white", strength: "strong"})

CREATE (i1:Industry {name: "industrial manufacturing"})

// ============================================================
// Cell 2 — Relationships
// ============================================================

MATCH (c:Customer {customer_id: 1}), (p:Product {product_id: 1})
CREATE (c)-[:PURCHASED {purchase_id: 1, quantity: 2, unit_price: 450.0, total_price: 900.0, purchase_date: "2026-08-19", status: "completed"}]->(p)

MATCH (c:Customer {customer_id: 1}), (p:Product {product_id: 2})
CREATE (c)-[:PURCHASED {purchase_id: 2, quantity: 2, unit_price: 450.0, total_price: 900.0, purchase_date: "2026-08-19", status: "completed"}]->(p)

MATCH (p1:Product {product_id: 1}), (p2:Product {product_id: 2})
CREATE (p1)-[:ALSO_BOUGHT {confidence: 1.0, support_count: 1}]->(p2)
CREATE (p2)-[:ALSO_BOUGHT {confidence: 1.0, support_count: 1}]->(p1)

MATCH (c:Customer {customer_id: 1}), (i:Industry {name: "industrial manufacturing"})
CREATE (c)-[:WORKS_IN]->(i)

// ============================================================
// Sanity check — added per reviewer's suggested habit, run right after
// Cell 1/2 to confirm the CREATE statements actually landed before moving
// on to the recommendation query.
// ============================================================

MATCH (n) RETURN labels(n) AS node_type, count(*) AS count

// ============================================================
// Cell 3 — Customers who bought X also bought Y (Required)
// ============================================================

MATCH (c:Customer)-[:PURCHASED]->(x:Product {product_id: 1})
MATCH (x)-[:ALSO_BOUGHT]->(y:Product)
RETURN DISTINCT c.first_name AS customer, x.product_name AS bought, y.product_name AS also_bought
