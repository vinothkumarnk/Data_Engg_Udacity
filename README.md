# Data Modeling for ACME

Udacity ND027 (Data Engineering with AWS) Course 1 capstone project — designing data models across ACME Corporation's stack.

The actual graded work is a single notebook ("ACME Data Modeling Project Starter") that must run inside the Udacity Workspace, against its pre-configured PostgreSQL/MongoDB/Neo4j containers — there's no local dev option. This repo is for backups and drafting, not for running the databases locally.

- **notebook/** — downloaded snapshots of the real `.ipynb` submission artifact, saved periodically for version history
- **part1_postgres/** — drafted DDL (`schema.sql`) and design notes for ACME Corp's legacy relational OLTP schema (wholesalers ordering gears)
- **part2_mongodb/** — drafted PyMongo queries and design notes for ACME 3D Printing's flexible/unstructured schema
- **part3_neo4j/** — drafted Cypher queries and design notes for ACME 3D Printing's product recommendation graph

Drafts in `part1/2/3` get pasted into the actual notebook cells in the Workspace once finalized — they're kept here as plain text so changes are easy to read and diff, unlike a whole notebook's JSON.
