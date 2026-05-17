# training — R + Quarto pipeline

Offline R+Quarto pipeline. Loads sources into a single DuckDB file, joins
through a country master, fits a regime-stratified logistic regression, and
exports JSON artifacts the static dashboard consumes.

## Bootstrap

Install R, Quarto, and the R packages:

```r
install.packages(c("DBI", "duckdb", "ggplot2", "remotes", "WDI",
                   "httr2", "jsonlite", "countrycode"))
remotes::install_github("vdeminstitute/vdemdata")
```

For ACLED (when access arrives): register at https://acleddata.com/ and
request Research-tier API access — gmail/personal-email accounts get the
Open tier which has no API. Store creds in `~/.Renviron` (on Windows that's
`Documents\.Renviron`, not the user profile root):

```
ACLED_EMAIL=your_email
ACLED_PASSWORD=your_password
```

## Pipeline

One source per notebook. Each lands a single named table in
`../data/panel.duckdb`. Notebooks are independent after first run — re-render
any single one to refresh its table.

| Step | Notebook | Lands table | Status |
|---|---|---|---|
| 0 | `00_load_countries.qmd` | `countries` | ✅ master reference table |
| 1 | `01_load_vdem.qmd` | `vdem` | ✅ V-Dem v16, ~28K country-years |
| 2 | `02_load_wdi.qmd` | `wdi` | ✅ World Bank WDI, ~9.5K country-years |
| 3 | `03_load_acled.qmd` | `acled_events` | ⏳ blocked on Research-tier API access |
| 4 | `04_load_unhcr.qmd` | `unhcr` | ✅ ~6.5K origin-years |
| 5 | `05_load_fao.qmd` | `fao` | ✅ 436 months of FFPI |
| 6 | `06_load_pb.qmd` | `pb_counterbalancing` | ⏳ manual Harvard Dataverse download |
| 7 | `07_load_debruin.qmd` | `security_forces` | ⏳ manual PRIO replication download |
| 8 | `08_build_panel.qmd` | `panel_features` | ✅ joins V-Dem+WDI+UNHCR+FAO; within-country z-scores |
| 9 | `09_label_events.qmd` | `panel_labeled` | ✅ outcome: V-Dem `v2cagenmob_ord >= 2` at year+1 |
| 10 | `10_fit_model.qmd` | `data/model/fit.rds` | ✅ logistic regression × 4 regime strata |
| 11 | `11_calibration.qmd` | `data/model/calibration.rds` | ✅ Brier, log loss, reliability on 2023 holdout |
| 12 | `12_export_artifacts.qmd` | `../artifacts/*.json` | ✅ weights, base rates, snapshot, calibration |

## Outcome variable (v0)

V-Dem's `v2cagenmob_ord` is the "mass-mobilization concept" ordinal: 0 = none,
1 = few sporadic events, 2 = several major events, 3 = many large events.
We use the **next year's** value (LEAD window function), thresholded `>= 2`
to mark "mass mobilization happened at notable scale next year."

When ACLED comes online we'll switch to event-derived counts at higher
resolution — replace the outcome chunk in `09_label_events.qmd` without
touching anything else.

## Features (z-scored within country)

| z-feature | Raw column | Source |
|---|---|---|
| `z_civil_liberties` | `v2x_civlib` | V-Dem |
| `z_freedom_expression` | `v2x_freexp_altinf` | V-Dem |
| `z_gdp_growth` | `gdp_growth` | WDI |
| `z_refugee_outflow` | `refugees + asylum_seekers` | UNHCR |
| `z_political_violence_ord` | `v2caviol_ord` | V-Dem |
| `z_ffpi_avg` | `ffpi_avg` (annualized) | FAO |

Z-scoring is **within-country** — each country's shock is measured relative
to its own history rather than a global benchmark. That makes a 5% GDP
contraction equally salient whether it happens to a country normally at +1%
or +6% baseline.

## Rendering

Single notebook:

```sh
quarto render 04_load_unhcr.qmd
```

All notebooks in order:

```sh
quarto render
```

(Or run via `Ctrl+Shift+K` from an RStudio session — same effect.)

## Files written outside `training/`

| Path | Written by | What |
|---|---|---|
| `../data/panel.duckdb` | every loader | The panel database (~250 MB) |
| `../data/raw/*.csv` | manual + 05 | Persisted raw downloads (FAO, P-B, de Bruin) |
| `../data/model/fit.rds` | 10 | Pickled fitted models |
| `../data/model/calibration.rds` | 11 | Calibration metrics |
| `../artifacts/*.json` | 12 | Frozen dashboard artifacts (committed) |
