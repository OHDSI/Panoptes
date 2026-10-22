# Panoptes 0.1.0

- Added a validated, authoritative database-platform declaration.
- Added canonical DBMS selection and enabled/required/CI-tier semantics.
- Added normalized `HADES_*` environment resolution with explicit legacy
  aliases and redacted printing.
- Added DatabaseConnector adapters for SQLite, PostgreSQL, SQL Server, Oracle,
  Redshift, Spark, BigQuery, Snowflake, and IRIS.
- Added a stable `panoptes_database_test_context`, scoped temporary BigQuery key
  files and SqlRender options, and explicit live connection verification.
- Added collision-resistant object names, CI matrix derivation, and static
  workflow drift validation.
- Added package templates, JSON Schema, unit tests, vignettes, and migration
  documentation based on the CohortGenerator prototype.
