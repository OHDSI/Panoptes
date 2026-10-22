# List configured database platforms

List configured database platforms

## Usage

``` r
getConfiguredDatabasePlatforms(config, enabled = TRUE)
```

## Arguments

- config:

  A validated configuration or path/package input accepted by
  [`readDatabaseTestConfig()`](https://ohdsi.github.io/Panoptes/reference/readDatabaseTestConfig.md).

- enabled:

  Whether to return enabled (`TRUE`), disabled (`FALSE`), or all
  (`NULL`) platforms.

## Value

A list of platform mappings.
