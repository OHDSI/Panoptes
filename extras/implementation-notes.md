# Panoptes implementation notes and maintainer questions

## Outcome

This repository is an R package named `Panoptes`, version 0.3.0. It provides
reusable database-testing infrastructure while leaving package-specific
fixtures, behavior, assertions, and database-object cleanup to each consumer.

The implementation treats the bundled configuration and workflow templates as
the source of truth for adoption. The public API is centered on validated
configuration, normalized environment variables, connection contexts,
temporary resources, compatibility checks, and workflow drift detection.

## Package rename

The package was initially implemented under the working name `Argus`. It was
renamed to `Panoptes` after discovering that `Argus` was already registered on
CRAN. The title is now **Panoptes — Database Platform Compatibility for
HADES**, named after Argus Panoptes, the many-eyed guardian of Greek mythology.

Because the package had not yet been released, the rename is complete rather
than compatibility-layered: package metadata and URLs, project and
documentation filenames, S3 classes, internal condition classes, test-injection
option keys, examples, templates, tests, and generated help all use `Panoptes`
or the `panoptes_` prefix. The phrase `Argus Panoptes` remains only where it
identifies the mythological namesake.

## Implemented contract

Panoptes provides:

- authoritative YAML configuration validation with unknown-field rejection;
- canonical names and input aliases for all ten supported DBMS platforms;
- one-DBMS-per-process selection through `HADES_TEST_DBMS`;
- enabled, required, runner, and operating-system policy;
- normalized `HADES_*` environment resolution with consumer-supplied aliases;
- local skip, optional-CI skip, and required-CI failure behavior;
- DatabaseConnector connection-details adapters without eager connections;
- the Snowflake `JDBC_QUERY_RESULT_FORMAT=JSON` workaround isolated in its
  adapter;
- temporary BigQuery key-file creation with restrictive permissions and
  deferred deletion;
- a stable, redacted `panoptes_database_test_context` S3 object;
- scoped `sqlRenderTempEmulationSchema` restoration;
- explicit connection verification and proof-of-attempt checks;
- portable collision-resistant object names;
- static workflow drift validation; and
- a JSON Schema, consumer configuration and workflow templates, tests,
  documentation, CI checks, coverage, and pkgdown setup.

## Design decisions

1. Environment validation happens before connection details, driver paths, or
   key files are created.
2. Panoptes never downloads JDBC drivers while constructing a context. Tests
   and CI provision them explicitly so context construction remains
   deterministic and network-free.
3. Explicit environment-variable alias maps accommodate naming exceptions
   while keeping them visible.
4. `runner`, `os`, and `githubEnvironment` are executable declaration fields.
5. BigQuery key input can be either an existing file path or JSON contents.
6. The vocabulary schema defaults to the CDM schema when not separately set.
7. `databaseConnection: all` means every adapter supported by Panoptes is
   declared. Packages supporting fewer platforms use `subset`.
8. Ordinary context creation is lazy with respect to a live connection.
   `verifyDatabaseTestConnection()` or `verify = TRUE` proves the attempt.
9. Panoptes cleans only resources it owns. Consumer database tables remain the
   responsibility of the behavior test.
10. Panoptes has no scheduled database-testing tier. Trigger policy belongs to
    the consumer workflow.

## Security and failure behavior

Print methods never print credential values, full connection strings, or
DatabaseConnector connection details. Missing-variable conditions contain only
normalized variable names. BigQuery temporary files are removed on normal or
error exit when `withDatabaseTestContext()` is used.

Required live CI is defined by both `HADES_DATABASE_TEST=true` and the selected
platform's `required: true`. Missing variables, an incompatible operating
system, or the absence of a connection attempt then fail. The same cases skip
locally or for an optional platform.

## Validation performed during implementation

- Every file in `R/` was parsed and the package loaded with
  `devtools::load_all()`.
- `devtools::test()` covers configuration, selection, environment policy,
  aliases, redaction, adapter arguments, connection-string workarounds,
  temporary key cleanup, option restoration, compatibility policy, connection
  attempts, unique names, and workflow drift.
- Package documentation is generated with roxygen2.
- `lintr::lint_package()` completed with no lints.
- The bundled JSON Schema parsed successfully and the full ten-platform
  consumer template passed the normative R validator.
- `R CMD build --no-manual --no-build-vignettes` and the corresponding
  `R CMD check` completed successfully. Prebuilt vignette output is included
  for environments that do not have Pandoc installed.

## Maintainer questions and review decisions

These do not block use of the package, because the implementation applies the
documented defaults, but they should be reviewed before the 0.3.0 release.

1. **Repository governance and URLs:** confirm `OHDSI/Panoptes` and the pkgdown
   URL.
2. **Additional consumers:** test with HADES packages having materially
   different database behavior before stabilizing the public API.
3. **testthat dependency:** Panoptes imports testthat for direct skip helpers,
   as recommended for 0.3.0. Revisit an optional adapter only if non-test uses
   emerge.
4. **`required` semantics:** the implementation treats it as global for the
   platform whenever explicit live CI is active.
5. **BigQuery compatibility:** the template currently restricts BigQuery to a
   Windows runner. Confirm whether current DatabaseConnector and driver
   versions support other runners before retaining this restriction long-term.
6. **Local contexts:** Panoptes treats SQLite and DuckDB as declared local
   platforms and expects `HADES_DB_SERVER`, CDM schema, and work schema if one
   is explicitly selected. Normal package tests may continue to construct
   their own local fixture without Panoptes.
7. **Reusable workflow publication:** the package includes an auditable caller
   workflow template and drift validator. Decide whether OHDSI also wants a
   centrally versioned reusable workflow after repository hosting is available.
8. **Snowflake workaround:** establish upstream version and removal criteria for
   `JDBC_QUERY_RESULT_FORMAT=JSON`.
9. **Fork pull-request policy:** protected secrets are unavailable to forks.
   Use manual dispatch, a protected maintainer branch, or another trusted
   execution policy; never expose secrets to untrusted code.
10. **Workflow policy:** Panoptes intentionally uses one complete live-database
    matrix and does not model trigger tiers or scheduled execution.
