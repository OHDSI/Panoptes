.panoptesEnvironmentVariables <- c(
  "HADES_DB_USER",
  "HADES_DB_PASSWORD",
  "HADES_DB_SERVER",
  "HADES_DB_CONNECTION_STRING",
  "HADES_DB_KEY_FILE",
  "HADES_CDM_SCHEMA",
  "HADES_VOCABULARY_SCHEMA",
  "HADES_WORK_SCHEMA",
  "HADES_CDM_VERSION"
)

requiredEnvironmentVariables <- function(platform) {
  variables <- c("HADES_CDM_SCHEMA", "HADES_WORK_SCHEMA")
  if (platform$connectionMode == "local") {
    variables <- c("HADES_DB_SERVER", variables)
  } else if (platform$connectionMode == "server") {
    variables <- c(
      "HADES_DB_USER", "HADES_DB_PASSWORD", "HADES_DB_SERVER", variables
    )
  } else if (platform$credentialMode == "keyFile") {
    variables <- c("HADES_DB_CONNECTION_STRING", "HADES_DB_KEY_FILE", variables)
  } else {
    variables <- c(
      "HADES_DB_USER", "HADES_DB_PASSWORD", "HADES_DB_CONNECTION_STRING",
      variables
    )
  }
  variables
}

normalizeLegacyAliases <- function(aliases) {
  if (is.null(aliases)) {
    return(stats::setNames(vector("list", length(.panoptesEnvironmentVariables)), .panoptesEnvironmentVariables))
  }
  if (is.character(aliases) && !is.null(names(aliases))) {
    aliases <- lapply(aliases, function(x) x)
  }
  if (!is.list(aliases) || is.null(names(aliases))) {
    stop("`aliases` must be a named character vector or named list.", call. = FALSE)
  }
  unknown <- setdiff(names(aliases), .panoptesEnvironmentVariables)
  if (length(unknown)) {
    stop(sprintf("Unknown normalized alias target(s): %s.", paste(unknown, collapse = ", ")), call. = FALSE)
  }
  result <- stats::setNames(vector("list", length(.panoptesEnvironmentVariables)), .panoptesEnvironmentVariables)
  for (name in names(aliases)) {
    value <- aliases[[name]]
    if (!is.character(value) || anyNA(value) || any(!nzchar(value))) {
      stop(sprintf("Aliases for %s must be non-empty environment-variable names.", name), call. = FALSE)
    }
    result[[name]] <- unique(value)
  }
  result
}

#' Resolve the normalized database test environment
#'
#' Normalized `HADES_*` variables always take precedence. `aliases` allows a
#' consumer to explicitly map historical variable names during migration.
#' Values are retained for connection construction but are never shown by the
#' print method.
#'
#' @param platform A platform mapping returned by
#'   [getDatabasePlatformConfig()].
#' @param aliases Optional named character vector or list. Names are normalized
#'   `HADES_*` variables and values are legacy environment-variable names.
#'
#' @return A `panoptes_database_test_environment` object.
#' @export
resolveDatabaseTestEnvironment <- function(platform, aliases = NULL) {
  if (!is.list(platform) || is.null(platform$dbms)) {
    stop("`platform` must be a validated platform mapping.", call. = FALSE)
  }
  aliases <- normalizeLegacyAliases(aliases)
  values <- stats::setNames(as.list(rep("", length(.panoptesEnvironmentVariables))), .panoptesEnvironmentVariables)
  sources <- stats::setNames(rep(NA_character_, length(.panoptesEnvironmentVariables)), .panoptesEnvironmentVariables)

  for (name in .panoptesEnvironmentVariables) {
    value <- Sys.getenv(name, unset = "")
    source <- if (nzchar(value)) name else NA_character_
    if (!nzchar(value) && length(aliases[[name]])) {
      for (alias in aliases[[name]]) {
        candidate <- Sys.getenv(alias, unset = "")
        if (nzchar(candidate)) {
          value <- candidate
          source <- alias
          break
        }
      }
    }
    values[[name]] <- value
    sources[[name]] <- source
  }
  if (!nzchar(values$HADES_VOCABULARY_SCHEMA)) {
    values$HADES_VOCABULARY_SCHEMA <- values$HADES_CDM_SCHEMA
    if (nzchar(values$HADES_CDM_SCHEMA)) {
      sources[["HADES_VOCABULARY_SCHEMA"]] <- sources[["HADES_CDM_SCHEMA"]]
    }
  }
  if (!nzchar(values$HADES_CDM_VERSION)) {
    values$HADES_CDM_VERSION <- platform$cdmVersion
    sources[["HADES_CDM_VERSION"]] <- "configuration"
  }
  result <- list(
    dbms = platform$dbms,
    values = values,
    sources = sources,
    required = requiredEnvironmentVariables(platform)
  )
  class(result) <- c("panoptes_database_test_environment", "list")
  result
}

#' @export
print.panoptes_database_test_environment <- function(x, ...) {
  cat("<panoptes_database_test_environment>", "\n", sep = "")
  cat("  DBMS: ", x$dbms, "\n", sep = "")
  for (name in names(x$values)) {
    state <- if (nzchar(x$values[[name]])) "set" else "unset"
    cat("  ", name, ": <", state, ">\n", sep = "")
  }
  invisible(x)
}

#' Validate a resolved database test environment
#'
#' In a required explicit live-database job, missing values are errors. In
#' local development and optional CI jobs they are test skips. Validation is
#' deliberately completed before connection details or temporary credentials
#' are created.
#'
#' @param platform A validated platform mapping.
#' @param environment An object returned by
#'   [resolveDatabaseTestEnvironment()].
#' @param strict Whether missing values are errors. The default combines
#'   `HADES_DATABASE_TEST` with the platform's `required` policy.
#'
#' @return `TRUE`, invisibly, or a skip/error condition.
#' @export
validateDatabaseTestEnvironment <- function(platform, environment, strict = NULL) {
  if (!inherits(environment, "panoptes_database_test_environment")) {
    stop("`environment` must come from resolveDatabaseTestEnvironment().", call. = FALSE)
  }
  if (is.null(strict)) {
    strict <- isLiveDatabaseTest() && isTRUE(platform$required)
  }
  if (!isScalarLogical(strict)) {
    stop("`strict` must be TRUE or FALSE.", call. = FALSE)
  }
  missing <- environment$required[
    !vapply(environment$values[environment$required], nzchar, logical(1))
  ]
  if (length(missing)) {
    message <- sprintf(
      "Missing environment variables for %s: %s",
      platform$dbms,
      paste(missing, collapse = ", ")
    )
    if (strict) {
      panoptesError(
        message,
        "panoptes_missing_environment",
        dbms = platform$dbms,
        missing = missing
      )
    }
    testthat::skip(message)
  }
  invisible(TRUE)
}
