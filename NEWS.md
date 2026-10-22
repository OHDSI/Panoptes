# Panoptes 0.1.0

- Added a validated, authoritative database-platform declaration.
- Added canonical DBMS selection and enabled/required semantics.
- Added normalized `HADES_*` environment resolution with explicit legacy
  aliases and redacted printing.
- Added DatabaseConnector adapters for SQLite, PostgreSQL, SQL Server, Oracle,
  Redshift, Spark, BigQuery, Snowflake, and IRIS.
- Added a stable `panoptes_database_test_context`, scoped temporary BigQuery key
  files and SqlRender options, and explicit live connection verification.
- Added collision-resistant object names and static workflow drift validation.
- Simplified live CI to one complete pull-request/manual matrix; Panoptes has no
  scheduled tier or matrix-derivation API. The prototype `ci` declaration field
  is rejected as unknown.
- Added package templates, JSON Schema, unit tests, vignettes, and migration
  documentation based on the CohortGenerator prototype.
