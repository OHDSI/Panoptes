# Verify that a database can be reached

Opens and immediately closes a connection. The context records the
attempt before connecting, so CI can distinguish an exercised job from
an early return even when connection creation fails.

## Usage

``` r
verifyDatabaseTestConnection(context)
```

## Arguments

- context:

  A Panoptes database test context.

## Value

`TRUE`, invisibly, when connection and disconnection succeed.
