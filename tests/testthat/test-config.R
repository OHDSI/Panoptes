test_that("configuration is read and normalized", {
  path <- test_path("fixtures", "database-platforms.yml")
  config <- readDatabaseTestConfig(path = path)

  expect_s3_class(config, "panoptes_database_test_config")
  expect_equal(config$package, "ExamplePackage")
  expect_equal(config$platforms[[1]]$dbms, "postgresql")
  expect_true(nzchar(attr(config, "path")))
})

test_that("source package roots are supported explicitly", {
  root <- tempfile("panoptes-consumer-")
  dir.create(file.path(root, "inst", "test-config"), recursive = TRUE)
  writeLines(
    c(
      "Package: ExamplePackage",
      "Version: 0.0.1"
    ),
    file.path(root, "DESCRIPTION")
  )
  file.copy(
    test_path("fixtures", "database-platforms.yml"),
    file.path(root, "inst", "test-config", "hades-database-platforms.yml")
  )
  withr::defer(unlink(root, recursive = TRUE, force = TRUE))

  expect_equal(readDatabaseTestConfig(package = root)$package, "ExamplePackage")
})

test_that("source package roots are discovered by package name", {
  root <- tempfile("panoptes-consumer-")
  testDirectory <- file.path(root, "tests", "testthat")
  dir.create(testDirectory, recursive = TRUE)
  dir.create(file.path(root, "inst", "test-config"), recursive = TRUE)
  writeLines(
    c(
      "Package: ExamplePackage",
      "Version: 0.0.1"
    ),
    file.path(root, "DESCRIPTION")
  )
  file.copy(
    test_path("fixtures", "database-platforms.yml"),
    file.path(root, "inst", "test-config", "hades-database-platforms.yml")
  )
  withr::defer(unlink(root, recursive = TRUE, force = TRUE))
  withr::local_dir(testDirectory)

  expect_equal(
    readDatabaseTestConfig(package = "ExamplePackage")$package,
    "ExamplePackage"
  )
})

test_that("top-level configuration rules are enforced", {
  config <- unclass(makeTestConfig())

  bad <- config
  bad$schemaVersion <- 2
  expect_error(validateDatabaseTestConfig(bad), "schemaVersion")

  bad <- config
  bad$extra <- TRUE
  expect_error(validateDatabaseTestConfig(bad), "Unknown top-level")

  bad <- config
  bad$platforms <- list()
  expect_error(validateDatabaseTestConfig(bad), "must not be empty")

  bad <- config
  bad$databaseConnection <- "none"
  expect_error(validateDatabaseTestConfig(bad), "must be empty")
})

test_that("platform fields and cross-field rules are enforced", {
  config <- unclass(makeTestConfig())

  bad <- config
  bad$platforms[[1]]$runner <- NULL
  expect_error(validateDatabaseTestConfig(bad), "missing field")

  bad <- config
  bad$platforms[[1]]$ci <- "pull-request"
  expect_error(validateDatabaseTestConfig(bad), "unknown field")

  bad <- config
  bad$platforms[[1]]$enabled <- FALSE
  bad$platforms[[1]]$required <- FALSE
  expect_error(validateDatabaseTestConfig(bad), "must provide `reason`")

  bad <- config
  bad$platforms <- c(bad$platforms, bad$platforms)
  expect_error(validateDatabaseTestConfig(bad), "Duplicate")

  bad <- config
  bad$platforms[[1]]$credentialMode <- "keyFile"
  expect_error(validateDatabaseTestConfig(bad), "requires `connectionMode")
})

test_that("SQLite and DuckDB are the supported local platforms", {
  duckdb <- makeTestPlatform(
    dbms = "duckdb",
    connectionMode = "local",
    credentialMode = "none"
  )
  expect_s3_class(makeTestConfig(list(duckdb)), "panoptes_database_test_config")

  bad <- duckdb
  bad$connectionMode <- "server"
  expect_error(makeTestConfig(list(bad)), "duckdb must use `connectionMode: local`")

  bad <- makeTestPlatform(connectionMode = "local", credentialMode = "none")
  expect_error(makeTestConfig(list(bad)), "Only SQLite and DuckDB")
})

test_that("databaseConnection all requires all supported adapters", {
  config <- unclass(makeTestConfig())
  config$databaseConnection <- "all"
  expect_error(validateDatabaseTestConfig(config), "requires every Panoptes platform")
})

test_that("the bundled consumer template remains valid", {
  template <- system.file(
    "templates",
    "hades-database-platforms.yml",
    package = "Panoptes"
  )
  config <- readDatabaseTestConfig(path = template)

  expect_equal(config$databaseConnection, "all")
  expect_length(config$platforms, 10)
  expect_contains(
    vapply(config$platforms, `[[`, character(1), "dbms"),
    "duckdb"
  )
})

test_that("configured platforms filter on enabled state", {
  disabled <- makeTestPlatform(
    dbms = "iris",
    enabled = FALSE,
    required = FALSE,
    connectionMode = "connectionString"
  )
  disabled$reason <- "Not supported by this package"
  config <- makeTestConfig(list(
    makeTestPlatform(),
    makeTestPlatform(dbms = "oracle"),
    disabled
  ))

  expect_length(getConfiguredDatabasePlatforms(config), 2)
  expect_length(getConfiguredDatabasePlatforms(config, enabled = FALSE), 1)
})
