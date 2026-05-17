# training — R + Quarto pipeline

Offline R+Quarto pipeline. Loads sources into a single DuckDB file, joins
through a country master, fits regularized logistic regressions, and
exports JSON artifacts the static dashboard consumes.

## Bootstrap

Install R, Quarto, and the R packages:

```r
install.packages(c("DBI", "duckdb", "ggplot2", "remotes", "WDI",
                   "httr2", "jsonlite", "countrycode", "readxl", "haven"))
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

| Step | Notebook | Lands table(s) | Status |
|---|---|---|---|
| 0 | `00_load_countries.qmd` | `countries` | ✅ master reference table |
| 1 | `01_load_vdem.qmd` | `vdem` | ✅ V-Dem v16, ~28K country-years |
| 2 | `02_load_wdi.qmd` | `wdi` | ✅ World Bank WDI |
| 2b | `02b_load_inflation_supplements.qmd` | `imf_inflation` | ✅ Hanke + IMF WEO backfill for WDI inflation gaps |
| 3a | `03a_load_mmp.qmd` | `mmp_annual` | ✅ Mass Mobilization Project (large-protest counts) |
| 3b | `03b_load_ucdp.qmd` | `ucdp_annual` | ✅ UCDP GED v25.1 — fatalities aggregated to country-year |
| 3c | `03c_load_coups.qmd` | `coups_annual` | ✅ Cline Center coups (realized + attempted) |
| 3d | `03d_load_fariss.qmd` | `fariss` | ✅ latent HR scores; loaded, excluded from current fit |
| 3e | `03e_load_polity.qmd` | `polity` | ✅ Polity5 polity2; loaded, excluded from current fit |
| 4 | `04_load_unhcr.qmd` | `unhcr` | ✅ ~6.5K origin-years |
| 5 | `05_load_fao.qmd` | `fao` | ✅ 436+ months of FFPI |
| 6 | `06_load_pb.qmd` | `pb_counterbalancing` | ✅ Pilster-Böhmelt (manual Harvard Dataverse download) |
| 7 | `07_load_debruin.qmd` | `security_forces` | ✅ de Bruin SSF 1960–2010 (manual PRIO replication download); loaded, excluded from current fit |
| 8 | `08_build_panel.qmd` | `panel_features` | ✅ joins all sources; within-country z-scores; region-median imputation |
| 9 | `09_label_events.qmd` | `panel_labeled` | ✅ multi-source outcome fusion |
| 10 | `10_fit_model.qmd` | `data/model/fit.rds` | ✅ pooled ridge + per-regime context models |
| 11 | `11_calibration.qmd` | `data/model/calibration.rds` | ✅ Brier, log loss, reliability on 2023 holdout |
| 12 | `12_export_artifacts.qmd` | `../artifacts/*.json` | ✅ weights, base rates, snapshot, calibration, hanke inflation |

## Outcome variable (v0)

Multi-source fusion. For each (country, year), look at **next year's events**
across four independent sources. Flag the country-year as unrest if **any**
threshold fires:

| Source | Threshold | Captures |
|---|---|---|
| Cline Center coups | `n_realized + n_attempted >= 1` | Regime-change attempts |
| UCDP GED | `fatalities_best >= 100` next year | Organized armed-violence episodes |
| MMP large protests | `n_large_protests >= 1` next year (≥1,000 participants) | Sustained mass mobilization at scale |
| V-Dem (post-2020 fallback) | `v2cagenmob_ord >= 4` next year | Bridges the MMP coverage cutoff (2020) |

Earlier v0 attempts used V-Dem `v2cagenmob_ord >= 2` alone, which produced
flat base rates (47–60% across regimes) because the ordinal is too broad.
Event-based sources are sparser and more specific — they let
closed-autocracy and liberal-democracy rates diverge as they should.

When ACLED comes online we'll replace MMP + UCDP with ACLED event counts —
edit `09_label_events.qmd` without touching anything else.

## Features used in the current model

Hybrid spec — `civil_liberties` enters as a **level** (so the model knows
where a country sits structurally). Additional structural anchors enter as
levels; dynamic stress features enter as **within-country z-scores** so the
model sees shocks relative to each country's own history.

| Feature | Type | Source | Notes |
|---|---|---|---|
| `civil_liberties` | Level (0–1) | V-Dem `v2x_civlib` | Structural |
| `log_gdp_per_cap` | Level | WDI `gdp_per_cap` | Development anchor |
| `loser_consent` | Level (0–4 ordinal) | V-Dem `v2elaccept_ord` | Factionalism / loser acceptance |
| `conflict_neighbors_count` | Level count | UCDP + region approximation | Conflict-ridden neighborhood proxy |
| `z_gdp_growth` | Within-country z | WDI `gdp_growth` | Economic shock |
| `z_cpi_inflation` | Within-country z | WDI + Hanke + IMF | Region-median imputed when source-missing |
| `z_unemployment` | Within-country z | WDI `unemployment` | Region-median imputed when source-missing |
| `z_political_violence_ord` | Within-country z | V-Dem `v2caviol_ord` | |
| `z_refugee_outflow` | Within-country z | UNHCR (`refugees + asylum_seekers`, log1p first) | |
| `z_ffpi_avg` | Global z | FAO FFPI annual avg | Same value for all countries in a year |
| `z_coup_proof_fragmentation` | Within-country z | Pilster-Böhmelt effective-number of forces | |

**Loaded into the panel but excluded from the current fit**:

- `freedom_expression` (V-Dem) — collinear with `civil_liberties`
- Fariss latent HR scores — collinear with `civil_liberties`
- Polity5 `polity2` — collinear with `civil_liberties`
- de Bruin counterbalancing / politicization — coverage ends 2010, forces too many listwise drops

Z-scoring is **within-country** with NA-safe winsorization at ±3 SDs (see
`_helpers.R::z_within`). The dashboard mirrors the same bound via
`weights.winsorize_bound` — single source of truth.

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

## Shared helpers

`_helpers.R` is sourced from each notebook's setup chunk:

- `srs_palette` — colour constants matching the dashboard parchment palette
- `srs_theme()` — ggplot theme block used in every plot-bearing notebook
- `z_within(x)` — within-country z-score, NA-safe, winsorized at `SRS_WINSORIZE_BOUND` (3)
- `cow_to_iso3(x)` — countrycode wrapper, COW numeric → ISO3 alpha-3

## Files written outside `training/`

| Path | Written by | What |
|---|---|---|
| `../data/panel.duckdb` | every loader | The panel database |
| `../data/raw/*` | manual + loaders | Persisted raw downloads (FAO, MMP, UCDP, P-B, de Bruin, Fariss, Polity5, Cline coups) |
| `../data/model/fit.rds` | 10 | Fitted models (RDS) |
| `../data/model/calibration.rds` | 11 | Calibration metrics |
| `../artifacts/*.json` | 12 | Frozen dashboard artifacts (committed) |
