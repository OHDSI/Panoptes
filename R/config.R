#' Read a database test declaration
#'
#' Locates, reads, and validates a consumer package's
#' `inst/test-config/hades-database-platforms.yml` declaration. An explicit
#' `path` is recommended in tooling. During package tests, Panoptes can locate a
#' source package by walking upward from the working directory.
#'
#' @param package Optional installed package name, package source directory, or
#'   expected package name.
#' @param path Optional path to the YAML declaration.
#'
#' @return A validated database test configuration with class
#'   `panoptes_database_test_config`.
#' @export
readDatabaseTestConfig <- function(package = NULL, path = NULL) {
  if (!is.null(path)) {
    if (!isScalarCharacter(path)) {
      stop("`path` must be one non-empty character value.", call. = FALSE)
    }
    configPath <- path
  } else if (!is.null(package) && dir.exists(package)) {
    configPath <- file.path(
      package,
      "inst",
      "test-config",
      "hades-database-platforms.yml"
    )
  } else {
    installedPath <- if (isScalarCharacter(package)) {
      system.file(
        "test-config",
        "hades-database-platforms.yml",
        package = package,
        mustWork = FALSE
      )
    } else {
      ""
    }
    if (nzchar(installedPath)) {
      configPath <- installedPath
    } else {
      root <- findPackageRoot(getwd(), package = package)
      if (is.null(root)) {
        panoptesError(
          "Could not locate a package root. Supply `path` or `package` explicitly.",
          "panoptes_config_not_found"
        )
      }
      configPath <- file.path(
        root,
        "inst",
        "test-config",
        "hades-database-platforms.yml"
      )
    }
  }

  if (!file.exists(configPath)) {
    panoptesError(
      sprintf("Database test declaration not found at '%s'.", configPath),
      "panoptes_config_not_found",
      path = configPath
    )
  }

  config <- yaml::read_yaml(configPath)
  expectedPackage <- if (!is.null(package) && !dir.exists(package)) package else NULL
  config <- validateDatabaseTestConfig(config, package = expectedPackage)
  attr(config, "path") <- normalizePath(configPath, winslash = "/")
  config
}

#' Validate a database test declaration
#'
#' Validation is normative even when the bundled JSON Schema is used by an
#' editor. Unknown fields are rejected so configuration cannot silently become
#' descriptive rather than executable.
#'
#' @param config Parsed YAML configuration.
#' @param package Optional expected package name.
#'
#' @return `config`, invisibly, with normalized canonical DBMS values and class
#'   `panoptes_database_test_config`.
#' @export
validateDatabaseTestConfig <- function(config, package = NULL) {
  if (!is.list(config) || is.null(names(config))) {
    stop("Database test configuration must be a named mapping.", call. = FALSE)
  }
  allowedTop <- c("schemaVersion", "package", "databaseConnection", "platforms")
  unknownTop <- setdiff(names(config), allowedTop)
  if (length(unknownTop)) {
    stop(
      sprintf("Unknown top-level configuration field(s): %s.", paste(unknownTop, collapse = ", ")),
      call. = FALSE
    )
  }
  missingTop <- setdiff(allowedTop, names(config))
  if (length(missingTop)) {
    stop(
      sprintf("Missing top-level configuration field(s): %s.", paste(missingTop, collapse = ", ")),
      call. = FALSE
    )
  }
  if (!is.numeric(config$schemaVersion) || length(config$schemaVersion) != 1L ||
      is.na(config$schemaVersion) || config$schemaVersion != 1) {
    stop("`schemaVersion` must be 1.", call. = FALSE)
  }
  if (!isScalarCharacter(config$package)) {
    stop("`package` must be one non-empty character value.", call. = FALSE)
  }
  if (!is.null(package) && !identical(config$package, package)) {
    stop(
      sprintf("Database test configuration is for '%s', not '%s'.", config$package, package),
      call. = FALSE
    )
  }
  if (!isScalarCharacter(config$databaseConnection) ||
      !config$databaseConnection %in% c("none", "subset", "all")) {
    stop("`databaseConnection` must be one of none, subset, or all.", call. = FALSE)
  }
  if (!is.list(config$platforms)) {
    stop("`platforms` must be a list.", call. = FALSE)
  }
  if (identical(config$databaseConnection, "none") && length(config$platforms)) {
    stop("`platforms` must be empty when `databaseConnection` is none.", call. = FALSE)
  }
  if (!identical(config$databaseConnection, "none") && !length(config$platforms)) {
    stop("`platforms` must not be empty when database connections are declared.", call. = FALSE)
  }

  config$platforms <- lapply(seq_along(config$platforms), function(index) {
    validatePlatformConfig(config$platforms[[index]], index)
  })
  dbms <- vapply(config$platforms, `[[`, character(1), "dbms")
  duplicates <- unique(dbms[duplicated(dbms)])
  if (length(duplicates)) {
    stop(
      sprintf("Duplicate database platform(s): %s.", paste(duplicates, collapse = ", ")),
      call. = FALSE
    )
  }
  if (identical(config$databaseConnection, "all") &&
      !setequal(dbms, .panoptesSupportedDbms)) {
    missing <- setdiff(.panoptesSupportedDbms, dbms)
    stop(
      sprintf(
        "`databaseConnection: all` requires every Panoptes platform; missing: %s.",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  class(config) <- c("panoptes_database_test_config", "list")
  invisible(config)
}

validatePlatformConfig <- function(platform, index) {
  if (!is.list(platform) || is.null(names(platform))) {
    stop(sprintf("Platform %d must be a named mapping.", index), call. = FALSE)
  }
  required <- c(
    "dbms", "enabled", "required", "cdmVersion",
    "connectionMode", "tempEmulationSchema", "runner", "os"
  )
  allowed <- c(required, "credentialMode", "reason", "githubEnvironment")
  unknown <- setdiff(names(platform), allowed)
  if (length(unknown)) {
    stop(
      sprintf("Platform %d has unknown field(s): %s.", index, paste(unknown, collapse = ", ")),
      call. = FALSE
    )
  }
  missing <- setdiff(required, names(platform))
  if (length(missing)) {
    stop(
      sprintf("Platform %d is missing field(s): %s.", index, paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  platform$dbms <- canonicalizeDbms(platform$dbms)
  if (!isScalarLogical(platform$enabled) || !isScalarLogical(platform$required) ||
      !isScalarLogical(platform$tempEmulationSchema)) {
    stop(
      sprintf("Platform '%s' enabled, required, and tempEmulationSchema must be logical.", platform$dbms),
      call. = FALSE
    )
  }
  if (!isScalarCharacter(platform$cdmVersion) ||
      !grepl("^[0-9]+([.][0-9]+){1,2}$", platform$cdmVersion)) {
    stop(sprintf("Platform '%s' has an invalid `cdmVersion`.", platform$dbms), call. = FALSE)
  }
  if (!isScalarCharacter(platform$connectionMode) ||
      !platform$connectionMode %in% c("local", "server", "connectionString")) {
    stop(sprintf("Platform '%s' has an invalid `connectionMode`.", platform$dbms), call. = FALSE)
  }
  if (!isScalarCharacter(platform$runner) || !isScalarCharacter(platform$os) ||
      !platform$os %in% c("any", "linux", "windows", "macos")) {
    stop(sprintf("Platform '%s' must declare a runner and valid operating system.", platform$dbms), call. = FALSE)
  }
  if (is.null(platform$credentialMode)) {
    platform$credentialMode <- if (platform$connectionMode == "local") "none" else "password"
  }
  if (!isScalarCharacter(platform$credentialMode) ||
      !platform$credentialMode %in% c("none", "password", "keyFile")) {
    stop(sprintf("Platform '%s' has an invalid `credentialMode`.", platform$dbms), call. = FALSE)
  }
  if (platform$credentialMode == "keyFile" && platform$connectionMode != "connectionString") {
    stop("`credentialMode: keyFile` requires `connectionMode: connectionString`.", call. = FALSE)
  }
  if (!platform$enabled && !isScalarCharacter(platform$reason)) {
    stop(sprintf("Disabled platform '%s' must provide `reason`.", platform$dbms), call. = FALSE)
  }
  if (platform$required && !platform$enabled) {
    stop(sprintf("Required platform '%s' must be enabled.", platform$dbms), call. = FALSE)
  }
  if (platform$connectionMode == "local" && platform$dbms != "sqlite") {
    stop("Only SQLite can use `connectionMode: local` in Panoptes 0.1.0.", call. = FALSE)
  }
  if (platform$dbms == "sqlite" && platform$connectionMode != "local") {
    stop("SQLite must use `connectionMode: local`.", call. = FALSE)
  }
  if (is.null(platform$githubEnvironment)) {
    platform$githubEnvironment <- paste0("test-", gsub(" ", "-", platform$dbms, fixed = TRUE))
  }
  if (!isScalarCharacter(platform$githubEnvironment)) {
    stop(sprintf("Platform '%s' has an invalid `githubEnvironment`.", platform$dbms), call. = FALSE)
  }
  platform
}

#' List configured database platforms
#'
#' @param config A validated configuration or path/package input accepted by
#'   [readDatabaseTestConfig()].
#' @param enabled Whether to return enabled (`TRUE`), disabled (`FALSE`), or all
#'   (`NULL`) platforms.
#'
#' @return A list of platform mappings.
#' @export
getConfiguredDatabasePlatforms <- function(config, enabled = TRUE) {
  config <- asDatabaseTestConfig(config)
  platforms <- config$platforms
  if (!is.null(enabled)) {
    if (!isScalarLogical(enabled)) {
      stop("`enabled` must be TRUE, FALSE, or NULL.", call. = FALSE)
    }
    platforms <- Filter(function(x) identical(x$enabled, enabled), platforms)
  }
  platforms
}

asDatabaseTestConfig <- function(config) {
  if (inherits(config, "panoptes_database_test_config")) {
    return(config)
  }
  if (is.character(config) && length(config) == 1L) {
    if (file.exists(config)) {
      return(readDatabaseTestConfig(path = config))
    }
    return(readDatabaseTestConfig(package = config))
  }
  validateDatabaseTestConfig(config)
}
