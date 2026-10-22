.panoptesDbmsAliases <- c(
  "postgres" = "postgresql",
  "postgresql" = "postgresql",
  "sqlserver" = "sql server",
  "sql server" = "sql server",
  "sql_server" = "sql server",
  "mssql" = "sql server",
  "oracle" = "oracle",
  "redshift" = "redshift",
  "spark" = "spark",
  "bigquery" = "bigquery",
  "big query" = "bigquery",
  "big_query" = "bigquery",
  "snowflake" = "snowflake",
  "iris" = "iris",
  "sqlite" = "sqlite"
)

.panoptesSupportedDbms <- unique(unname(.panoptesDbmsAliases))

canonicalizeDbms <- function(dbms, allowUnknown = FALSE) {
  if (!is.character(dbms) || length(dbms) != 1L || is.na(dbms)) {
    stop("`dbms` must be one non-missing character value.", call. = FALSE)
  }
  value <- tolower(trimws(dbms))
  canonical <- unname(.panoptesDbmsAliases[value])
  if (length(canonical) == 0L || is.na(canonical)) {
    if (allowUnknown) {
      return(value)
    }
    stop(sprintf("Unsupported DBMS '%s'.", value), call. = FALSE)
  }
  canonical
}

isScalarCharacter <- function(x, allowEmpty = FALSE) {
  is.character(x) && length(x) == 1L && !is.na(x) &&
    (allowEmpty || nzchar(trimws(x)))
}

isScalarLogical <- function(x) {
  is.logical(x) && length(x) == 1L && !is.na(x)
}

isTruthy <- function(value) {
  tolower(trimws(value)) %in% c("1", "true", "yes", "on")
}

panoptesError <- function(message, class = "panoptes_error", ...) {
  condition <- structure(
    c(list(message = message, call = NULL), list(...)),
    class = c(class, "error", "condition")
  )
  stop(condition)
}

findPackageRoot <- function(start, package = NULL) {
  start <- normalizePath(start, winslash = "/", mustWork = FALSE)
  repeat {
    description <- file.path(start, "DESCRIPTION")
    if (file.exists(description)) {
      fields <- tryCatch(read.dcf(description), error = function(e) NULL)
      foundPackage <- if (is.null(fields)) "" else fields[1L, "Package"]
      if (is.null(package) || identical(foundPackage, package)) {
        return(start)
      }
    }
    parent <- dirname(start)
    if (identical(parent, start)) {
      return(NULL)
    }
    start <- parent
  }
}

currentOperatingSystem <- function() {
  if (.Platform$OS.type == "windows") {
    "windows"
  } else if (identical(Sys.info()[["sysname"]], "Darwin")) {
    "macos"
  } else {
    "linux"
  }
}
