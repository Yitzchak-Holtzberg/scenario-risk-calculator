# data

Shared raw sources and the DuckDB database used by every project in this
repo. **Contents are gitignored** (except `curated/`) — too large to commit and
licenses vary per source.

```
data/
├── raw/         # downloaded source files (V-Dem and WDI pulled via R packages, not stored here)
├── curated/     # hand-curated supplements used by the loaders (committed)
└── panel.duckdb # loader tables from pipelines/00–07, plus project tables (~250 MB after full run)
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
| `acled/regional/` | ACLED country-year aggregates | `03f_load_acled.qmd` | Manual: ACLED Aggregated Data export (no redistribution) |

## `panel.duckdb` tables

Built incrementally. Each loader in `pipelines/` writes its own tables;
projects then add their own derived tables (prefix them by project when
adding new ones, e.g. `bc_` for beautiful-century, to avoid collisions).

| Table | Written by | Grain |
|---|---|---|
| `countries` | 00 | one row per country (ISO3) |
| `vdem` | 01 | (iso3c, year) |
| `wdi` | 02 | (iso3c, year) |
| `imf_inflation` | 02b | (iso3c, year) |
| `mmp_annual` | 03a | (iso3c, year) |
| `ucdp_annual` | 03b | (iso3c, year) |
| `coups_annual` | 03c | (iso3c, year) |
| `fariss_hr` | 03d | (iso3c, year) |
| `polity5` | 03e | (iso3c, year) |
| `unhcr`, `unhcr_inflow` | 04 | (iso3c, year) |
| `acled_annual` | 03f | (iso3c, year) |
| `fao` | 05 | (year, month) |
| `fao_annual` | scenario-risk-calculator/08 | (year) |
| `pb_counterbalancing` | 06 | (iso3c, year) |
| `security_forces` | 07 | (iso3c, year) |
| `panel_features` | scenario-risk-calculator/08 | (iso3c, year) — joined model panel |
| `panel_labeled` | scenario-risk-calculator/09 | (iso3c, year) — `panel_features` + outcome labels |

## Re-creating the data folder

Render the loaders in [`../pipelines/`](../pipelines/README.md) in numeric
order from a fresh checkout (the table above lists the manual downloads).
Fitted models now live with their project (e.g.
`projects/scenario-risk-calculator/model/`), not in `data/model/`.

## `curated/`

Small hand-maintained supplement files used by the loaders. Committed. See
[`curated/README.md`](curated/README.md). Project-specific curated files live
under `projects/<name>/curated/`.
