makeTestPlatform <- function(
    dbms = "postgresql",
    enabled = TRUE,
    required = TRUE,
    connectionMode = "server",
    credentialMode = "password",
    tempEmulationSchema = FALSE,
    runner = "ubuntu-latest",
    os = "any") {
  list(
    dbms = dbms,
    enabled = enabled,
    required = required,
    cdmVersion = "5.4",
    connectionMode = connectionMode,
    credentialMode = credentialMode,
    tempEmulationSchema = tempEmulationSchema,
    runner = runner,
    os = os,
    githubEnvironment = paste0("test-", gsub(" ", "-", dbms, fixed = TRUE))
  )
}

makeTestConfig <- function(platforms = list(makeTestPlatform())) {
  validateDatabaseTestConfig(list(
    schemaVersion = 1,
    package = "ExamplePackage",
    databaseConnection = if (length(platforms)) "subset" else "none",
    platforms = platforms
  ))
}

databaseEnvironment <- c(
  HADES_DB_USER = "user",
  HADES_DB_PASSWORD = "password",
  HADES_DB_SERVER = "server/database",
  HADES_DB_CONNECTION_STRING = "jdbc:test://server/database",
  HADES_DB_KEY_FILE = "{\"type\":\"service_account\"}",
  HADES_CDM_SCHEMA = "cdm",
  HADES_VOCABULARY_SCHEMA = "vocabulary",
  HADES_WORK_SCHEMA = "work",
  HADES_CDM_VERSION = "5.4",
  HADES_DATABASE_TEST = "false",
  HADES_TEST_DBMS = "postgresql"
)

mockConnectionDetails <- function(...) {
  list(...)
}
