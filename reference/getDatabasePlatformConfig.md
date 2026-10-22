# Get one database platform declaration

Get one database platform declaration

## Usage

``` r
getDatabasePlatformConfig(
  config,
  dbms = Sys.getenv("HADES_TEST_DBMS", unset = "")
)
```

## Arguments

- config:

  A database test configuration.

- dbms:

  DBMS name or alias. Defaults to the selected DBMS.

## Value

A platform mapping, or `NULL` when no DBMS is selected.
