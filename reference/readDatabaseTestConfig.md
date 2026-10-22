# Read a database test declaration

Locates, reads, and validates a consumer package's
`inst/test-config/hades-database-platforms.yml` declaration. An explicit
`path` is recommended in tooling. During package tests, Panoptes can
locate a source package by walking upward from the working directory.

## Usage

``` r
readDatabaseTestConfig(package = NULL, path = NULL)
```

## Arguments

- package:

  Optional installed package name, package source directory, or expected
  package name.

- path:

  Optional path to the YAML declaration.

## Value

A validated database test configuration with class
`panoptes_database_test_config`.
