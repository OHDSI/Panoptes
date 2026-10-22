# Contributing to Panoptes

Panoptes changes should preserve a small, test-support-focused API. New
public extension points should be driven by at least two consuming HADES
packages.

Before opening a pull request:

``` r

devtools::document()
devtools::test()
devtools::check()
lintr::lint_package()
```

Do not add real credentials, server names, connection strings, or
writable schemas to fixtures. Adapter tests must inject a
connection-details factory and must not require JDBC downloads or a live
database. Error and print tests should verify that credential values
cannot appear in output.

Configuration changes must update all three normative artifacts
together:

1.  [`validateDatabaseTestConfig()`](https://ohdsi.github.io/Panoptes/reference/validateDatabaseTestConfig.md);
2.  `inst/schema/hades-database-platforms.schema.json`; and
3.  `inst/templates/hades-database-platforms.yml`.

Package-specific behavior, fixtures, and database-object cleanup belong
in the consuming package rather than Panoptes.
