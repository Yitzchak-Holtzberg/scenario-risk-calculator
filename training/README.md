# training — R + Quarto pipeline

Offline pipeline. Builds the country-month panel in DuckDB, fits a regime-stratified logistic regression, bootstraps confidence intervals, and emits frozen artifacts to `../artifacts/`.

## Bootstrap

Install R, RStudio, Quarto, and the DuckDB CLI (handled at the repo level).

In RStudio, run:

```r
install.packages(c("DBI", "duckdb", "ggplot2", "remotes", "WDI", "httr2", "jsonlite", "readxl", "boot", "yardstick"))
remotes::install_github("vdeminstitute/vdemdata")
```

For ACLED, register at https://acleddata.com/ and request Research-tier API access (gmail/personal-email accounts default to Open tier which has no API). The new ACLED auth uses OAuth password-grant with your account email + password — store both in `~/.Renviron`:

```
ACLED_EMAIL=your_email
ACLED_PASSWORD=your_password
```

On Windows, `.Renviron` lives at `Documents\.Renviron`, not the user-profile root.

## Pipeline

Each source is loaded by its own notebook into `data/panel.duckdb`. Run them in order on first setup; afterward they're independent and only need to be re-run when the upstream data refreshes.

One source per notebook — clean failure isolation and independent re-renders. Each lands a single named table in `data/panel.duckdb`.

| Step | Notebook | Purpose | Status |
|---|---|---|---|
| 1 | `01_load_vdem.qmd` | V-Dem v16 via `vdemdata` — regime classification + political covariates | ✅ |
| 2 | `02_load_wdi.qmd` | World Bank WDI — economic covariates (CPI, GDP growth, GDP/capita, trade, unemployment) | ✅ |
| 3 | `03_load_acled.qmd` | ACLED — protest / unrest event data | ⏳ blocked on Research-tier API access |
| 4 | `04_load_unhcr.qmd` | UNHCR refugee population — origin-side refugee + asylum-seeker counts | |
| 5 | `05_load_fao.qmd` | FAO Food Price Index — global monthly index of food commodity prices | |
| 6 | `06_load_pb.qmd` | Pilster–Böhmelt counterbalancing / coup-proofing (manual Harvard Dataverse download) | |
| 7 | `07_load_debruin.qmd` | de Bruin State Security Forces 1960–2010 (manual PRIO replication download) | |
| 8 | `08_build_panel.qmd` | Join all sources into country-month panel; within-country z-scores | |
| 9 | `09_label_events.qmd` | Apply sustained-mass-unrest resolution rules | |
| 10 | `10_fit_model.qmd` | `glm()` stratified by V-Dem RoW regime category; bootstrap CIs | |
| 11 | `11_calibration.qmd` | Brier, log loss, reliability on 2019–2024 holdout | |
| 12 | `12_export_artifacts.qmd` | Emit JSON artifacts + render `model-card.html` | |

Render any single notebook in RStudio with `Ctrl+Shift+K`, or render everything via `quarto render` from this folder.
