# Using Panoptes in a HADES package

This guide takes a HADES package maintainer from an ordinary package
test suite to one package-owned behavior test that runs against every
database platform the package declares. The examples use a fictional
package named `MyHadesPackage`, begin with PostgreSQL, and then expand
to the complete live database matrix.

## 1. Understand the ownership boundary

Panoptes owns reusable test infrastructure:

- locating and validating the platform declaration;
- selecting one DBMS per R process;
- resolving normalized environment variables;
- constructing `DatabaseConnector` connection details;
- checking runner and operating-system compatibility;
- managing temporary credentials and scoped SqlRender options;
- generating collision-resistant database object names;
- proving that a live connection was attempted; and
- detecting drift between the declaration and the CI matrix.

The consuming package continues to own:

- the list of databases it supports;
- access to existing database servers and OMOP CDMs;
- package-specific fixtures, behavior, and assertions;
- database objects created by the test and their cleanup; and
- GitHub environments, secrets, approvals, and trusted-run policy.

Panoptes does not provision a database or CDM and does not certify
support by opening a connection alone. A green job must exercise
meaningful package behavior and assert its result.

## 2. Add Panoptes as a test dependency

Add Panoptes to `Suggests` in the consuming package’s `DESCRIPTION`:

``` text
Suggests:
    Panoptes (>= 0.2.0),
    testthat (>= 3.0.0)
```

Panoptes belongs in `Suggests`, not `Imports`, because the package uses
it only from tests and CI. This guide assumes Panoptes is available from
its released repository, so consumers do not need a development
`Remotes` entry.

## 3. Declare the supported platforms

Create the configuration directory and copy Panoptes’s installed
template:

``` r

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

For a PostgreSQL-first adoption, reduce the copied file to a declaration
like this:

``` yaml
schemaVersion: 1
package: MyHadesPackage
databaseConnection: subset
platforms:
  - dbms: postgresql
    enabled: true
    required: true
    cdmVersion: "5.4"
    connectionMode: server
    credentialMode: password
    tempEmulationSchema: false
    runner: ubuntu-latest
    os: any
    githubEnvironment: test-postgresql
```

The declaration is executable policy rather than a place to store
secrets:

| Field | Meaning |
|----|----|
| `databaseConnection` | `none`, `subset`, or `all`; `all` requires entries for every Panoptes adapter |
| `enabled` | Whether the package currently claims and tests support for the platform |
| `required` | Whether incomplete or incompatible explicit live CI must fail instead of skip |
| `cdmVersion` | Default OMOP CDM version for the behavior test |
| `connectionMode` | `local`, `server`, or `connectionString` |
| `credentialMode` | `none`, `password`, or `keyFile` |
| `tempEmulationSchema` | Whether Panoptes scopes SqlRender temporary-table emulation to the work schema |
| `runner` | GitHub Actions runner used by the platform’s matrix row |
| `os` | `any`, `linux`, `windows`, or `macos` compatibility requirement |
| `githubEnvironment` | Protected GitHub environment supplying that row’s secrets |

Use `databaseConnection: subset` and retain only platforms the package
supports. Use `databaseConnection: all` only when all ten adapter
entries remain in the file. A disabled entry must set `required: false`
and provide a non-empty `reason`.

SQLite and DuckDB are local file-based platforms. Their entries must use
`connectionMode: local` and `credentialMode: none`; `HADES_DB_SERVER` is
the path to the database file. A consumer that runs DuckDB tests should
also list the `duckdb` R package in `Suggests`. Neither local platform
needs a JDBC driver.

Never put users, passwords, servers, connection strings, key contents,
or schema values in this file. It is committed to source control.

Validate the declaration before writing the behavior test:

``` r

config <- Panoptes::readDatabaseTestConfig(
  path = "inst/test-config/hades-database-platforms.yml"
)
Panoptes::validateDatabaseTestConfig(config, package = "MyHadesPackage")
```

Unknown fields, duplicate DBMS entries, invalid field combinations, and
missing required fields fail immediately.

## 4. Add a consumer integration test

Add `tests/testthat/test-panoptes-integration.R`. This test proves that
Panoptes can discover the installed declaration and that the consumer
declares the intended platforms:

``` r

Panoptes::skipIfLiveDatabaseTest()

testthat::test_that("Panoptes finds the package declaration", {
  config <- Panoptes::readDatabaseTestConfig(package = "MyHadesPackage")

  testthat::expect_equal(config$package, "MyHadesPackage")
  testthat::expect_equal(config$databaseConnection, "subset")
  testthat::expect_equal(
    vapply(config$platforms, `[[`, character(1), "dbms"),
    "postgresql"
  )
})
```

Do not copy Panoptes’s configuration, adapter, environment, or lifecycle
unit tests into the consumer. The consumer integration test covers the
boundary; Panoptes’s own suite covers the generic implementation.

## 5. Write one package-owned behavior test

Add a focused file such as `tests/testthat/test-database-platform.R`.
The same test body should run for every selected DBMS. Keep DBMS
branches out of the assertions; platform-specific connection behavior
belongs in Panoptes.

``` r

testthat::test_that("package behavior works on the selected database", {
  testthat::skip_on_cran()

  config <- Panoptes::readDatabaseTestConfig(package = "MyHadesPackage")
  Panoptes::skipIfNoLiveDatabase(config)

  Panoptes::withDatabaseTestContext(config, verify = TRUE, {
    resultTable <- context$objectPrefix

    on.exit(
      MyHadesPackage::dropTestResults(
        connectionDetails = context$connectionDetails,
        workDatabaseSchema = context$workDatabaseSchema,
        resultTable = resultTable
      ),
      add = TRUE
    )

    result <- MyHadesPackage::runDatabaseBehavior(
      connectionDetails = context$connectionDetails,
      cdmDatabaseSchema = context$cdmDatabaseSchema,
      vocabularyDatabaseSchema = context$vocabularyDatabaseSchema,
      workDatabaseSchema = context$workDatabaseSchema,
      resultTable = resultTable
    )

    testthat::expect_true(result$succeeded)
    testthat::expect_gt(result$rowCount, 0)
    Panoptes::requireDatabaseTestConnectionAttempted(context)
  })
})
```

Replace the fictional `runDatabaseBehavior()` and `dropTestResults()`
calls with the package’s real behavior and idempotent cleanup. Register
cleanup before the behavior begins, and make it tolerate a partially
created object. Use `context$objectPrefix` directly as an object name;
Panoptes has already bounded it for DBMS identifier limits.

`verify = TRUE` opens and closes a connection before evaluating the test
body. That proves reachability but does not replace the package
assertions.
[`requireDatabaseTestConnectionAttempted()`](https://ohdsi.github.io/Panoptes/reference/requireDatabaseTestConnectionAttempted.md)
prevents a required CI path from finishing green after an early return
that never attempted a connection.

The context exposes these consumer-facing fields:

| Field | Consumer use |
|----|----|
| `dbms` | Canonical selected DBMS name |
| `connectionDetails` | Redacted-on-print `DatabaseConnector` connection details |
| `cdmDatabaseSchema` | OMOP CDM schema |
| `vocabularyDatabaseSchema` | Vocabulary schema, defaulting to the CDM schema |
| `workDatabaseSchema` | Writable schema for package-owned test objects |
| `cdmVersion` | Environment override or declared CDM version |
| `tempEmulationSchema` | Work schema when temporary-table emulation is enabled, otherwise `NULL` |
| `objectPrefix` | Collision-resistant, DBMS-bounded object name |
| `platform` | Validated declaration entry for the selected DBMS |

Panoptes removes temporary BigQuery key files and restores scoped
options when
[`withDatabaseTestContext()`](https://ohdsi.github.io/Panoptes/reference/withDatabaseTestContext.md)
exits, including after an error. It never deletes objects created by the
consumer test.

### Optional focused live-test mode

The bundled workflow runs `R CMD check` with `HADES_DATABASE_TEST=true`.
If the consumer wants that check to focus exclusively on the live
behavior test, put this at the beginning of ordinary test files:

``` r

Panoptes::skipIfLiveDatabaseTest()
```

Do not add the guard to the live behavior test. This focusing mechanism
is optional; omit it if the live job should also run the ordinary suite.

## 6. Run PostgreSQL locally

Download the matching JDBC driver explicitly. Panoptes constructs
connection details but intentionally performs no network downloads:

``` powershell
$env:DATABASECONNECTOR_JAR_FOLDER = "$env:USERPROFILE\.jdbcDrivers"
```

``` r

driverFolder <- Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
dir.create(driverFolder, recursive = TRUE, showWarnings = FALSE)
DatabaseConnector::downloadJdbcDrivers(
  dbms = "postgresql",
  pathToDriver = driverFolder
)
```

Set the normalized environment in the same PowerShell process:

``` powershell
$env:HADES_TEST_DBMS = "postgresql"
$env:HADES_DATABASE_TEST = "false"
$env:HADES_DB_USER = "..."
$env:HADES_DB_PASSWORD = "..."
$env:HADES_DB_SERVER = "server/database"
$env:HADES_CDM_SCHEMA = "cdm"
$env:HADES_WORK_SCHEMA = "scratch"
Rscript -e 'devtools::test(filter = "database-platform", reporter = "summary")'
```

`HADES_DATABASE_TEST=false` gives local-development behavior: missing
values or an incompatible OS produce a test skip rather than a
required-CI failure. A disabled or undeclared selection is a
configuration error, and a real connection or behavior failure still
fails the test.

`HADES_VOCABULARY_SCHEMA` defaults to `HADES_CDM_SCHEMA`, and
`HADES_CDM_VERSION` defaults to the declared `cdmVersion`. Set either
variable only when the environment differs. Panoptes print methods show
variable names and set/unset status, never credential values or complete
connection strings.

For a local DuckDB run, install the `duckdb` R package, select `duckdb`,
and set `HADES_DB_SERVER` to an existing DuckDB file containing the test
CDM. Keep the schema variables shown above, but omit the user, password,
JDBC-folder, and driver-download steps. Panoptes opens the file through
DatabaseConnector; it does not create or populate the CDM.

## 7. Provision GitHub environments and secrets

Create one protected GitHub environment for each enabled external
platform. The environment name must match `githubEnvironment`, for
example `test-postgresql`. Use the same normalized secret names in every
environment; each adapter reads only the values its connection mode
requires.

SQLite and DuckDB are local platforms and do not require protected
GitHub environments or rows in the external-database matrix.

| Connection style | Required normalized secrets |
|----|----|
| Server and password | `HADES_DB_USER`, `HADES_DB_PASSWORD`, `HADES_DB_SERVER`, `HADES_CDM_SCHEMA`, `HADES_WORK_SCHEMA` |
| Connection string and password | `HADES_DB_USER`, `HADES_DB_PASSWORD`, `HADES_DB_CONNECTION_STRING`, `HADES_CDM_SCHEMA`, `HADES_WORK_SCHEMA` |
| Connection string and key file | `HADES_DB_CONNECTION_STRING`, `HADES_DB_KEY_FILE`, `HADES_CDM_SCHEMA`, `HADES_WORK_SCHEMA` |

For BigQuery, `HADES_DB_KEY_FILE` may be an existing file path or the
key JSON contents. When it contains JSON, Panoptes writes a restricted
temporary file and removes it on exit. The connection string must
contain `<keyfile path>` where the generated path should be substituted.

Optionally define `HADES_VOCABULARY_SCHEMA` and `HADES_CDM_VERSION`. Do
not create blank placeholder secrets; an unset optional value allows the
documented default to apply.

Apply organization-approved reviewers and deployment rules to each
environment. Pull requests from forks do not receive protected secrets.
The bundled workflow skips fork-originated pull requests; a maintainer
can evaluate trusted code with manual dispatch after it is present in
the repository.

## 8. Configure live database CI

Copy the installed workflow template instead of maintaining a second
full YAML example from this vignette:

``` r

dir.create(".github/workflows", recursive = TRUE, showWarnings = FALSE)
file.copy(
  system.file(
    "templates",
    "database-platform-tests.yml",
    package = "Panoptes"
  ),
  ".github/workflows/database-platform-tests.yml"
)
```

For the PostgreSQL-first declaration, retain only the PostgreSQL matrix
row. Whenever a platform becomes enabled in the declaration, add its
DBMS, runner, and GitHub environment row in the same change. Packages
declaring all adapters should retain all eight external rows from the
template; SQLite and DuckDB remain local platforms and are not part of
the live matrix.

The template provides:

- `pull_request` and `workflow_dispatch` triggers, with no scheduled
  trigger;
- one isolated job for each enabled external DBMS;
- a safe condition that prevents fork pull requests from receiving live
  jobs;
- the runner and protected environment declared for each matrix row;
- normalized secret-to-environment-variable mapping;
- cross-platform Java setup;
- an explicit per-DBMS JDBC driver download;
- declaration/workflow drift validation; and
- `R CMD check` with `HADES_DATABASE_TEST=true`, focused on the live
  behavior test when the optional ordinary-test guards are present.

Panoptes does not define or require scheduled database testing. Trigger
policy belongs to the consumer workflow.

## 9. Validate and roll out

Validate the static workflow locally whenever the declaration or matrix
changes:

``` r

config <- Panoptes::readDatabaseTestConfig(
  path = "inst/test-config/hades-database-platforms.yml"
)
Panoptes::validateDatabaseTestWorkflow(
  config,
  ".github/workflows/database-platform-tests.yml"
)
```

The validator reports missing platforms, extra platforms, wrong runners,
and wrong GitHub environment names. It expects exactly one row for every
enabled external platform.

Begin with the PostgreSQL subset and run it using `workflow_dispatch`.
After the package behavior and cleanup succeed, add the remaining
supported platforms to the declaration and workflow together. A required
matrix job must not be considered complete until it has used valid
credentials, verified a connection, run the package assertions, and
cleaned its objects.

Use these failure modes when diagnosing a job:

| Symptom | Meaning |
|----|----|
| Local test skips and names missing variables | Complete the local environment or intentionally leave the platform unavailable |
| Required live CI reports missing variables | The selected GitHub environment lacks required normalized secrets |
| Incompatible-platform error | The workflow runner does not satisfy the declaration’s `os` policy |
| Driver or Java error | Java or the selected JDBC driver was not provisioned before the test |
| Connection error | Connection details were constructed, but the live verification failed |
| No-connection-attempt error | Required CI exited before verification or meaningful behavior began |
| Cleanup error or leftover objects | The consumer’s idempotent [`on.exit()`](https://rdrr.io/r/base/on.exit.html) cleanup is incomplete |
| Workflow-drift error | The declaration and static matrix rows no longer agree |

## Maintenance checklist

When database support changes:

1.  update the declaration and workflow row together;
2.  provision or remove the matching protected GitHub environment;
3.  verify runner, OS, Java, and driver compatibility;
4.  update the declared CDM version or environment override
    intentionally;
5.  keep the behavior assertions equivalent across DBMSs;
6.  verify success and error paths both clean package-owned objects;
7.  run the consumer integration test and workflow validator; and
8.  run every required external platform before claiming support.
