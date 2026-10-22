# Validate a database test declaration

Validation is normative even when the bundled JSON Schema is used by an
editor. Unknown fields are rejected so configuration cannot silently
become descriptive rather than executable.

## Usage

``` r
validateDatabaseTestConfig(config, package = NULL)
```

## Arguments

- config:

  Parsed YAML configuration.

- package:

  Optional expected package name.

## Value

`config`, invisibly, with normalized canonical DBMS values and class
`panoptes_database_test_config`.
