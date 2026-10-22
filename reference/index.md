# Package index

## Configuration and selection

- [`readDatabaseTestConfig()`](https://ohdsi.github.io/Panoptes/reference/readDatabaseTestConfig.md)
  : Read a database test declaration
- [`validateDatabaseTestConfig()`](https://ohdsi.github.io/Panoptes/reference/validateDatabaseTestConfig.md)
  : Validate a database test declaration
- [`getConfiguredDatabasePlatforms()`](https://ohdsi.github.io/Panoptes/reference/getConfiguredDatabasePlatforms.md)
  : List configured database platforms
- [`getSelectedTestDbms()`](https://ohdsi.github.io/Panoptes/reference/getSelectedTestDbms.md)
  : Resolve the selected database platform
- [`getDatabasePlatformConfig()`](https://ohdsi.github.io/Panoptes/reference/getDatabasePlatformConfig.md)
  : Get one database platform declaration

## Test environment and lifecycle

- [`resolveDatabaseTestEnvironment()`](https://ohdsi.github.io/Panoptes/reference/resolveDatabaseTestEnvironment.md)
  : Resolve the normalized database test environment
- [`validateDatabaseTestEnvironment()`](https://ohdsi.github.io/Panoptes/reference/validateDatabaseTestEnvironment.md)
  : Validate a resolved database test environment
- [`createDatabaseTestContext()`](https://ohdsi.github.io/Panoptes/reference/createDatabaseTestContext.md)
  : Create a database test context
- [`withDatabaseTestContext()`](https://ohdsi.github.io/Panoptes/reference/withDatabaseTestContext.md)
  : Evaluate code with a scoped database test context
- [`verifyDatabaseTestConnection()`](https://ohdsi.github.io/Panoptes/reference/verifyDatabaseTestConnection.md)
  : Verify that a database can be reached
- [`databaseTestConnectionAttempted()`](https://ohdsi.github.io/Panoptes/reference/databaseTestConnectionAttempted.md)
  : Report whether live connection verification was attempted
- [`requireDatabaseTestConnectionAttempted()`](https://ohdsi.github.io/Panoptes/reference/requireDatabaseTestConnectionAttempted.md)
  : Require proof of a live connection attempt
- [`createUniqueDatabaseObjectName()`](https://ohdsi.github.io/Panoptes/reference/createUniqueDatabaseObjectName.md)
  : Create a collision-resistant database object name

## Test focus

- [`isLiveDatabaseTest()`](https://ohdsi.github.io/Panoptes/reference/isLiveDatabaseTest.md)
  : Detect explicit live-database test mode
- [`skipIfNoLiveDatabase()`](https://ohdsi.github.io/Panoptes/reference/skipIfNoLiveDatabase.md)
  : Skip unless a live database is selected
- [`skipIfLiveDatabaseTest()`](https://ohdsi.github.io/Panoptes/reference/skipIfLiveDatabaseTest.md)
  : Skip ordinary tests during focused live-database execution

## Continuous integration

- [`validateDatabaseTestWorkflow()`](https://ohdsi.github.io/Panoptes/reference/validateDatabaseTestWorkflow.md)
  : Validate a static CI matrix against a declaration
