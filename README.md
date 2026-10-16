# Conflict & political-risk research (monorepo)

Shared data pipelines plus independent research projects built on top of them.

```
.
├── data/          ← shared DuckDB (panel.duckdb) + raw downloads (gitignored) + curated supplements
├── pipelines/     ← shared R/Quarto loaders, one source per notebook (00–07) + _helpers.R
└── projects/
    ├── scenario-risk-calculator/   ← 12-month mobilization / armed-violence risk model + dashboard
    └── beautiful-century/          ← testing the democratic-peace / abundance-peace thesis
```

## How the pieces fit

**Pipelines** pull and tidy data. Each loader writes standard
`(iso3c, year)` tables into `data/panel.duckdb` and makes no modelling
choices. Run them once, then any project can read the same tables.

**Projects** own everything specific to one question: feature engineering,
outcome labels, models, outputs, and any web front end. A project reads
the shared tables and writes its own tables, prefixed by project (for example
`bc_` for beautiful-century, or the existing `panel_*` tables for the risk calculator).

| Project | Question | Status |
|---|---|---|
| [scenario-risk-calculator](projects/scenario-risk-calculator/README.md) | What is each country's 12-month probability of mass mobilization and of armed violence or a coup? | v0.7.2, dashboard on GitHub Pages |
| [beautiful-century](projects/beautiful-century/README.md) | Is peace among rich democracies real, and is it spreading? | Started; test 3 (democratic ratchet) drafted |

## Quick start

```r
install.packages(c("DBI", "duckdb", "ggplot2", "remotes", "WDI", "httr2",
                   "jsonlite", "countrycode", "readxl", "haven", "glmnet"))
remotes::install_github("vdeminstitute/vdemdata")
```

```sh
cd pipelines && quarto render                 # build data/panel.duckdb
cd ../projects/<project>/analysis && quarto render
```

See [`pipelines/README.md`](pipelines/README.md) for the loader list and
[`data/README.md`](data/README.md) for manual downloads.

## Adding things

- **A new data source** (usable by more than one project) goes in
  `pipelines/` as the next numbered loader.
- **A new project** goes in `projects/<name>/`, with its own `README.md`
  and `analysis/`. It reads `../../../data/panel.duckdb` and sources
  `../../../pipelines/_helpers.R`.

## Licensing note

ACLED data cannot be redistributed. The raw files are gitignored; only
country-year aggregates and derived flags are committed.
