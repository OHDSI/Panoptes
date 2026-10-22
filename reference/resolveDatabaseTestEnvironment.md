# Resolve the normalized database test environment

Normalized `HADES_*` variables always take precedence. `aliases` allows
a consumer to explicitly map historical variable names during migration.
Values are retained for connection construction but are never shown by
the print method.

## Usage

``` r
resolveDatabaseTestEnvironment(platform, aliases = NULL)
```

## Arguments

- platform:

  A platform mapping returned by
  [`getDatabasePlatformConfig()`](https://ohdsi.github.io/Panoptes/reference/getDatabasePlatformConfig.md).

- aliases:

  Optional named character vector or list. Names are normalized
  `HADES_*` variables and values are legacy environment-variable names.

## Value

A `panoptes_database_test_environment` object.
