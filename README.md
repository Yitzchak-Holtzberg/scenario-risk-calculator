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
00 countries
   ├── 01 vdem
   ├── 02 wdi  ── 02b inflation-supplements (Hanke + IMF backfill)
   ├── 03a mmp (protests)
   ├── 03b ucdp (conflict events)
   ├── 03c coups (Cline)
   ├── 03d fariss (latent HR scores) ── loaded, not yet in v0 fit
   ├── 03e polity (Polity5)          ── loaded, not yet in v0 fit
   ├── 04 unhcr (refugee outflow)
   ├── 05 fao (food prices)
   ├── 06 pb (coup-proofing fragmentation)
   └── 07 debruin (state security forces) ── loaded, not yet in v0 fit
        │
        ▼
   08 build_panel  ──►  09 label_events (multi-source fusion)
                                  │
                                  ▼
                          10 fit_model  ──►  11 calibration  ──►  12 export_artifacts
                                                                       │
                                                                       ▼
                  web/index.html  ◄──── artifacts/*.json
                  (sliders, scenarios)        (frozen)
```

| Step | Notebook | What it does | Status |
|---|---|---|---|
| 0 | `00_load_countries.qmd` | Master country reference (ISO3, GW code, V-Dem id, region) | ✅ |
| 1 | `01_load_vdem.qmd` | V-Dem v16: regime classification + governance indices | ✅ |
| 2 | `02_load_wdi.qmd` | World Bank WDI: CPI, GDP growth, GDP/capita, trade, unemployment | ✅ |
| 2b | `02b_load_inflation_supplements.qmd` | IMF Staff inflation estimates + Hanke Troubled Currencies estimates for countries WDI doesn't cover (Cuba, Venezuela, Sudan, Zimbabwe, Argentina, Lebanon, Syria) | ✅ |
| 3a | `03a_load_mmp.qmd` | Mass Mobilization Project (Clark & Regan) — large protest events 1990-2020 | ✅ |
| 3b | `03b_load_ucdp.qmd` | UCDP GED v25.1 — armed-conflict fatalities 1989-2024 | ✅ |
| 3c | `03c_load_coups.qmd` | Cline Center Coup d'État Project — coups 1945-2026 | ✅ |
| 3d | `03d_load_fariss.qmd` | Fariss latent human-rights protection scores | ✅ (loaded, not in v0 fit — collinearity) |
| 3e | `03e_load_polity.qmd` | Polity5 democracy-autocracy scores 1800-2018 | ✅ (loaded, not in v0 fit — collinearity) |
| — | *ACLED* | Canonical protest/conflict events | ⏳ blocked on Research-tier API access (applied 2026-05-15). MMP + UCDP + Cline coups serve as proxy. |
| 4 | `04_load_unhcr.qmd` | UNHCR refugee + asylum-seeker counts by origin | ✅ |
| 5 | `05_load_fao.qmd` | FAO Food Price Index, monthly global | ✅ |
| 6 | `06_load_pb.qmd` | Pilster-Böhmelt counterbalancing (coup-proofing) | ✅ (auto-fetched from Harvard Dataverse) |
| 7 | `07_load_debruin.qmd` | de Bruin State Security Forces 1960-2010 | ✅ loaded; excluded from v0 fit (coverage gaps) |
| 8 | `08_build_panel.qmd` | Join all sources into country-year panel; within-country z-scores; **`COALESCE(wdi, imf)` for inflation**; region-median imputation for CPI/unemployment | ✅ |
| 9 | `09_label_events.qmd` | Multi-source outcome fusion: coup OR UCDP fatalities OR MMP large protest OR V-Dem mob ord | ✅ |
| 10 | `10_fit_model.qmd` | Logistic regression × 4 V-Dem RoW regime strata; 8 features | ✅ |
| 11 | `11_calibration.qmd` | Brier, log loss, reliability on 2023 holdout | ✅ |
| 12 | `12_export_artifacts.qmd` | Emit `weights.json`, `base_rates.json`, `country_snapshot.json`, `calibration.json`, `hanke_inflation.json` | ✅ |
| — | `web/index.html` | Dashboard: country picker + probability + CI + sliders + **IMF/Hanke inflation toggle** | ✅ |

## Forecast definition (v0)

**Outcome** (`unrest_next_year`, in `09_label_events.qmd`): flag a country-year if *any* of the following fires in the **following** year:

- Cline Center: 1+ coup attempt (realized or attempted)
- UCDP GED: 100+ conflict fatalities
- MMP: 1+ large protest (≥1,000 participants)
- V-Dem fallback (post-2020 only, since MMP ends in 2020): `v2cagenmob_ord ≥ 4`

Multi-source fusion protects against any single source's quirks. ACLED, when access arrives, will replace the MMP + UCDP proxy. Earlier v0 attempts used V-Dem `v2cagenmob_ord ≥ 2` alone, which produced flat base rates (47–60% across regimes) because the ordinal is too broad.

**Stratification**: V-Dem Regimes of the World — closed autocracy, electoral autocracy, electoral democracy, liberal democracy. One logistic model per stratum.

**Features (8 total)** — hybrid of levels (structural) and within-country z-scores (dynamic):

| Feature | Type | Source |
|---|---|---|
| `civil_liberties` | Level (0–1) | V-Dem `v2x_civlib` |
| `z_gdp_growth` | Within-country z | WDI |
| `z_cpi_inflation` | Within-country z (Hanke + IMF backfilled) | WDI + supplements |
| `z_unemployment` | Within-country z | WDI |
| `z_political_violence_ord` | Within-country z | V-Dem `v2caviol_ord` |
| `z_refugee_outflow` | Within-country z (log1p first) | UNHCR |
| `z_ffpi_avg` | Global z (same value per year) | FAO |
| `z_coup_proof_fragmentation` | Within-country z | Pilster-Böhmelt |

All z-scores winsorized at ±3 SDs (see `training/_helpers.R::z_within`); the dashboard mirrors the bound via `weights.winsorize_bound`.

Loaded into the panel but excluded from the v0 fit: `freedom_expression`, Fariss, Polity5 (collinear with `civil_liberties`); de Bruin (coverage ends 2010).

**Train / holdout**: train on 1995-2022, holdout 2023.

## Running the pipeline

Install once:

```r
install.packages(c("DBI", "duckdb", "ggplot2", "remotes", "WDI",
                   "httr2", "jsonlite", "countrycode", "readxl", "haven"))
remotes::install_github("vdeminstitute/vdemdata")
```

Render notebooks in numeric order:

```sh
cd training
quarto render 00_load_countries.qmd
quarto render 01_load_vdem.qmd
# … through 12_export_artifacts.qmd
```

Or render everything: `cd training && quarto render`. Notebooks are independent after first run — re-render any single one to refresh its DuckDB table.

## Running the dashboard

Static HTML, but uses `fetch()` so it needs a local web server (browsers block `fetch()` on `file://`):

```sh
cd web
python -m http.server 8080
# then open http://localhost:8080
```

The dashboard reads `../artifacts/*.json` directly. To refresh after re-training, re-run `12_export_artifacts.qmd` and reload the page.

GitHub Pages deploys `web/` automatically on push to `main` (see `.github/workflows/`).

## Current model state (honest)

- **Brier skill score = 0.0505** on 2023 holdout (n=175, base rate 26.3%). Meaningful signal but modest. Published instability-forecasting work hits 0.05–0.15 with larger feature sets — we're at the low end of credible.
- **Reliability**: well-calibrated in the 0.05–0.45 band; over-confident at the top end (predicted 0.54 → actual 0.14, n=7; predicted 0.82 → actual 0.50, n=1). Platt scaling on v1.
- **Country rankings are more reliable than absolute probabilities**. Rank order matches political-risk intuition; the exact percentages should be treated as estimates with wide uncertainty. 90% CIs are sampled from MVN(coef, vcov) in the browser and shown with each prediction.
- **Country-year, not country-month**: every covariate is annual. Country-month would forward-fill 12 identical rows per year — no information added. When ACLED arrives, we revisit.
- **Listwise deletion in `10_fit_model.qmd`**: country-years with any missing feature are dropped from training. Countries with chronic CPI/unemployment gaps (Cuba, North Korea, Eritrea) are systematically under-represented. Partially mitigated by `02b_load_inflation_supplements.qmd` and region-median imputation in `08_build_panel.qmd`; full fix queued for v1.

## Roadmap — what we still want to add

These would push the model from "v0 prototype" to "credible v1."

| Priority | Source / change | Why | Status |
|---|---|---|---|
| 🔴 High | **ACLED** (protest/conflict events) | The canonical political-risk event source. Would replace the MMP+UCDP proxy with real-time event counts and unlock monthly granularity. | Blocked on Research-tier API access; applied 2026-05-15 |
| 🟠 Medium | **Ridge regression** | Lets us put Fariss + Polity5 back into the fit alongside `civil_liberties` without collinear sign-flip. Already loaded, just excluded. | Queued |
| 🟠 Medium | **Country-specific imputation** | Carry-forward + regional median for the remaining WDI gaps so countries like Cuba and North Korea re-enter training. Partial fix already shipped via `02b`. | Partial |
| 🟠 Medium | **de Bruin State Security Forces** | Already loaded. Coverage ends 2010 → forward-fill required. Would give us elite-split and security-force-defection features. | Loaded, excluded from fit |
| 🟠 Medium | **Energy crisis indicators** (electricity per capita YoY, energy-import dependency) | Mock dashboard's "Energy crisis" indicator concept. WDI has some; IEA has more (most behind paywall). | Not yet loaded |
| 🟡 Low | **Country-level food security** (FAO Suite of Food Security Indicators) | Replaces global FFPI with country-specific signal. | Not yet loaded |
| 🟡 Low | **NELDA elections** | Election timing + manipulation. Critical for electoral-cycle dynamics. | Not yet loaded |
| 🟡 Low | **Internet shutdowns** (Access Now KeepItOn) | Real-time indicator of regime repression. Niche but informative. | Not yet loaded |
| 🟡 Low | **GDELT events** | News-derived events at daily granularity. TB-scale; useful when we revisit country-month. | Not yet loaded |

## Modeling improvements queued for v1

- **Platt scaling / isotonic regression** — fix the high-end over-confidence visible in the 2023 reliability bins
- **Ridge regression** — let the model use `civil_liberties`, Fariss, and Polity5 together without collinear sign-flip
- **Country-specific imputation** — finish carry-forward / regional median for remaining gaps so listwise deletion drops fewer countries
- **Country-month granularity** — revisit when ACLED comes online with event-level frequency
- **Hierarchical model** — Bayesian partial pooling across regions/regimes instead of strict stratification
- **Diagnostic** — emit a "countries never seen in training" list from `10_fit_model.qmd` to surface listwise-deletion damage

## License

TBD — depends on data-source license compatibility. V-Dem is CC BY 4.0; WDI is CC BY 4.0; UNHCR data is open with attribution; FAO data is CC BY-NC-SA. ACLED is restrictive (no redistribution).
