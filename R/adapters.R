getJdbcDriverFolder <- function() {
  configured <- Sys.getenv("DATABASECONNECTOR_JAR_FOLDER", unset = "")
  if (nzchar(configured)) {
    return(configured)
  }
  path <- file.path(path.expand("~"), ".jdbcDrivers")
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  path
}

normalizeSparkConnectionString <- function(connectionString) {
  if (!nzchar(connectionString) || grepl("EnableArrow=0", connectionString, fixed = TRUE)) {
    return(connectionString)
  }
  if (grepl(";$", connectionString)) {
    paste0(connectionString, "EnableArrow=0")
  } else {
    paste0(connectionString, ";EnableArrow=0")
  }
}

normalizeSnowflakeConnectionString <- function(connectionString) {
  if (!nzchar(connectionString) || grepl("JDBC_QUERY_RESULT_FORMAT=JSON", connectionString, fixed = TRUE)) {
    return(connectionString)
  }
  separator <- if (grepl("?", connectionString, fixed = TRUE)) "&" else "?"
  paste0(connectionString, separator, "JDBC_QUERY_RESULT_FORMAT=JSON")
}

prepareKeyFile <- function(value, deferEnv) {
  if (file.exists(value)) {
    return(normalizePath(value, winslash = "/"))
  }
  path <- tempfile("panoptes-key-", fileext = ".json")
  writeLines(value, path, useBytes = TRUE)
  Sys.chmod(path, mode = "0600")
  withr::defer(unlink(path, force = TRUE), envir = deferEnv)
  normalizePath(path, winslash = "/")
}

createPlatformConnectionDetails <- function(platform, environment, deferEnv) {
  values <- environment$values
  factory <- getOption(
    "Panoptes.connectionDetailsFactory",
    DatabaseConnector::createConnectionDetails
  )
  args <- list(
    dbms = platform$dbms,
    pathToDriver = getJdbcDriverFolder()
  )
  if (platform$connectionMode %in% c("local", "server")) {
    args$server <- values$HADES_DB_SERVER
  }
  if (platform$credentialMode == "password") {
    args$user <- values$HADES_DB_USER
    args$password <- utils::URLdecode(values$HADES_DB_PASSWORD)
  }
  if (platform$connectionMode == "connectionString") {
    connectionString <- values$HADES_DB_CONNECTION_STRING
    if (platform$dbms == "spark") {
      connectionString <- normalizeSparkConnectionString(connectionString)
    }
    if (platform$dbms == "snowflake") {
      connectionString <- normalizeSnowflakeConnectionString(connectionString)
    }
    if (platform$credentialMode == "keyFile") {
      keyPath <- prepareKeyFile(values$HADES_DB_KEY_FILE, deferEnv)
      connectionString <- gsub(
        "<keyfile path>",
        keyPath,
        connectionString,
        fixed = TRUE
      )
      args$user <- ""
      args$password <- ""
    }
    args$connectionString <- connectionString
  }
  tryCatch(
    do.call(factory, args),
    error = function(error) {
      panoptesError(
        sprintf("Failed to construct connection details for %s.", platform$dbms),
        "panoptes_connection_details_error",
        dbms = platform$dbms
      )
    }
  )
}
