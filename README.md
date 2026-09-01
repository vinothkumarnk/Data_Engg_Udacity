# The Unified Commerce Challenge

Udacity ND027 (Data Engineering with AWS) Course 2 capstone project — building a centralized Amazon Redshift warehouse for a fictional fast-growing e-commerce company.

## Scenario

Critical data is spread across three systems:

- **PostgreSQL** — order management and payments
- **Cassandra** — real-time clickstream and user activity
- **Neo4j** — product recommendation graphs

The task: design a clean dimensional schema in Redshift and build an ETL/ELT pipeline that unifies these sources, handling schema drift, incremental updates, and error recovery — then optimize for speed and scalability (distribution keys, sort keys, compression, materialized views) while enforcing data quality with validation checks and metadata logging.

## What's new here vs. Modules 1-4

Most of the toolkit is already built from earlier modules (dimensional schema design, `COPY`, `INSERT...SELECT` with surrogate keys, DISTKEY/SORTKEY/compression, materialized views, row-count/referential-integrity validation). The genuinely new requirements this capstone adds:

- **Schema drift** — handling a source's schema changing over time
- **Incremental updates** — loading only new/changed rows since the last run, not full reloads
- **Error recovery** — explicit recovery procedures, beyond idempotent re-runs
- **Batch vs. near-real-time balance** — everything through Module 4 was pure batch
- **Metadata logging** — a durable record of pipeline runs, beyond ad-hoc validation prints

## Status

Just started — this repo currently holds only the scenario capture. Structure (notebook layout, per-source folders, etc.) will follow once the actual Udacity project workspace and rubric are available, rather than being guessed at up front.

See `Data_Warehouses_on_AWS/00-course-summary.html` (sibling folder, not tracked in this repo) for how this capstone fits into the full course.
