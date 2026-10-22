test_that("selected DBMS names and aliases are canonicalized", {
  config <- makeTestConfig(list(makeTestPlatform(dbms = "sql server")))

  expect_equal(getSelectedTestDbms(config, " SQLServer "), "sql server")
  expect_equal(getDatabasePlatformConfig(config, "mssql")$dbms, "sql server")
  expect_null(getSelectedTestDbms(config, ""))
})

test_that("undeclared and disabled platforms fail clearly", {
  config <- makeTestConfig()
  expect_error(getSelectedTestDbms(config, "oracle"), class = "panoptes_platform_not_declared")

  disabled <- makeTestPlatform(enabled = FALSE, required = FALSE)
  disabled$reason <- "Deliberately disabled"
  config <- makeTestConfig(list(disabled))
  expect_error(getSelectedTestDbms(config, "postgresql"), class = "panoptes_platform_disabled")
})

test_that("live mode accepts common true values", {
  expect_true(isLiveDatabaseTest("true"))
  expect_true(isLiveDatabaseTest("YES"))
  expect_false(isLiveDatabaseTest("false"))
})
