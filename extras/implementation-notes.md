# Panoptes implementation notes and maintainer questions

## Outcome

This repository is now an R package named `Panoptes`, version 0.1.0. The
implementation extracts the reusable database-test infrastructure from the
local CohortGenerator `update-database-testing-approach` branch while keeping
CohortGenerator-specific fixtures, behavior, assertions, and object cleanup out
of Panoptes.

The source material reviewed was:

- `extras/HADES_multi_database_testing_package_handoff.md`;
- `extras/CohortGenerator_multi_database_testing_proposal.md`;
- `C:/git/ohdsi/CohortGenerator/inst/test-config/hades-database-platforms.yml`;
- `tests/testthat/helper-database-platforms.R`, `helper.R`, `setup.R`,
  `test-database-platforms.R`, and `test-dbms-platforms.R`; and
- `.github/workflows/database-platform-tests.yml`.

The prototype was treated as discovery code. Generic functions were redesigned
around the handoff's validation and lifecycle requirements rather than copied
verbatim.

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
- canonical names and input aliases for all nine prototype DBMS platforms;
- one-DBMS-per-process selection through `HADES_TEST_DBMS`;
- enabled, required, CI-tier, runner, and operating-system policy;
- normalized `HADES_*` environment resolution with consumer-supplied aliases;
- local skip, optional-CI skip, and required-CI failure behavior;
- DatabaseConnector connection-details adapters without eager connections;
- Spark `EnableArrow=0` and Snowflake `JDBC_QUERY_RESULT_FORMAT=JSON`
  workarounds isolated in their adapters;
- temporary BigQuery key-file creation with restrictive permissions and
  deferred deletion;
- a stable, redacted `panoptes_database_test_context` S3 object;
- scoped `sqlRenderTempEmulationSchema` restoration;
- explicit connection verification and proof-of-attempt checks;
- portable collision-resistant object names;
- CI matrix derivation and static workflow drift validation;
- a JSON Schema, consumer configuration/workflow templates, tests, README,
  vignettes, CI checks, coverage, and pkgdown setup.

## Deliberate differences from CohortGenerator

1. Environment validation happens before connection details, driver paths, or
   key files are created.
2. Panoptes never downloads JDBC drivers. Tests and CI should provision them in
   setup; context construction remains deterministic and network-free.
3. `environmentPrefix` is rejected. It could not express existing naming
   exceptions. Explicit alias maps make migration behavior visible.
4. `runner`, `os`, and `githubEnvironment` are executable declaration fields.
5. BigQuery key input can be either an existing file path or JSON contents.
6. The vocabulary schema defaults to the CDM schema when not separately set.
7. `databaseConnection: all` means that every adapter supported by Panoptes is
   declared. Packages supporting fewer platforms use `subset`.
8. Ordinary context creation is lazy with respect to a live connection.
   `verifyDatabaseTestConnection()` or `verify = TRUE` proves the attempt.
9. Panoptes cleans only resources it owns. Consumer database tables remain the
   responsibility of the behavior test.

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

- Every file in `R/` was parsed and the package loaded with `devtools::load_all`.
- `devtools::test()` covers configuration, selection, environment policy,
  aliases, redaction, adapter arguments, connection-string workarounds,
  temporary key cleanup, option restoration, compatibility policy, connection
  attempts, unique names, CI matrices, and workflow drift.
- Package documentation is generated with roxygen2.
- `devtools::test()` completed with all tests passing and no live credentials.
- `lintr::lint_package()` completed with no lints.
- The bundled JSON Schema parsed successfully and the full nine-platform
  consumer template passed the normative R validator.
- `R CMD build --no-manual --no-build-vignettes` completed successfully.
- `R CMD check --no-manual --no-build-vignettes` completed with `Status: OK`.
  Prebuilt vignette HTML/tangle outputs are included because Pandoc is not
  installed in the local execution environment. CI installs Pandoc and can
  rebuild the source vignettes normally.
- An `--as-cran` incoming-feasibility attempt could not query CRAN or
  Bioconductor because outbound repository access is unavailable in the local
  sandbox. The subsequent complete offline package check was clean.

## Maintainer questions and review decisions

These do not block use of the package, because the implementation applies the
documented defaults, but they should be reviewed before a public 0.1.0 tag.

1. **Repository governance and URLs:** confirm `OHDSI/Panoptes` and the pkgdown URL.
2. **Second pilot package:** choose a HADES package materially different from
   CohortGenerator before stabilizing the public API.
3. **testthat dependency:** Panoptes imports testthat for direct skip helpers, as
   recommended for 0.1.0. Revisit an optional adapter only if non-test uses
   emerge.
4. **`required` semantics:** the implementation treats it as global for the
   platform's selected tier. If a platform needs different required policy per
   tier, the schema will need a tier-specific structure.
5. **BigQuery compatibility:** the template preserves the prototype's Windows
   restriction. Confirm whether current DatabaseConnector/driver versions now
   support other runners before retaining it long-term.
6. **SQLite context:** Panoptes treats SQLite as a declared local platform and
   expects `HADES_DB_SERVER`, CDM schema, and work schema if explicitly selected.
   Normal package tests may continue to construct their own Eunomia fixture
   without Panoptes.
7. **Reusable workflow publication:** the package includes an auditable caller
   workflow template and drift validator. Decide whether OHDSI also wants a
   centrally versioned reusable workflow after repository hosting is available.
8. **Spark and Snowflake workarounds:** establish upstream version/removal
   criteria for `EnableArrow=0` and `JDBC_QUERY_RESULT_FORMAT=JSON`.
9. **Fork pull-request policy:** protected secrets are unavailable to forks.
   Choose manual dispatch, a protected maintainer branch, or another trusted
   execution policy; do not expose secrets to untrusted code.
10. **Workflow tiers:** the schema assigns one tier per platform. Confirm whether
    a future platform must run in multiple tiers; if so, make `ci` an array in a
    later schema version.

## Suggested CohortGenerator migration sequence

The detailed file-by-file plan, replacement configuration, test refactor, CI
design, and acceptance criteria are in
[CohortGenerator Panoptes Migration Handoff](CohortGenerator_Panoptes_migration_handoff.md).

1. Add Panoptes to `Suggests` at a pinned release or commit.
2. Update the consumer YAML to Panoptes schema fields and remove
   `environmentPrefix`.
3. Map current workflow secrets to normalized `HADES_*` names, or temporarily
   pass explicit aliases.
4. Replace generic copied helpers with `readDatabaseTestConfig()` and
   `withDatabaseTestContext()`.
5. Keep `test-dbms-platforms.R` behavior and table cleanup in CohortGenerator.
6. Split pull-request and scheduled matrices, and put BigQuery on its declared
   runner.
7. Add static matrix validation tests.
8. Run live PostgreSQL first, then add adapters individually.
9. Remove copied helper tests only after equivalent Panoptes and consumer
   integration tests pass.

## CohortGenerator pilot update

The CohortGenerator consumer migration is now implemented locally on its
`update-database-testing-approach` branch. During the pilot,
`readDatabaseTestConfig(package = "CohortGenerator")` exposed a source-root
discovery bug: `read.dcf()` retains the `Package` field name, causing
`identical()` to reject an otherwise equal package name. `findPackageRoot()`
now removes that field name before comparison, and a nested source-package
regression test covers the documented discovery behavior.

The Panoptes test suite passes after this correction. The consumer migration's
decisions and remaining repository-configuration questions are recorded in
`extras/Panoptes_migration_implementation_notes.md` in CohortGenerator.
