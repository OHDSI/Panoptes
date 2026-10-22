# Validate a resolved database test environment

In a required explicit live-database job, missing values are errors. In
local development and optional CI jobs they are test skips. Validation
is deliberately completed before connection details or temporary
credentials are created.

## Usage

``` r
validateDatabaseTestEnvironment(platform, environment, strict = NULL)
```

## Arguments

- platform:

  A validated platform mapping.

- environment:

  An object returned by
  [`resolveDatabaseTestEnvironment()`](https://ohdsi.github.io/Panoptes/reference/resolveDatabaseTestEnvironment.md).

- strict:

  Whether missing values are errors. The default combines
  `HADES_DATABASE_TEST` with the platform's `required` policy.

## Value

`TRUE`, invisibly, or a skip/error condition.
