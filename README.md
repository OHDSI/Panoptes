# Panoptes — Database Platform Compatibility for HADES

Named after Argus Panoptes, the many-eyed guardian of Greek mythology, Panoptes
helps HADES package maintainers explicitly declare and verify support for
database platforms. Just as its mythological namesake maintained watch through
many eyes, Panoptes provides a consistent view of database compatibility across
the HADES ecosystem.

Panoptes establishes a standardized mechanism for declaring supported DBMS
platforms and provides reusable testing utilities to help maintainers validate
those declarations. By making database support explicit and testable, Panoptes
improves transparency, consistency, and confidence in the cross-platform
behavior of HADES packages.

It provides test infrastructure for HADES packages that exercise their own
behavior against live database platforms. It gives consuming packages one
contract for declaring supported DBMSs, selecting one DBMS per R process,
resolving credentials and schemas, constructing a consistent
`DatabaseConnector` context, and keeping CI matrices aligned with the package
declaration.

Panoptes does not define a package's behavioral assertions, create an OMOP CDM,
provision database servers, or manage secrets. Those responsibilities remain
with the consuming package and its CI environment.

## Why Panoptes exists

The first implementation was prototyped in CohortGenerator. It proved that a
single behavior test can run against PostgreSQL, SQL Server, Oracle, Redshift,
Spark, BigQuery, Snowflake, and IRIS while SQLite remains available for normal
package tests. It also revealed infrastructure that should not be copied into
each HADES package: declaration validation, strict CI behavior, platform
adapters, temporary credentials, scoped options, and matrix drift checks.

Panoptes extracts that reusable layer and fixes the prototype's known ordering and
policy gaps. In particular, environment validation happens before connection
construction, required and optional CI jobs behave differently, BigQuery's
runner is explicit, and connection attempts can be asserted.

## Installation

During development, install Panoptes from its repository:

```r
remotes::install_github("OHDSI/Panoptes")
```

Consuming packages should list Panoptes under `Suggests` because it is used only
by tests.

## Quick start

### 1. Declare supported platforms

Copy the bundled template to the consuming package:

```r
template <- system.file(
  "templates",
  "hades-database-platforms.yml",
  package = "Panoptes"
)
dir.create("inst/test-config", recursive = TRUE, showWarnings = FALSE)
file.copy(
  template,
  "inst/test-config/hades-database-platforms.yml"
)
```

Change `package`, choose `databaseConnection: subset` if the package does not
support every Panoptes adapter, and remove unwanted platform entries. Each field
is validated; unknown fields fail rather than becoming ignored documentation.

### 2. Write one package-owned behavior test

```r
testthat::test_that("cohort generation works on the selected DBMS", {
  config <- Panoptes::readDatabaseTestConfig(package = "MyHadesPackage")
  Panoptes::skipIfNoLiveDatabase(config)

  Panoptes::withDatabaseTestContext(
    config,
    verify = TRUE,
    {
      connection <- DatabaseConnector::connect(context$connectionDetails)
      on.exit(DatabaseConnector::disconnect(connection), add = TRUE)

      tableName <- paste0(context$objectPrefix, "_cohort")
      on.exit({
        # Delete package-owned test objects here.
      }, add = TRUE)

      # Arrange package-specific fixtures, run package behavior, and assert.
      testthat::expect_true(nzchar(context$cdmDatabaseSchema))
      Panoptes::requireDatabaseTestConnectionAttempted(context)
    }
  )
})
```

The expression passed to `withDatabaseTestContext()` can refer to `context`.
Panoptes restores the `sqlRenderTempEmulationSchema` option and deletes any
temporary key file on success or failure. It deliberately does not remove
consumer-owned database objects.

### 3. Provide normalized environment variables

Panoptes uses this process-level contract:

| Variable | Meaning |
|---|---|
| `HADES_TEST_DBMS` | One selected DBMS, such as `postgresql` |
| `HADES_DATABASE_TEST` | Explicit live CI intent (`true` or `false`) |
| `HADES_DB_USER` | Database user when password credentials are used |
| `HADES_DB_PASSWORD` | Database password; URL-encoded values are decoded |
| `HADES_DB_SERVER` | Server or SQLite database path |
| `HADES_DB_CONNECTION_STRING` | JDBC connection string when declared |
| `HADES_DB_KEY_FILE` | Existing key-file path or temporary key-file contents |
| `HADES_CDM_SCHEMA` | OMOP CDM schema |
| `HADES_VOCABULARY_SCHEMA` | Vocabulary schema; defaults to the CDM schema |
| `HADES_WORK_SCHEMA` | Writable schema owned by the test environment |
| `HADES_CDM_VERSION` | Optional override of the declared CDM version |

Existing package-era variables can be used through an explicit alias map:

```r
legacyAliases <- c(
  HADES_DB_USER = "CDM5_POSTGRESQL_USER",
  HADES_DB_PASSWORD = "CDM5_POSTGRESQL_PASSWORD",
  HADES_DB_SERVER = "CDM5_POSTGRESQL_SERVER",
  HADES_CDM_SCHEMA = "CDM5_POSTGRESQL_CDM_SCHEMA",
  HADES_WORK_SCHEMA = "CDM5_POSTGRESQL_OHDSI_SCHEMA"
)

Panoptes::withDatabaseTestContext(
  config,
  legacyAliases = legacyAliases,
  { context$dbms }
)
```

Normalized variables always take precedence. Error messages and print methods
show names and set/unset state, never credential values or complete connection
strings.

### 4. Keep CI aligned with the declaration

Derive the expected rows for a tier:

```r
Panoptes::getDatabaseTestMatrix(config, ci = "pull-request")
Panoptes::getDatabaseTestMatrix(config, ci = "scheduled")
```

For an auditable static caller matrix, add a unit test:

```r
testthat::expect_true(
  Panoptes::validateDatabaseTestWorkflow(
    config,
    ".github/workflows/database-platform-tests.yml",
    ci = "pull-request"
  )
)
```

The bundled `inst/templates/database-platform-tests.yml` shows the boundary:
the caller chooses triggers and maps GitHub secrets to normalized variables;
Panoptes validates DBMS, runner, and GitHub environment rows.

## Missing environment policy

| Execution mode | Platform policy | Missing required values |
|---|---|---|
| Local development | required or optional | Skip with missing variable names |
| Explicit live CI | optional | Skip |
| Explicit live CI | required | Fail before connection construction |

Ordinary package checks should not receive live credentials. Put
`Panoptes::skipIfLiveDatabaseTest()` at the start of ordinary test files only when
the live workflow intentionally focuses `R CMD check` on the live behavior
test.

## More documentation

- `vignette("using-panoptes", package = "Panoptes")` gives a full consumer workflow.
- `vignette("migrating-to-panoptes", package = "Panoptes")` maps the CohortGenerator
  prototype helpers to Panoptes.
- `extras/implementation-notes.md` records implementation decisions, known
  constraints, and maintainer questions from the extraction.

## Scope

Panoptes 0.1.0 supports declaration and selection, normalized environment
resolution, the nine prototype platform adapters, a stable S3 context, scoped
resources, connection-attempt verification, unique object names, and CI matrix
validation. Database/CDM provisioning, package behavior, organization secrets,
performance certification, and automatic cleanup of package-owned objects are
out of scope.
