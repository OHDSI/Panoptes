test_that("CI matrices are derived from declared tiers", {
  config <- readDatabaseTestConfig(path = test_path("fixtures", "database-platforms.yml"))

  pullRequest <- getDatabaseTestMatrix(config, "pull-request")
  scheduled <- getDatabaseTestMatrix(config, "scheduled")

  expect_equal(pullRequest$dbms, "postgresql")
  expect_equal(pullRequest$runner, "ubuntu-latest")
  expect_equal(scheduled$dbms, "bigquery")
  expect_equal(scheduled$runner, "windows-latest")
})

test_that("workflow validation catches matrix drift", {
  config <- readDatabaseTestConfig(path = test_path("fixtures", "database-platforms.yml"))
  workflow <- test_path("fixtures", "pull-request-workflow.yml")

  expect_true(validateDatabaseTestWorkflow(config, workflow, "pull-request"))

  parsed <- yaml::read_yaml(workflow)
  parsed$jobs$`database-test`$strategy$matrix$include[[1]]$runner <- "windows-latest"
  expect_error(
    validateDatabaseTestWorkflow(config, parsed, "pull-request"),
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

  expect_true(validateDatabaseTestWorkflow(config, workflow, "pull-request"))
})
