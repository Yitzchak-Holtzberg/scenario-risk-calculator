# training — R + Quarto pipeline

Offline pipeline. Builds the country-month panel in DuckDB, fits a regime-stratified logistic regression, bootstraps confidence intervals, and emits frozen artifacts to `../artifacts/`.

## Bootstrap

Install R, RStudio, Quarto, and the DuckDB CLI.

In RStudio, open `training.Rproj` (created on first run) and run:

```r
install.packages(c("duckdb", "DBI", "vdemdata", "WDI", "tidyverse", "boot", "yardstick"))
```

For ACLED, register for an academic key at https://acleddata.com/ and store in `~/.Renviron`:

```
ACLED_EMAIL=your_email
ACLED_KEY=your_key
```

## Pipeline

1. `01_load_sources.qmd` — pull V-Dem / WDI / ACLED / MMP / P&B / de Bruin into DuckDB.
2. `02_build_panel.qmd` — join into country-month panel; compute within-country z-scores.
3. `03_label_events.qmd` — apply resolution rules; emit event label per (country, month).
4. `04_fit_model.qmd` — `glm()` stratified by V-Dem RoW; bootstrap CIs.
5. `05_calibration.qmd` — Brier, log loss, reliability diagram on 2019–2024 holdout.
6. `06_export_artifacts.qmd` — write `weights.json`, `base_rates.json`, `country_snapshot.json`, `calibration.json`, render `model-card.html`.

Run end-to-end via `quarto render`.
