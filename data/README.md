# data

Raw sources and the DuckDB panel database. **Contents are gitignored** — too
large to commit and licenses vary per source.

```
data/
├── raw/         # downloaded source files (V-Dem and WDI pulled via R packages, not stored here)
├── model/       # fitted models + calibration metrics (RDS, written by training/10 + 11)
├── curated/     # hand-curated reference files (committed)
└── panel.duckdb # built incrementally by training/00–08 (~250 MB after full run)
```

## Raw sources

| File / dir in `raw/` | Source | Loaded by | Acquisition |
|---|---|---|---|
| *(none — pulled via `vdemdata` package)* | V-Dem v16 | `01_load_vdem.qmd` | Auto via R package |
| *(none — pulled via `WDI` package)* | World Bank WDI | `02_load_wdi.qmd` | Auto via R package |
| *(none — pulled via `WDI` + Hanke/IMF tabs)* | Hanke/IMF inflation | `02b_load_inflation_supplements.qmd` | Manual: Hanke list + IMF WEO export |
| `mmp_all.tab` | Mass Mobilization Project | `03a_load_mmp.qmd` | Manual: Harvard Dataverse |
| `ucdp_ged251/` (zip + extracted CSV) | UCDP Georeferenced Events v25.1 | `03b_load_ucdp.qmd` | Manual: ucdp.uu.se |
| `cline_coups.csv` | Cline Center coup database | `03c_load_coups.qmd` | Manual: clinecenter.illinois.edu |
| `fariss_lhrs_v4.csv` | Fariss latent human-rights scores v4 | `03d_load_fariss.qmd` | Manual: Harvard Dataverse |
| `polity5_v2018.xls` | Polity5 | `03e_load_polity.qmd` | Manual: centerforsystemicpeace.org |
| *(none — pulled via UNHCR API in 04)* | UNHCR | `04_load_unhcr.qmd` | Auto via REST API |
| `fao_food_price_indices.csv` | FAO Food Price Index | `05_load_fao.qmd` | Manual: fao.org/worldfoodsituation |
| `pilster_bohmelt_coup_proofing.tab` | Pilster-Böhmelt counterbalancing | `06_load_pb.qmd` | Manual: Harvard Dataverse |
| `debruin_ssf/` + `debruin_ssf.zip` | de Bruin State Security Forces | `07_load_debruin.qmd` | Manual: PRIO replication archive |
| ⏳ *(pending)* | ACLED | (future `03_load_acled.qmd`) | API; Research-tier access applied 2026-05-15 |

## `panel.duckdb` tables

Built incrementally — each loader writes one table; `08_build_panel.qmd`
joins them; `09_label_events.qmd` adds outcome columns.

| Table | Written by | Grain |
|---|---|---|
| `countries` | 00 | one row per country (ISO3) |
| `vdem` | 01 | (iso3c, year) |
| `wdi` | 02 | (iso3c, year) |
| `imf_inflation` | 02b | (iso3c, year) |
| `mmp_annual` | 03a | (iso3c, year) |
| `ucdp_annual` | 03b | (iso3c, year) |
| `coups_annual` | 03c | (iso3c, year) |
| `fariss` | 03d | (iso3c, year) |
| `polity` | 03e | (iso3c, year) |
| `unhcr` | 04 | (iso3c, year) |
| `fao` | 05 | (year, month) |
| `fao_annual` | 08 | (year) |
| `pb_counterbalancing` | 06 | (iso3c, year) |
| `security_forces` | 07 | (iso3c, year) |
| `panel_features` | 08 | (iso3c, year) — joined panel with z-scored features |
| `panel_labeled` | 09 | (iso3c, year) — `panel_features` + `unrest_next_year` |

## Re-creating the data folder

Render the training notebooks in numeric order from a fresh checkout. See
[`../training/README.md`](../training/README.md) for the canonical pull order
and which loaders need manual file downloads.

## `curated/`

Small hand-maintained mapping files. Committed.

- `prediction_market_mapping.csv` — maps prediction-market questions (Polymarket, Kalshi) to the model's country-year outcomes.
