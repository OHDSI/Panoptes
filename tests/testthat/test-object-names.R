test_that("unique database object names are portable", {
  first <- createUniqueDatabaseObjectName("Cohort Test!", maxLength = 30)
  second <- createUniqueDatabaseObjectName("Cohort Test!", maxLength = 30)

  expect_match(first, "^[a-z][a-z0-9_]+$")
  expect_lte(nchar(first), 30)
  expect_false(identical(first, second))
})
