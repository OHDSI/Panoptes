.panoptesDbmsMaxIdentifierLength <- c(
  "oracle" = 30L,
  "postgresql" = 63L,
  "redshift" = 127L,
  "sql server" = 128L,
  "spark" = 128L,
  "bigquery" = 300L,
  "snowflake" = 255L,
  "iris" = 200L,
  "sqlite" = 255L
)

#' Create a collision-resistant database object name
#'
#' @param prefix Human-readable prefix. Invalid characters are converted to
#'   underscores and a leading letter is enforced.
#' @param maxLength Maximum identifier length. When omitted, a conservative
#'   63-character limit is used.
#'
#' @return A lower-case database identifier.
#' @export
createUniqueDatabaseObjectName <- function(prefix, maxLength = NULL) {
  if (!isScalarCharacter(prefix)) {
    stop("`prefix` must be one non-empty character value.", call. = FALSE)
  }
  if (is.null(maxLength)) {
    maxLength <- 63L
  }
  if (!is.numeric(maxLength) || length(maxLength) != 1L || is.na(maxLength) || maxLength < 16) {
    stop("`maxLength` must be one number of at least 16.", call. = FALSE)
  }
  prefix <- tolower(gsub("[^A-Za-z0-9_]", "_", prefix))
  prefix <- gsub("_+", "_", prefix)
  if (!grepl("^[a-z]", prefix)) {
    prefix <- paste0("x_", prefix)
  }
  suffix <- paste0(
    format(Sys.time(), "%Y%m%d%H%M%S"),
    "_",
    Sys.getpid(),
    "_",
    sprintf("%06d", sample.int(999999L, 1L))
  )
  available <- as.integer(maxLength) - nchar(suffix) - 1L
  paste0(substr(prefix, 1L, available), "_", suffix)
}
