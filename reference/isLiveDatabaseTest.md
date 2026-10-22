# Detect explicit live-database test mode

Detect explicit live-database test mode

## Usage

``` r
isLiveDatabaseTest(value = Sys.getenv("HADES_DATABASE_TEST", unset = "false"))
```

## Arguments

- value:

  Value to interpret, normally `HADES_DATABASE_TEST`.

## Value

A logical scalar.
