# Create a collision-resistant database object name

Create a collision-resistant database object name

## Usage

``` r
createUniqueDatabaseObjectName(prefix, maxLength = NULL)
```

## Arguments

- prefix:

  Human-readable prefix. Invalid characters are converted to underscores
  and a leading letter is enforced.

- maxLength:

  Maximum identifier length. When omitted, a conservative 63-character
  limit is used.

## Value

A lower-case database identifier.
