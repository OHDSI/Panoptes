checkPlatformCompatibility <- function(platform) {
  if (platform$os == "any" || platform$os == currentOperatingSystem()) {
    return(invisible(TRUE))
  }
  message <- sprintf(
    "Database platform '%s' requires %s but this process is running on %s.",
    platform$dbms,
    platform$os,
    currentOperatingSystem()
  )
  if (isLiveDatabaseTest() && platform$required) {
    panoptesError(message, "panoptes_incompatible_platform", dbms = platform$dbms)
  }
  testthat::skip(message)
}

#' Create a database test context
#'
#' The returned context is constructed only after configuration, platform,
#' compatibility, and environment validation succeeds. It does not connect to
#' the database eagerly. Prefer [withDatabaseTestContext()] when temporary
#' credentials may be required.
#'
#' @param config A database test configuration.
#' @param dbms Optional DBMS selection. Defaults to `HADES_TEST_DBMS`.
#' @param legacyAliases Explicit normalized-to-legacy environment aliases.
#'
#' @return A `panoptes_database_test_context` object.
#' @export
createDatabaseTestContext <- function(
    config,
    dbms = NULL,
    legacyAliases = NULL) {
  config <- asDatabaseTestConfig(config)
  if (is.null(dbms)) {
    dbms <- getSelectedTestDbms(config)
  }
  if (is.null(dbms)) {
    panoptesError(
      "No database is selected. Set HADES_TEST_DBMS or supply `dbms`.",
      "panoptes_no_database_selected"
    )
  }
  platform <- getDatabasePlatformConfig(config, dbms)
  if (!platform$enabled) {
    panoptesError(
      sprintf("Database platform '%s' is disabled: %s", platform$dbms, platform$reason),
      "panoptes_platform_disabled"
    )
  }
  checkPlatformCompatibility(platform)
  environment <- resolveDatabaseTestEnvironment(platform, aliases = legacyAliases)
  validateDatabaseTestEnvironment(platform, environment)
  connectionDetails <- createPlatformConnectionDetails(
    platform,
    environment,
    deferEnv = parent.frame()
  )
  state <- new.env(parent = emptyenv())
  state$connectionAttempted <- FALSE
  result <- list(
    dbms = platform$dbms,
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = environment$values$HADES_CDM_SCHEMA,
    vocabularyDatabaseSchema = environment$values$HADES_VOCABULARY_SCHEMA,
    workDatabaseSchema = environment$values$HADES_WORK_SCHEMA,
    cdmVersion = environment$values$HADES_CDM_VERSION,
    tempEmulationSchema = if (platform$tempEmulationSchema) {
      environment$values$HADES_WORK_SCHEMA
    } else {
      NULL
    },
    objectPrefix = createUniqueDatabaseObjectName(
      "panoptes",
      .panoptesDbmsMaxIdentifierLength[[platform$dbms]]
    ),
    platform = platform,
    .state = state
  )
  class(result) <- c("panoptes_database_test_context", "list")
  result
}

#' @export
print.panoptes_database_test_context <- function(x, ...) {
  cat("<panoptes_database_test_context>", "\n", sep = "")
  cat("  DBMS: ", x$dbms, "\n", sep = "")
  cat("  CDM schema: ", x$cdmDatabaseSchema, "\n", sep = "")
  cat("  vocabulary schema: ", x$vocabularyDatabaseSchema, "\n", sep = "")
  cat("  work schema: ", x$workDatabaseSchema, "\n", sep = "")
  cat("  CDM version: ", x$cdmVersion, "\n", sep = "")
  cat("  connection attempted: ", databaseTestConnectionAttempted(x), "\n", sep = "")
  cat("  connection details: <redacted>\n")
  invisible(x)
}

#' Verify that a database can be reached
#'
#' Opens and immediately closes a connection. The context records the attempt
#' before connecting, so CI can distinguish an exercised job from an early
#' return even when connection creation fails.
#'
#' @param context A Panoptes database test context.
#'
#' @return `TRUE`, invisibly, when connection and disconnection succeed.
#' @export
verifyDatabaseTestConnection <- function(context) {
  if (!inherits(context, "panoptes_database_test_context")) {
    stop("`context` must be a Panoptes database test context.", call. = FALSE)
  }
  connector <- getOption("Panoptes.connect", DatabaseConnector::connect)
  disconnector <- getOption("Panoptes.disconnect", DatabaseConnector::disconnect)
  context$.state$connectionAttempted <- TRUE
  connection <- tryCatch(
    connector(context$connectionDetails),
    error = function(error) {
      panoptesError(
        sprintf("Live connection attempt failed for %s.", context$dbms),
        "panoptes_connection_error",
        dbms = context$dbms
      )
    }
  )
  on.exit(
    tryCatch(
      disconnector(connection),
      error = function(error) {
        panoptesError(
          sprintf("Failed to close the test connection for %s.", context$dbms),
          "panoptes_disconnection_error",
          dbms = context$dbms
        )
      }
    ),
    add = TRUE
  )
  invisible(TRUE)
}

#' Report whether live connection verification was attempted
#'
#' @param context A Panoptes database test context.
#'
#' @return A logical scalar.
#' @export
databaseTestConnectionAttempted <- function(context) {
  inherits(context, "panoptes_database_test_context") &&
    isTRUE(context$.state$connectionAttempted)
}

#' Require proof of a live connection attempt
#'
#' @param context A Panoptes database test context.
#'
#' @return `TRUE`, invisibly, or an error in required live CI.
#' @export
requireDatabaseTestConnectionAttempted <- function(context) {
  if (databaseTestConnectionAttempted(context)) {
    return(invisible(TRUE))
  }
  message <- sprintf("No live connection was attempted for %s.", context$dbms)
  if (isLiveDatabaseTest() && isTRUE(context$platform$required)) {
    panoptesError(message, "panoptes_connection_not_attempted", dbms = context$dbms)
  }
  testthat::skip(message)
}

#' Evaluate code with a scoped database test context
#'
#' The expression can refer to `context`. Package-owned temporary credential
#' files and the `sqlRenderTempEmulationSchema` option are restored when the
#' call exits, including after an error. If the expression evaluates to a
#' function, that function is called with the context as its only argument.
#'
#' @param config A database test configuration.
#' @param code Code to evaluate, or a function accepting one context argument.
#' @param dbms Optional DBMS selection.
#' @param legacyAliases Explicit legacy environment aliases.
#' @param verify Whether to verify a live connection before evaluating `code`.
#'
#' @return The value produced by `code`.
#' @export
withDatabaseTestContext <- function(
    config,
    code,
    dbms = NULL,
    legacyAliases = NULL,
    verify = FALSE) {
  expression <- substitute(code)
  evaluationEnvironment <- new.env(parent = parent.frame())
  context <- createDatabaseTestContext(config, dbms, legacyAliases)
  evaluationEnvironment$context <- context
  withr::local_options(
    list(sqlRenderTempEmulationSchema = context$tempEmulationSchema),
    .local_envir = environment()
  )
  if (isTRUE(verify)) {
    verifyDatabaseTestConnection(context)
  }
  result <- eval(expression, envir = evaluationEnvironment)
  if (is.function(result)) {
    result(context)
  } else {
    result
  }
}
