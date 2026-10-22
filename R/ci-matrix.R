#' Derive a CI matrix from a database test declaration
#'
#' @param config A database test configuration.
#' @param ci One CI tier: `pull-request`, `push`, `scheduled`, `manual`, or
#'   `none`.
#'
#' @return A data frame suitable for serializing as a GitHub Actions matrix.
#' @export
getDatabaseTestMatrix <- function(config, ci) {
  platforms <- getConfiguredDatabasePlatforms(config, ci = ci, enabled = TRUE)
  if (!length(platforms)) {
    return(data.frame(
      dbms = character(),
      runner = character(),
      environment = character(),
      required = logical(),
      ci = character(),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    dbms = vapply(platforms, `[[`, character(1), "dbms"),
    runner = vapply(platforms, `[[`, character(1), "runner"),
    environment = vapply(platforms, `[[`, character(1), "githubEnvironment"),
    required = vapply(platforms, `[[`, logical(1), "required"),
    ci = vapply(platforms, `[[`, character(1), "ci"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

extractWorkflowMatrix <- function(workflow) {
  if (!is.list(workflow$jobs)) {
    stop("Workflow must contain a `jobs` mapping.", call. = FALSE)
  }
  includes <- list()
  for (job in workflow$jobs) {
    include <- job$strategy$matrix$include
    if (is.list(include)) {
      includes <- c(includes, include)
    }
  }
  Filter(function(x) is.list(x) && !is.null(x$dbms), includes)
}

#' Validate a static CI matrix against a declaration
#'
#' @param config A database test configuration.
#' @param workflow Path to a GitHub Actions YAML workflow or an already parsed
#'   workflow mapping.
#' @param ci CI tier represented by the static matrix.
#'
#' @return `TRUE`, invisibly, or a `panoptes_workflow_drift` error.
#' @export
validateDatabaseTestWorkflow <- function(config, workflow, ci) {
  config <- asDatabaseTestConfig(config)
  if (is.character(workflow) && length(workflow) == 1L) {
    if (!file.exists(workflow)) {
      stop(sprintf("Workflow not found at '%s'.", workflow), call. = FALSE)
    }
    workflow <- yaml::read_yaml(workflow)
  }
  if (!is.list(workflow)) {
    stop("`workflow` must be a path or parsed YAML mapping.", call. = FALSE)
  }
  expected <- getDatabaseTestMatrix(config, ci)
  include <- extractWorkflowMatrix(workflow)
  observed <- if (length(include)) {
    data.frame(
      dbms = vapply(include, function(x) canonicalizeDbms(x$dbms), character(1)),
      runner = vapply(include, function(x) {
        if (is.null(x$runner)) "" else as.character(x$runner)
      }, character(1)),
      environment = vapply(include, function(x) {
        if (is.null(x$environment)) "" else as.character(x$environment)
      }, character(1)),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(dbms = character(), runner = character(), environment = character())
  }
  expected <- expected[order(expected$dbms), c("dbms", "runner", "environment"), drop = FALSE]
  observed <- observed[order(observed$dbms), , drop = FALSE]
  rownames(expected) <- NULL
  rownames(observed) <- NULL
  if (!identical(expected, observed)) {
    missing <- setdiff(expected$dbms, observed$dbms)
    extra <- setdiff(observed$dbms, expected$dbms)
    mismatched <- intersect(expected$dbms, observed$dbms)
    mismatched <- mismatched[vapply(mismatched, function(dbms) {
      !identical(
        expected[expected$dbms == dbms, c("runner", "environment"), drop = FALSE],
        observed[observed$dbms == dbms, c("runner", "environment"), drop = FALSE]
      )
    }, logical(1))]
    details <- c(
      if (length(missing)) paste0("missing: ", paste(missing, collapse = ", ")),
      if (length(extra)) paste0("extra: ", paste(extra, collapse = ", ")),
      if (length(mismatched)) paste0("runner/environment mismatch: ", paste(mismatched, collapse = ", "))
    )
    panoptesError(
      paste0("Database workflow matrix does not match the declaration (", paste(details, collapse = "; "), ")."),
      "panoptes_workflow_drift",
      missing = missing,
      extra = extra,
      mismatched = mismatched
    )
  }
  invisible(TRUE)
}
