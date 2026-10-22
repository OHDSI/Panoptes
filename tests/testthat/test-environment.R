test_that("normalized environment values take precedence over aliases", {
  platform <- makeTestPlatform()
  withr::with_envvar(
    c(databaseEnvironment, LEGACY_USER = "legacy-user"),
    {
      environment <- resolveDatabaseTestEnvironment(
        platform,
        aliases = c(HADES_DB_USER = "LEGACY_USER")
      )
      expect_equal(environment$values$HADES_DB_USER, "user")
      expect_equal(environment$sources[["HADES_DB_USER"]], "HADES_DB_USER")
    }
  )
})

test_that("legacy aliases and schema fallbacks are explicit", {
  platform <- makeTestPlatform()
  values <- databaseEnvironment
  values[["HADES_DB_USER"]] <- NA_character_
  values[["HADES_VOCABULARY_SCHEMA"]] <- NA_character_
  values <- c(values, LEGACY_USER = "legacy-user")
  withr::with_envvar(values, {
    environment <- resolveDatabaseTestEnvironment(
      platform,
      aliases = list(HADES_DB_USER = c("LEGACY_USER"))
    )
    expect_equal(environment$values$HADES_DB_USER, "legacy-user")
    expect_equal(environment$values$HADES_VOCABULARY_SCHEMA, "cdm")
  })
})

test_that("environment printing redacts values", {
  withr::with_envvar(databaseEnvironment, {
    environment <- resolveDatabaseTestEnvironment(makeTestPlatform())
    output <- capture.output(print(environment))
    expect_true(any(grepl("HADES_DB_PASSWORD: <set>", output, fixed = TRUE)))
    expect_false(any(grepl("password", output, fixed = TRUE)))
    expect_false(any(grepl("server/database", output, fixed = TRUE)))
  })
})

test_that("missing variables skip locally and fail required CI", {
  platform <- makeTestPlatform(required = TRUE)
  empty <- setNames(rep(NA_character_, length(databaseEnvironment)), names(databaseEnvironment))
  withr::with_envvar(empty, {
    environment <- resolveDatabaseTestEnvironment(platform)
    expect_condition(
      validateDatabaseTestEnvironment(platform, environment, strict = FALSE),
      class = "skip"
    )
    expect_error(
      validateDatabaseTestEnvironment(platform, environment, strict = TRUE),
      class = "panoptes_missing_environment"
    )
  })
})

test_that("optional platforms skip even in live CI", {
  platform <- makeTestPlatform(required = FALSE)
  empty <- setNames(rep(NA_character_, length(databaseEnvironment)), names(databaseEnvironment))
  empty[["HADES_DATABASE_TEST"]] <- "true"
  withr::with_envvar(empty, {
    environment <- resolveDatabaseTestEnvironment(platform)
    expect_condition(
      validateDatabaseTestEnvironment(platform, environment),
      class = "skip"
    )
  })
})
