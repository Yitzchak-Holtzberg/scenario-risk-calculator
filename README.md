# Scenario Risk Calculator

Country-level political-risk forecasting tool. Regime-stratified logistic regression with frozen JSON artifacts and a static dashboard. The user picks a country, sees a 12-month probability of sustained mass unrest with a 90% CI, and moves sliders to explore scenarios.

**v0 question**: *How likely is sustained mass mobilization in {country} within the next 12 months?*

## Stack (v0 reality)

| Layer | Tool |
|---|---|
| Training pipeline | R + Quarto |
| Database | DuckDB (embedded, single file) |
| Artifacts | Frozen JSON files in `artifacts/` |
| Dashboard | Static HTML + vanilla JS in `web/` (no toolchain) |

The training pipeline writes JSON; the dashboard reads JSON and computes scenarios in the browser. No backend at runtime.

The original spec proposed a Go API + SvelteKit. v0 ships without either — the dashboard runs entirely client-side from the frozen artifacts. We can layer in SvelteKit + a Go API later if needed for richer interactions.

## Layout

```
scenario-risk-calculator/
├── training/    ← R + Quarto pipeline (panel build, glm fit, JSON export)
├── data/        ← DuckDB file + raw CSV downloads (gitignored)
├── artifacts/   ← Frozen JSON consumed by the dashboard (committed)
├── web/         ← Static dashboard (index.html — opens against ../artifacts/)
├── api/         ← Reserved for later Go service (empty for v0)
└── mocks/       ← HTML mockups that defined the dashboard design language
```

## Pipeline

```
00 countries → 01 vdem ──┐
                01 wdi ──┤
              02 unhcr ──┼──► 08 build_panel ──► 09 label_events ──► 10 fit_model
                03 fao ──┘                                                    │
                                                                              ▼
   web/index.html ◄──── artifacts/*.json ◄──── 12 export_artifacts ◄──── 11 calibration
   (sliders, scenarios)        (frozen)
```

| Step | Notebook | What it does | Status |
|---|---|---|---|
| 0 | `00_load_countries.qmd` | Master country reference (ISO3, GW code, V-Dem id, region) | ✅ |
| 1 | `01_load_vdem.qmd` | V-Dem v16: regime classification + governance indices | ✅ |
| 2 | `02_load_wdi.qmd` | World Bank WDI: CPI, GDP growth, GDP/capita, trade, unemployment | ✅ |
| 3 | `03_load_acled.qmd` | ACLED protest/conflict events | ⏳ blocked on Research-tier API access |
| 4 | `04_load_unhcr.qmd` | UNHCR refugee + asylum-seeker counts by origin | ✅ |
| 5 | `05_load_fao.qmd` | FAO Food Price Index, monthly global | ✅ |
| 6 | `06_load_pb.qmd` | Pilster-Böhmelt counterbalancing (coup-proofing) | ⏳ manual download |
| 7 | `07_load_debruin.qmd` | de Bruin State Security Forces 1960-2010 | ⏳ manual download |
| 8 | `08_build_panel.qmd` | Join all sources into country-year panel; within-country z-scores | ✅ |
| 9 | `09_label_events.qmd` | Outcome label from V-Dem `v2cagenmob_ord` lead | ✅ |
| 10 | `10_fit_model.qmd` | Logistic regression, one per V-Dem RoW regime category | ✅ |
| 11 | `11_calibration.qmd` | Brier, log loss, reliability on 2023 holdout | ✅ |
| 12 | `12_export_artifacts.qmd` | Emit `weights.json`, `base_rates.json`, `country_snapshot.json`, `calibration.json` | ✅ |
| — | `web/index.html` | Dashboard: country picker + probability + CI + sliders | ✅ |

## Forecast definition (v0)

**Outcome**: V-Dem `v2cagenmob_ord >= 2` in year+1 — "several or many mass-mobilization events." This is a stand-in for sustained mass unrest until ACLED comes online for higher-resolution event counts.

**Stratification**: V-Dem Regimes of the World — closed autocracy, electoral autocracy, electoral democracy, liberal democracy. One logistic model per stratum.

**Features (z-scored within country)**:
- Civil liberties (V-Dem `v2x_civlib`)
- Freedom of expression (V-Dem `v2x_freexp_altinf`)
- GDP growth (WDI)
- Refugee outflow (UNHCR, origin side)
- Political violence (V-Dem `v2caviol_ord`)
- Global food prices (FAO FFPI annual avg)

**Train / holdout**: train on 1995-2022, holdout 2023.

## Running the pipeline

Install once:

```r
install.packages(c("DBI", "duckdb", "ggplot2", "remotes", "WDI",
                   "httr2", "jsonlite", "countrycode"))
remotes::install_github("vdeminstitute/vdemdata")
```

Render notebooks in numeric order:

```sh
cd training
quarto render 00_load_countries.qmd
quarto render 01_load_vdem.qmd
# … through 12
```

Or render everything: `cd training && quarto render`.

## Running the dashboard

Static HTML, but uses `fetch()` so it needs a local web server (browsers block `fetch()` on `file://`):

```sh
cd web
python -m http.server 8080
# then open http://localhost:8080
```

The dashboard reads `../artifacts/*.json` directly. To refresh after re-training, re-run `12_export_artifacts.qmd` and reload the page.

## Current model state (honest)

- **Brier skill score 0.01** — model is barely better than predicting the base rate. Outcome threshold (`>=2`) is too loose; base rates run 47–60% across regimes. Tighten to `>=3` for "many large events" to lift signal.
- **Missing data**: ACLED, Pilster-Böhmelt, de Bruin. These would unlock 3 more indicator concepts shown in the mocks (elite split, security-force defection, sharper unrest counts). Pipeline is built to absorb them as additions.
- **Country-year, not country-month**: every covariate is annual. Country-month would forward-fill 12 identical rows per year — no information added. When ACLED arrives, we revisit.

## License

TBD — depends on data-source license compatibility. V-Dem is CC BY 4.0; WDI is CC BY 4.0; UNHCR data is open with attribution; FAO data is CC BY-NC-SA. ACLED is restrictive (no redistribution).
