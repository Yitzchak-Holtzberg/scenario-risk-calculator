# Scenario Risk Calculator

Country-level political-risk forecasting tool. **Two pooled LASSO logistic models** on raw cross-country feature levels write frozen JSON artifacts for a static dashboard. The user picks a country, sees two separate 12-month probabilities — `P(mobilization)` and `P(armed violence/coup)` — with 90% CIs, and moves sliders to explore scenarios.

**v0 question**: *Given this country's structural and economic characteristics, what fraction of historical country-years with similar values experienced (a) mass mobilization next year, or (b) armed conflict / coup attempt next year?* (The PITF/Goldstone 2010 framing, stratified into two outcome tiers because protest and armed conflict are empirically distinct processes.)

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
   ├── 03d fariss (latent HR scores) ── loaded, excluded (collinearity)
   ├── 03e polity (Polity5)          ── loaded, excluded (collinearity)
   ├── 03f acled (country-year aggregates: demos, violence, fatalities)
   ├── 04 unhcr (refugee outflow)
   ├── 05 fao (food prices)
   ├── 06 pb (coup-proofing fragmentation)
   └── 07 debruin (state security forces) ── loaded, excluded (coverage ends 2010)
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
| 2b | `02b_load_inflation_supplements.qmd` | IMF WEO bulk supplement: **PCPIPCH** (inflation), **NGDP_RPCH** (real GDP growth), **NGDPDPC** (GDP per capita) — backfills WDI for 2025+ where WDI is still releasing. Plus hand-curated IMF Staff estimates for crisis countries (Cuba, Venezuela, Sudan, Zimbabwe, Argentina, Lebanon, Syria) and Hanke Troubled Currencies estimates for the dashboard toggle. | ✅ |
| 3a | `03a_load_mmp.qmd` | Mass Mobilization Project (Clark & Regan) — large protest events 1990-2020 | ✅ |
| 3b | `03b_load_ucdp.qmd` | UCDP GED v25.1 — armed-conflict fatalities 1989-2024 | ✅ |
| 3c | `03c_load_coups.qmd` | Cline Center Coup d'État Project — coups 1945-2026 | ✅ |
| 3d | `03d_load_fariss.qmd` | Fariss latent human-rights protection scores | ✅ loaded; excluded from current fit |
| 3e | `03e_load_polity.qmd` | Polity5 democracy-autocracy scores 1800-2018 | ✅ loaded; excluded from current fit |
| 3f | `03f_load_acled.qmd` | ACLED country-year aggregates (demonstrations, political violence events, fatalities, civilian-targeting events, civilian fatalities), 1997-2026, 250 countries. **v0.7 Phase A**: Research-tier API was denied; ACLED granted dashboard-read access. Pre-aggregated files staged in `data/raw/acled/` (gitignored). | ✅ v0.7 |
| 4 | `04_load_unhcr.qmd` | UNHCR refugee + asylum-seeker counts by origin | ✅ |
| 5 | `05_load_fao.qmd` | FAO Food Price Index, monthly global | ✅ |
| 6 | `06_load_pb.qmd` | Pilster-Böhmelt counterbalancing (coup-proofing) | ✅ (auto-fetched from Harvard Dataverse) |
| 7 | `07_load_debruin.qmd` | de Bruin State Security Forces 1960-2010 | ✅ loaded; excluded from current fit (coverage gaps) |
| 8 | `08_build_panel.qmd` | Join all sources into country-year panel; **raw cross-country levels (no z-scoring, no imputation, no forward-fill)**; **`COALESCE(wdi, imf-curated, imf-weo)` for inflation**; log1p for refugee outflow; cpi_inflation clipped to [-10, 200]%. Missing-source country-years stay NA. | ✅ |
| 9 | `09_label_events.qmd` | Multi-source outcome fusion: coup OR UCDP fatalities OR MMP large protest OR V-Dem mob ord | ✅ |
| 10 | `10_fit_model.qmd` | Pooled LASSO logistic regression on raw cross-country levels + per-regime context models; 10 features; no regime dummies; **monotonicity constraints** (every β forced to substantively-correct sign); `political_violence_ord` lagged 1 year to kill autocorrelation with outcome label; bootstrap empirical vcov for CIs | ✅ v0.5 |
| 11 | `11_calibration.qmd` | Brier, log loss, reliability on 2023 holdout | ✅ |
| 12 | `12_export_artifacts.qmd` | Emit `weights.json`, `base_rates.json`, `country_snapshot.json`, `calibration.json`, `hanke_inflation.json` | ✅ |
| — | `web/index.html` | Dashboard: country picker + probability + CI + sliders + **IMF/Hanke inflation toggle** | ✅ |

## Forecast definition (v0)

**Two outcome tiers** (in `09_label_events.qmd`), each predicted separately by its own LASSO:

- `outcome_mobilization` — fires if **any of** (a) MMP-recorded protest with participants ≥0.1% of population (per-capita threshold, calibrated to Iran 2022 Woman-Life-Freedom baseline; catches Yellow Vests, HK 2019, Iceland 2008, BLM 2020, Iran 2009 Green Movement), (b) V-Dem `v2cagenmob_ord ≥ 4` ("mass mobilization was a defining feature of the year"; post-2020 fallback for MMP), or **(c, v0.7.1) ACLED violent-demonstration fatalities ≥ 10 in the year** (the deadly-mobilization signature: Iran 2022 = 421 fatalities, USA 2020 BLM = 14, Iran 2021 = 10).
- `outcome_violence` — fires if **any of** (a) UCDP GED records 100+ fatalities in state-based armed conflict, (b) Cline Center records a coup attempt (realized or attempted), or **(c, v0.7.1) ACLED total fatalities ≥ 100 in the year** (UCDP-equivalent threshold; complementary measurement from a different coding pipeline; critically fills UCDP's release-lag gap — UCDP coverage ends 2024, ACLED runs through 2026).

**Why fatalities, not event counts.** v0.7-rev0 used an event-count threshold (≥10 ACLED demonstrations per million) and it broke catastrophically — Sweden, Japan, Germany, Canada, France, USA all flipped to mobilization=1 every year because ACLED counts every protest event (including 50-person climate rallies). The 2023 holdout Brier skill score collapsed from −0.05 to −0.81. The fix: ACLED only contributes via **fatalities**, the bias-resistant currency in event data. Deaths are coded across regimes more uniformly than events (hospitals, families, opposition track them even when state suppresses news). Peaceful protests of any volume contribute nothing.

`unrest_next_year` is kept as a legacy column (OR of both tiers) for backwards compatibility but the headline forecasts are the two tiers separately.

Multi-source fusion protects against any single source's quirks. ACLED **augments** MMP+UCDP rather than replacing them (v0.7 Phase A): MMP runs 1990-2020 with full global coverage; ACLED runs 1997-2026 but doesn't reach global coverage until 2018-2020. Keeping both as OR-channels means MMP covers the pre-2020 / pre-ACLED-coverage country-years while ACLED covers post-2020 + provides denser event counts where both are present. Earlier v0 attempts used V-Dem `v2cagenmob_ord ≥ 2` alone, which produced flat base rates (47–60% across regimes) because the ordinal is too broad.

**Regime controls**: V-Dem Regimes of the World — closed autocracy, electoral autocracy, electoral democracy, liberal democracy. In v0.4 the **pooled model does not use regime dummies** (they were 0.816-correlated with `civil_liberties` and created an unstable coefficient allocation); civil liberties is the single regime-quality channel in the headline model. Per-regime stratified LASSO models are still fit and retained for within-regime analyst context.

**Features (14 total, v0.7.1)** — all raw cross-country levels, no within-country z-scoring:

| Feature | Type | Source |
|---|---|---|
| `civil_liberties` | Level (0–1) | V-Dem `v2x_civlib` |
| `log_gdp_per_cap` | Level (log USD) | WDI GDP per capita |
| `loser_consent` | Level (0–4 ordinal) | V-Dem `v2elaccept_ord` |
| `conflict_neighbors_count` | Level count | UCDP + region approximation |
| `gdp_growth` | Level (%) | WDI |
| `cpi_inflation` | Level (%) clipped to [-10, 200] | WDI + IMF curated + IMF WEO bulk |
| `unemployment` | Level (%) | WDI |
| `political_violence_ord_lag1` | Level (0–4 ordinal), lag-1 | V-Dem `v2caviol_ord` |
| `mass_mobilization_ord_lag1` | Level (0–4 ordinal), lag-1 | V-Dem `v2cagenmob_ord` |
| `log_refugee_outflow` | Level (log1p) | UNHCR |
| `coup_proof_fragmentation` | Level | Pilster-Böhmelt |
| `log_acled_violent_demo_fat_per_cap_lag1` | log1p(deaths/million pop), lag-1 | ACLED Violent demonstration sub-event |
| `log_acled_pv_fat_per_cap_lag1` | log1p(deaths/million pop), lag-1 | ACLED Political violence event types |
| `acled_covered_lag1` | 0/1 missing-indicator co-feature | ACLED coverage flag |

`cpi_inflation` is clipped at [-10, 200]% before fitting so hyperinflation outliers (Venezuela 2017, Zimbabwe 2008) don't dominate the coefficient. `log_refugee_outflow` is log1p-transformed for cross-country comparability (Afghanistan 6M vs USA 6K).

**v0.7 Phase A — ACLED features built but not yet in the fit.** `08_build_panel.qmd` now also computes `log_acled_demos_per_cap_lag1`, `log_acled_fatalities_per_cap_lag1`, and `acled_covered_lag1` and persists them in `panel_features`. They are **deliberately not added to the model's `features` list yet**: ACLED's pre-2018 coverage gap would listwise-drop ~50% of training rows the moment those features became required for `complete.cases`. Phase A.5 / Phase B will decide on a missing-value strategy (zero-fill with co-feature, V-Dem ordinal fallback, etc.) and add the ACLED features to the fit with a before/after BSS comparison.

Loaded into the panel but excluded from the v0.4 fit: `freedom_expression` and `regime_support_locus` (collinear with civil_liberties); `fariss_hr_score` and `polity2` (collinear, ~0.9 with civil_liberties); de Bruin `counterbalancing` / `politicization` (source ends 2010); `ffpi_avg` (no cross-country variation in a given year).

**Train / holdout**: train on 1995-2022, holdout 2023. CPI-imputed country-years are listwise-dropped from training so the regression doesn't learn region-median synthetic inflation as a feature.

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

- **v0.7.1 Brier skill score (2023 holdout)**:
  - **Mobilization tier**: **+0.022** (n=144, base rate 14.6%). First time positive since the project started. Modest predictive value — the model adds a small amount of real information beyond the base rate. Still consistent with the literature: protest at 1-year horizon is genuinely hard to predict from structural features alone.
  - **Armed violence / coup tier**: **+0.624** (n=144, base rate 25.0%). Strong predictive value — up from +0.46 in v0.6 (a 35% absolute improvement). The new ACLED-derived continuous fatality feature gave the model a much richer signal than the V-Dem ordinal lag it complements.
  - The contrast still validates the two-tier split. Mobilization remains the harder problem; we don't pretend otherwise. But both tiers improved from the ACLED fatality channel: mobilization went from worse-than-baseline (−0.054) to slightly-better-than-baseline (+0.022), and violence got a major lift.

- **v0.6 baseline (pre-ACLED) for comparison**:
  - Mobilization: BSS = −0.054, base rate 11.8%
  - Violence: BSS = +0.459, base rate 18.0%
- **Face validity restored**: Cuba 34.6% > USA 26.6%. The v0.4.1 inversion (USA 39% > Cuba 32%) is gone because v0.5's monotonicity constraints zero out `civil_liberties`'s sign-flipped contribution (the "more civil liberties → more reported unrest" reporting-bias artifact). Country rankings now match political-risk intuition top to bottom.
- **`political_violence_ord` is lagged by 1 year**. v0.4 used the concurrent V-Dem violence ordinal as a predictor, but our outcome label includes the V-Dem `v2cagenmob_ord >= 4` fallback for post-2020 years — concurrent violence partly predicts itself. Lagging breaks the autocorrelation.
- **Monotonicity constraints** force every coefficient to its substantively-justified sign: `civil_liberties ≤ 0`, `cpi_inflation ≥ 0`, `unemployment ≥ 0`, etc. Reporting bias can no longer flip signs. Features that lose their predictive power when forced to the right sign get zeroed out (cpi_inflation, unemployment, civil_liberties, log_gdp_per_cap, loser_consent all sit at β = 0). **This is an honest empirical finding**: at the 1-year horizon, those features don't add predictive value beyond prior political violence — consistent with PITF/Goldstone literature (economic shocks predict 2-3 year horizons).
- **Curated unemployment supplement** (`data/curated/unemployment_supplement.csv`) overrides WDI/ILO official numbers for 8 state-managed economies (Cuba, Belarus, Venezuela, PRK, Eritrea, Turkmenistan, Cambodia, Laos) where state-employment-guarantee policies suppress the published rate. Uses IMF Article IV reviews + NGO consensus.
- **18 countries show "no prediction available"** — PRK, Somalia, Taiwan, Hong Kong, Eritrea (still — has unemployment supplement but missing other features), and others where at least one v0.5 model-input feature is genuinely NA after the source-coverage pull. Better to abstain than to score on imputed data.
- **Active coefficients** (only 5 of 10 features survive LASSO at λ.min with constraints): `political_violence_ord_lag1` β=+0.73 (dominant), `coup_proof_fragmentation` β=+0.31, `log_refugee_outflow` β=+0.18, `gdp_growth` β=−0.018 (tiny), `conflict_neighbors_count` β=+0.012 (tiny). The model relies primarily on prior violence + structural fragility + refugee outflow.
- **Closedness→under-reporting bias remains** in the outcome label itself. Fixing the residual bias requires a Heckman / Bayesian censored-outcome model (queued for v1) — out of scope for v0.5.
- **ACLED won't fully fix the bias**, only narrow it. Reporting-availability bias is upstream of any event data source.
- **Country-year, not country-month**: every covariate is annual. Country-month would replicate the same row 12 times — no new information. When ACLED arrives, we revisit.

## Roadmap — what we still want to add

These would push the model from "v0 prototype" to "credible v1."

| Priority | Source / change | Why | Status |
|---|---|---|---|
| ✅ Done | **ACLED** (protest/conflict events) | The canonical political-risk event source. Augments (not replaces) MMP+UCDP fusion: ACLED brings 2018-2026 dense coverage to close MMP's 2020 cliff; MMP keeps pre-2018 Latin America/Europe covered where ACLED hadn't started yet. Narrows the closedness-under-reporting bias but does not fully fix it (ACLED still can't see inside DPRK / Eritrea). | Shipped in v0.7 Phase A — Research-tier API was denied; dashboard-read clearance granted; five pre-aggregated country-year xlsx files loaded |
| 🔴 High | **Censored-outcome correction** | Heckman 2-stage or Bayesian baseline-prior to handle "observed" vs "true" unrest — the fundamental fix for the PRK problem. | Not started |
| ✅ Done | **Raw cross-country levels, no imputation** | Replaces within-country z-scoring + region-median fills. Honest about data coverage. | Shipped in v0.4.1 |
| 🟠 Medium | **Real CPI/unemployment for closed autocracies** | IMF Article IV reviews, World Bank country reports, central-bank releases for the ~10 countries currently dropping out (PRK, Eritrea, Saudi Arabia, Somalia, etc.). Hand-curated supplement, like the existing `02b_load_inflation_supplements.qmd`. | Partial (Cuba/Venezuela/Lebanon covered via 02b) |
| 🟠 Medium | **de Bruin State Security Forces** | Already loaded. Coverage ends 2010 → forward-fill required. Would give us elite-split and security-force-defection features. | Loaded, excluded from fit |
| 🟠 Medium | **Energy crisis indicators** (electricity per capita YoY, energy-import dependency) | Mock dashboard's "Energy crisis" indicator concept. WDI has some; IEA has more (most behind paywall). | Not yet loaded |
| 🟡 Low | **Country-level food security** (FAO Suite of Food Security Indicators) | Replaces global FFPI with country-specific signal. | Not yet loaded |
| 🟡 Low | **NELDA elections** | Election timing + manipulation. Critical for electoral-cycle dynamics. | Not yet loaded |
| 🟡 Low | **Internet shutdowns** (Access Now KeepItOn) | Real-time indicator of regime repression. Niche but informative. | Not yet loaded |
| 🟡 Low | **GDELT events** | News-derived events at daily granularity. TB-scale; useful when we revisit country-month. | Not yet loaded |

## Modeling improvements queued for v1

- ~~**Ridge regression** — stabilize correlated predictors without collinear sign-flip~~ — shipped in v0.3
- ~~**LASSO + raw cross-country levels** — replace within-country z's with cross-sectional PITF/Goldstone framing~~ — shipped in v0.4
- ~~**No-imputation policy** — drop region-median fills; missing source data → "no prediction available"~~ — shipped in v0.4.1
- ~~**ACLED ingestion as third OR-channel in outcome fusion**~~ — shipped in v0.7 Phase A (mobilization + violence tiers)
- **ACLED features in the fit (Phase A.5 / B)** — `log_acled_demos_per_cap_lag1` and `log_acled_fatalities_per_cap_lag1` are built and persisted in the panel but not yet in the model. Decide missing-value strategy (zero-fill + co-feature vs V-Dem ordinal fallback vs listwise drop), then add with before/after BSS comparison.
- **ACLED YoY-change feature (Phase B)** — `acled_demos_yoy_change_lag1` with winsorization. Acceleration is mechanically the only signal in the pipeline that could predict short-fuse protest. Iran 2017→2022 demos went 2430 → 4281 (76% increase).
- **Heckman / Bayesian censored-outcome correction (Phase C)** — model "observed unrest" vs "true unrest" separately. ACLED's now-measurable coverage + zero-counts in covered closed regimes (DPRK 0/0/0/1/4 demos 2018-2022) provide a stronger first-stage selection signal than was previously available.
- **Hand-curated supplements for closed autocracies** — IMF Article IV / central-bank releases for the 10-18 countries that currently drop from inference. Same template as `02b_load_inflation_supplements.qmd`.
- **Platt scaling / isotonic regression** — fix the high-end over-confidence visible in the 2023 reliability bins
- **Country-month granularity** — revisit now that ACLED is available; would need monthly aggregates rather than the current annual files
- **Diagnostic** — emit a "countries never seen in training" list from `10_fit_model.qmd` to surface listwise-deletion damage

## License

TBD — depends on data-source license compatibility. V-Dem is CC BY 4.0; WDI is CC BY 4.0; UNHCR data is open with attribution; FAO data is CC BY-NC-SA. **ACLED is restrictive (no redistribution).** The repo handles this by gitignoring `data/raw/acled/` and committing only country-year aggregates / derived binary outcome flags to DuckDB and `artifacts/` — never the raw event rows. ACLED granted dashboard-read clearance after the Research-tier API application was denied; the loader reads pre-aggregated country-year xlsx files exported from ACLED's [Aggregated Data](https://acleddata.com/data-export-tool/) interface.
