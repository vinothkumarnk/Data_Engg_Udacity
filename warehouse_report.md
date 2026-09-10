# Data Warehouse Build Report

Generated: 2026-09-09T22:14:30.447211Z

## Schema Overview

### Staging Tables

- `stg_orders_raw`: 2,500 rows
- `stg_events_raw`: 2,500 rows
- `stg_edges_raw`: 2,500 rows

### Fact Tables

- `dw_fact_orders`: 2,500 rows
- `dw_fact_events`: 2,500 rows
- `dw_fact_graph_edges`: 2,500 rows

### Dimension Tables

- `dw_dim_referrer`: 6 rows
- `dw_dim_os`: 5 rows
- `dw_dim_shipping_method`: 3 rows
- `dw_dim_device`: 3 rows
- `dw_dim_browser`: 5 rows
- `dw_dim_ab_variant`: 2 rows
- `dw_dim_customer`: 4,849 rows
- `dw_dim_channel`: 5 rows
- `dw_dim_date`: 552 rows
- `dw_dim_campaign`: 7 rows
- `dw_dim_product`: 3,107 rows
- `dw_dim_payment_method`: 5 rows

## Design Rationale


### 1. Why star schema?

Three unrelated source systems each describe a different kind of occurence:

- orders (PostgreSQL) - one row is one order, like customer C55 buying 3 items on a ceratin date for certain amount
- events (Cassandra) - one row is one click or action, like customer C55 viewing a product page
- edges (Neo4J) - one row is one relationship, like customer C55 having PURCHASED product

These are genuinely differnt shapes of data, so a star scehma keeps each one in its own fact table (fact_orders,
fact_events, fact_graph_edges) instead of forcing them into a single table with mostly empty columns depdending 
on which kind of row it is.

Shared context lives once in a dimension table and gets refrenced from every fact table that needs it:

dim_customer holds one row for customer c55, and all three fact tables point back to that same row through customer_sk
instead of each fact table keeping its own copy.

dim_date holds one row per calendar day, referenceed by order date, ship date, event date, edge date across all 
three fact tables intead of three separate calendars



### 2. Distribution key choices


Customer-centric facts use DISTKEY(customer_sk)

- fact_orders and fact_events both use DISTKEY(customer_sk)
- Example: customer C55 (customer_sk = 205) - every order row and every event rrow for C55 lands on the same physical
node, since they all share that same customer_sk value
- Result: fact_orders and fact_events colocate with each other, and a query like "total spend per customer" grop by
customer_sk is fast, since one customer's rows area already sitting together


Product-centric fact uses DISTKEY(to_product_sk)

- fact_graph_edges uses DISTKEY(to_product_sk) instead, since its main analytical angle is product relationships, not customers
- Same applies — dim_product's own DISTKEY is product_id, not product_sk

The 9 small dimensions use DISTSTYLE ALL

- Example: dim_channel has only 5 rows — copying all 5 rows to every single node costs almost nothing
- That means joining any fact table to dim_channel never needs a shuffle, since the whole table is already sitting locally on every node


### 3. Sort key choices

Every fact table is sorted by its date key

- fact_orders - sorted by order_date_key
- fact_events - sorted by event_date_key
- fact_graph_edges - sorted by event_date_key

Why date specifically, and not some other column — this warehouse is built for time-based analytics 
(daily revenue, monthly trends, this quarter vs last quarter), so the date key is the column almost every real 
query is going to filter or group by. Sorting by the column your queries actually use is the whole point
— sorting by, say, channel instead wouldn't help a "revenue this month" query at all.

### 4. Materialized view purpose

- dw_mv_daily_revenue takes fact_orders (2500 rows) and pre-computes, per day: how many orders, total revenue,
average order value
- Result: instead of 2500 individual order rows, we get one row per distinct day (roughly 552 rows, matching dim_date's count)
 each row already holding the answer

Regular view vs. materialized view:

- A regular VIEW is just a saved query — every time you SELECT from it, Redshift re-runs the whole aggregation 
from scratch, scanning all 2500 rows again
- A materialized view actually stores the computed result physically. Reading from it means reading pre-computed 
numbers, not recalculating them

Example:

- Someone asks "what was revenue on June 12, 2024?"
- Without the materialized view: Redshift scans all 2500 fact_orders rows, filters to June 12, 
sums them up — every single time this question gets asked
- With the materialized view: Redshift just reads the one row for June 12 that's already sitting there with 
the answer computed — no scanning, no summing


## Analytics Capabilities


- Revenue/order-volume by day/week/month/quarter — via dim_date

- Customer-level analysis — via dim_customer, joined across fact_orders and fact_events

- Product-level analysis — via dim_product, joined across fact_events and fact_graph_edges

- Channel/device/browser/campaign breakdowns — for marketing/UX

- Graph-relationship analysis — via fact_graph_edges

- Pre-aggregated daily revenue — via dw_mv_daily_revenue


