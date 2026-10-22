#' Resolve the selected database platform
#'
#' @param config A database test configuration.
#' @param value Selection value, normally `HADES_TEST_DBMS`.
#'
#' @return A canonical DBMS name, or `NULL` when no DBMS is selected.
#' @export
getSelectedTestDbms <- function(
    config,
    value = Sys.getenv("HADES_TEST_DBMS", unset = "")) {
  config <- asDatabaseTestConfig(config)
  if (!isScalarCharacter(value, allowEmpty = TRUE)) {
    stop("The DBMS selection must be one character value.", call. = FALSE)
  }
  if (!nzchar(trimws(value))) {
    return(NULL)
  }
  dbms <- canonicalizeDbms(value)
  platform <- getDatabasePlatformConfig(config, dbms)
  if (!platform$enabled) {
    panoptesError(
      sprintf("Database platform '%s' is disabled: %s", dbms, platform$reason),
      "panoptes_platform_disabled",
      dbms = dbms
    )
  }
  dbms
}

#' Get one database platform declaration
#'
#' @param config A database test configuration.
#' @param dbms DBMS name or alias. Defaults to the selected DBMS.
#'
#' @return A platform mapping, or `NULL` when no DBMS is selected.
#' @export
getDatabasePlatformConfig <- function(
    config,
    dbms = Sys.getenv("HADES_TEST_DBMS", unset = "")) {
  config <- asDatabaseTestConfig(config)
  if (is.null(dbms) || (is.character(dbms) && length(dbms) == 1L && !nzchar(trimws(dbms)))) {
    return(NULL)
  }
  canonical <- canonicalizeDbms(dbms)
  matches <- vapply(config$platforms, function(x) identical(x$dbms, canonical), logical(1))
  if (!any(matches)) {
    panoptesError(
      sprintf("Database platform '%s' is not declared by %s.", canonical, config$package),
      "panoptes_platform_not_declared",
      dbms = canonical
    )
  }
  config$platforms[[which(matches)[1L]]]
}
