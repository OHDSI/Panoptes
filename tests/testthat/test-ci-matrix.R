test_that("workflow validation catches matrix drift", {
  config <- readDatabaseTestConfig(path = test_path("fixtures", "database-platforms.yml"))
  workflow <- test_path("fixtures", "pull-request-workflow.yml")

  expect_true(validateDatabaseTestWorkflow(config, workflow))

  parsed <- yaml::read_yaml(workflow)
  parsed$jobs$`database-test`$strategy$matrix$include[[1]]$runner <- "windows-latest"
  expect_error(
    validateDatabaseTestWorkflow(config, parsed),
    class = "panoptes_workflow_drift"
  )
})

test_that("bundled configuration and workflow templates stay aligned", {
  config <- readDatabaseTestConfig(path = system.file(
    "templates",
    "hades-database-platforms.yml",
    package = "Panoptes"
  ))
  workflow <- system.file(
    "templates",
    "database-platform-tests.yml",
    package = "Panoptes"
  )

  expect_true(validateDatabaseTestWorkflow(config, workflow))

  parsed <- yaml::read_yaml(workflow)
  job <- parsed$jobs$`database-test`
  include <- job$strategy$matrix$include
  observedDbms <- vapply(include, `[[`, character(1), "dbms")
  externalPlatforms <- Filter(
    function(platform) {
      platform$enabled && platform$connectionMode != "local"
    },
    config$platforms
  )
  expectedDbms <- vapply(externalPlatforms, `[[`, character(1), "dbms")

  expect_setequal(observedDbms, expectedDbms)
  expect_match(job[["if"]], "github.repository", fixed = TRUE)
  expect_identical(
    job$env$DATABASECONNECTOR_JAR_FOLDER,
    "${{ runner.temp }}/jdbcDrivers"
  )

  actions <- vapply(job$steps, function(step) {
    if (is.null(step$uses)) "" else step$uses
  }, character(1))
  expect_contains(actions, "actions/setup-java@v4")

  driverSteps <- Filter(
    function(step) identical(step$name, "Download JDBC driver"),
    job$steps
  )
  expect_length(driverSteps, 1)
  expect_match(driverSteps[[1]]$run, "downloadJdbcDrivers", fixed = TRUE)

  workflowText <- readLines(workflow, warn = FALSE)
  expect_false(any(grepl("^[[:space:]]+schedule:", workflowText)))
})
