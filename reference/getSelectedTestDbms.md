# Resolve the selected database platform

Resolve the selected database platform

## Usage

``` r
getSelectedTestDbms(config, value = Sys.getenv("HADES_TEST_DBMS", unset = ""))
```

## Arguments

- config:

  A database test configuration.

- value:

  Selection value, normally `HADES_TEST_DBMS`.

## Value

A canonical DBMS name, or `NULL` when no DBMS is selected.
