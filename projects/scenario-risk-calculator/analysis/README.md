# analysis — Scenario Risk Calculator model (R + Quarto)

Project-specific steps that turn the shared loader tables into the two
risk models and the dashboard artifacts. The loaders themselves (steps
00–07) live in [`../../../pipelines/`](../../../pipelines/README.md) — run
those first so `data/panel.duckdb` is populated.

> Note: the outcome/feature sections below predate v0.4 in places
> (z-scoring, imputation). The project [README](../README.md) is the
> current source of truth for the model spec.

## Steps

| Step | Notebook | Reads | Writes |
|---|---|---|---|
| 8 | `08_build_panel.qmd` | loader tables in `data/panel.duckdb` | `panel_features`, `fao_annual` |
| 9 | `09_label_events.qmd` | `panel_features`, `../curated/manual_mobilization_labels.csv` | `panel_labeled`, `manual_mobilization_labels` |
| 10 | `10_fit_model.qmd` | `panel_labeled` | `../model/fit.rds` |
| 11 | `11_calibration.qmd` | `../model/fit.rds`, panel | `../model/calibration.rds` |
| 12 | `12_export_artifacts.qmd` | fit, calibration, panel | `../artifacts/*.json` (+ mirrored to `../web/artifacts/`) |
| 13 | `13_export_views_overlay.qmd` | ViEWS forecasts | `../artifacts/views_overlay.json` |

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

```sh
cd projects/scenario-risk-calculator/analysis
quarto render 10_fit_model.qmd   # one step
quarto render                    # 08 → 13
```

## Paths used by these notebooks

| Path (relative to `analysis/`) | What |
|---|---|
| `../../../data/panel.duckdb` | Shared DuckDB (loader tables + this project's `panel_*` tables) |
| `../../../pipelines/_helpers.R` | Shared plotting/ISO helpers |
| `../curated/` | Project-specific hand-curated labels (committed) |
| `../model/` | Fitted models + calibration RDS (gitignored) |
| `../artifacts/*.json` | Frozen dashboard artifacts (committed) |
| `../web/artifacts/` | Copy of artifacts served by GitHub Pages |
