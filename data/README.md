# data

Raw sources and the DuckDB panel database. **Contents are gitignored** — too large to commit and licenses vary per source.

```
data/
├── raw/         # downloaded CSVs from V-Dem, WDI, ACLED, MMP, P&B, de Bruin
└── panel.duckdb # built by training/02_build_panel.qmd
```

## Re-creating the data folder

See `training/01_load_sources.qmd` for the canonical pull order. Free academic registration required for ACLED.
