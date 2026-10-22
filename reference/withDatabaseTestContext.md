# Evaluate code with a scoped database test context

The expression can refer to `context`. Package-owned temporary
credential files and the `sqlRenderTempEmulationSchema` option are
restored when the call exits, including after an error. If the
expression evaluates to a function, that function is called with the
context as its only argument.

## Usage

``` r
withDatabaseTestContext(
  config,
  code,
  dbms = NULL,
  legacyAliases = NULL,
  verify = FALSE
)
```

## Arguments

- config:

  A database test configuration.

- code:

  Code to evaluate, or a function accepting one context argument.

- dbms:

  Optional DBMS selection.

- legacyAliases:

  Explicit legacy environment aliases.

- verify:

  Whether to verify a live connection before evaluating `code`.

## Value

The value produced by `code`.
