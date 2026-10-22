test_that("context creation validates then calls the adapter", {
  config <- makeTestConfig()
  captured <- NULL
  factory <- function(...) {
    captured <<- list(...)
    structure(captured, class = "mock_connection_details")
  }
  withr::with_options(list(Panoptes.connectionDetailsFactory = factory), {
    withr::with_envvar(databaseEnvironment, {
      context <- createDatabaseTestContext(config)
      expect_s3_class(context, "panoptes_database_test_context")
      expect_equal(context$dbms, "postgresql")
      expect_equal(context$cdmDatabaseSchema, "cdm")
      expect_equal(context$vocabularyDatabaseSchema, "vocabulary")
      expect_equal(context$workDatabaseSchema, "work")
      expect_null(context$tempEmulationSchema)
      expect_equal(captured$user, "user")
      expect_equal(captured$password, "password")
      expect_equal(captured$server, "server/database")
    })
  })
})

test_that("passwords are URL decoded for DatabaseConnector", {
  values <- databaseEnvironment
  values[["HADES_DB_PASSWORD"]] <- "p%40ss%2Fword"
  withr::with_options(list(Panoptes.connectionDetailsFactory = mockConnectionDetails), {
    withr::with_envvar(values, {
      context <- createDatabaseTestContext(makeTestConfig())
      expect_equal(context$connectionDetails$password, "p@ss/word")
    })
  })
})

test_that("Spark and Snowflake workarounds are isolated in adapters", {
  spark <- makeTestPlatform(dbms = "spark", connectionMode = "connectionString")
  snowflake <- makeTestPlatform(dbms = "snowflake", connectionMode = "connectionString")
  values <- databaseEnvironment
  values[["HADES_TEST_DBMS"]] <- "spark"
  withr::with_options(list(Panoptes.connectionDetailsFactory = mockConnectionDetails), {
    withr::with_envvar(values, {
      sparkContext <- createDatabaseTestContext(makeTestConfig(list(spark)))
      expect_match(sparkContext$connectionDetails$connectionString, "EnableArrow=0", fixed = TRUE)
    })
    values[["HADES_TEST_DBMS"]] <- "snowflake"
    withr::with_envvar(values, {
      snowflakeContext <- createDatabaseTestContext(makeTestConfig(list(snowflake)))
      expect_match(
        snowflakeContext$connectionDetails$connectionString,
        "JDBC_QUERY_RESULT_FORMAT=JSON",
        fixed = TRUE
      )
    })
  })
})

test_that("withDatabaseTestContext scopes options and temporary key files", {
  platform <- makeTestPlatform(
    dbms = "bigquery",
    required = FALSE,
    connectionMode = "connectionString",
    credentialMode = "keyFile",
    tempEmulationSchema = TRUE,
    runner = "windows-latest",
    os = "any"
  )
  config <- makeTestConfig(list(platform))
  values <- databaseEnvironment
  values[["HADES_TEST_DBMS"]] <- "bigquery"
  values[["HADES_DB_CONNECTION_STRING"]] <- "jdbc:bigquery://server;key=<keyfile path>"
  keyPath <- NULL
  oldOption <- getOption("sqlRenderTempEmulationSchema")
  withr::with_options(list(Panoptes.connectionDetailsFactory = mockConnectionDetails), {
    withr::with_envvar(values, {
      result <- withDatabaseTestContext(config, {
        keyPath <<- sub("^.*key=", "", context$connectionDetails$connectionString)
        expect_true(file.exists(keyPath))
        expect_equal(getOption("sqlRenderTempEmulationSchema"), "work")
        context$dbms
      })
      expect_equal(result, "bigquery")
    })
  })
  expect_false(file.exists(keyPath))
  expect_identical(getOption("sqlRenderTempEmulationSchema"), oldOption)
})

test_that("context printing never includes connection details", {
  withr::with_options(list(Panoptes.connectionDetailsFactory = mockConnectionDetails), {
    withr::with_envvar(databaseEnvironment, {
      context <- createDatabaseTestContext(makeTestConfig())
      output <- capture.output(print(context))
      expect_true(any(grepl("<redacted>", output, fixed = TRUE)))
      expect_false(any(grepl("password", output, fixed = TRUE)))
    })
  })
})

test_that("connection verification records an attempt and disconnects", {
  disconnected <- FALSE
  withr::with_options(
    list(
      Panoptes.connectionDetailsFactory = mockConnectionDetails,
      Panoptes.connect = function(details) list(details = details),
      Panoptes.disconnect = function(connection) disconnected <<- TRUE
    ),
    {
      withr::with_envvar(databaseEnvironment, {
        context <- createDatabaseTestContext(makeTestConfig())
        expect_false(databaseTestConnectionAttempted(context))
        expect_true(verifyDatabaseTestConnection(context))
        expect_true(databaseTestConnectionAttempted(context))
        expect_true(disconnected)
        expect_true(requireDatabaseTestConnectionAttempted(context))
      })
    }
  )
})

test_that("adapter and connection errors do not expose credentials", {
  secret <- "secret-password-and-connection-string"
  values <- databaseEnvironment
  values[["HADES_DB_PASSWORD"]] <- secret
  withr::with_envvar(values, {
    withr::with_options(
      list(Panoptes.connectionDetailsFactory = function(...) stop(secret)),
      {
        condition <- expect_error(
          createDatabaseTestContext(makeTestConfig()),
          class = "panoptes_connection_details_error"
        )
        expect_false(grepl(secret, condition$message, fixed = TRUE))
      }
    )

    withr::with_options(list(Panoptes.connectionDetailsFactory = mockConnectionDetails), {
      context <- createDatabaseTestContext(makeTestConfig())
      withr::with_options(list(Panoptes.connect = function(details) stop(secret)), {
        condition <- expect_error(
          verifyDatabaseTestConnection(context),
          class = "panoptes_connection_error"
        )
        expect_false(grepl(secret, condition$message, fixed = TRUE))
        expect_true(databaseTestConnectionAttempted(context))
      })
    })
  })
})

test_that("incompatible required CI runners fail", {
  incompatible <- makeTestPlatform(os = if (.Platform$OS.type == "windows") "linux" else "windows")
  values <- databaseEnvironment
  values[["HADES_DATABASE_TEST"]] <- "true"
  withr::with_envvar(values, {
    expect_error(
      createDatabaseTestContext(makeTestConfig(list(incompatible))),
      class = "panoptes_incompatible_platform"
    )
  })
})
