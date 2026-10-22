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

Add `Panoptes (>= 0.1.0)` to the consuming package's `Suggests`, then copy and
customize the declaration template:

```r
dir.create("inst/test-config", recursive = TRUE, showWarnings = FALSE)
file.copy(
  system.file(
    "templates",
    "hades-database-platforms.yml",
    package = "Panoptes"
  ),
  "inst/test-config/hades-database-platforms.yml"
)
```

Write one database-neutral behavior test. The consumer supplies the behavior,
assertions, and cleanup; Panoptes supplies the selected context and verifies the
connection:

```r
testthat::test_that("package behavior works on the selected DBMS", {
  config <- Panoptes::readDatabaseTestConfig(package = "MyHadesPackage")
  Panoptes::skipIfNoLiveDatabase(config)

  Panoptes::withDatabaseTestContext(config, verify = TRUE, {
    on.exit({
      # Delete package-owned test objects here.
    }, add = TRUE)

    # Run package-specific behavior using context and assert its result.
    testthat::expect_true(nzchar(context$cdmDatabaseSchema))
    Panoptes::requireDatabaseTestConnectionAttempted(context)
  })
})
```

Copy the bundled workflow, configure one protected GitHub environment per
external DBMS, and keep its static matrix aligned with the declaration. The
complete dependency, configuration, local-development, secrets, CI, rollout,
and troubleshooting procedure is in
`vignette("using-panoptes", package = "Panoptes")`.

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

- `vignette("using-panoptes", package = "Panoptes")` gives the complete
  step-by-step maintainer adoption guide.
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
