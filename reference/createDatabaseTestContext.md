# Create a database test context

The returned context is constructed only after configuration, platform,
compatibility, and environment validation succeeds. It does not connect
to the database eagerly. Prefer
[`withDatabaseTestContext()`](https://ohdsi.github.io/Panoptes/reference/withDatabaseTestContext.md)
when temporary credentials may be required.

## Usage

``` r
createDatabaseTestContext(config, dbms = NULL, legacyAliases = NULL)
```

## Arguments

- config:

  A database test configuration.

- dbms:

  Optional DBMS selection. Defaults to `HADES_TEST_DBMS`.

- legacyAliases:

  Explicit normalized-to-legacy environment aliases.

## Value

A `panoptes_database_test_context` object.
