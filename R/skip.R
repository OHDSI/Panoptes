#' Detect explicit live-database test mode
#'
#' @param value Value to interpret, normally `HADES_DATABASE_TEST`.
#'
#' @return A logical scalar.
#' @export
isLiveDatabaseTest <- function(
    value = Sys.getenv("HADES_DATABASE_TEST", unset = "false")) {
  isTruthy(value)
}

#' Skip unless a live database is selected
#'
#' @param config A database test configuration.
#'
#' @return `TRUE`, invisibly, or a testthat skip.
#' @export
skipIfNoLiveDatabase <- function(config) {
  if (is.null(getSelectedTestDbms(config))) {
    testthat::skip("Set HADES_TEST_DBMS to run live database platform tests.")
  }
  invisible(TRUE)
}

#' Skip ordinary tests during focused live-database execution
#'
#' @return `TRUE`, invisibly, or a testthat skip.
#' @export
skipIfLiveDatabaseTest <- function() {
  if (isLiveDatabaseTest()) {
    testthat::skip("Skipping non-database tests in live database mode.")
  }
  invisible(TRUE)
}
