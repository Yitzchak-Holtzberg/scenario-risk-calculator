# Scenario Risk Calculator

Country-level political risk forecasting tool. Data-driven, regime-stratified, indicator-weighted logistic model with confidence intervals and per-indicator contribution breakdowns. Modeled on CSIS / RAND country-risk methodology.

v0 question: *How likely is a sustained mass unrest episode in {country} within the next 12 months?*

Full spec lives in the planning vault. This repo is the implementation.

## Stack

| Layer | Tool |
|---|---|
| Training pipeline | R + Quarto in RStudio |
| Database | DuckDB (embedded, single file) |
| Backend API | Go (stdlib `net/http` + `chi`) |
| Frontend | SvelteKit + TypeScript |
| Hosting | Azure Container Apps (API) + Azure Static Web Apps (frontend) |

## Layout

```
scenario-risk-calculator/
├── api/         # Go stateless JSON API
├── web/         # SvelteKit dashboard
├── training/    # R + Quarto pipeline (panel join, glm fit, bootstrap CIs)
├── data/        # DuckDB files + raw source CSVs (gitignored; large)
└── artifacts/   # weights.json, base_rates.json, country_snapshot.json, model-card.html
                 # ^ produced by training/, consumed by api/
```

The training pipeline emits frozen artifacts. The API loads them at startup and serves stateless forecasts. Retraining is a deliberate dated event.

## Data sources

| Source | Role |
|---|---|
| V-Dem v14 | Regime classification + political covariates (regime support, civil liberties) |
| World Bank WDI / IMF WEO | Economic covariates (inflation, GDP, trade) |
| ACLED | Protest / unrest event detection (real-time) |
| Mass Mobilization Project | Pre-2018 historical protest depth |
| Pilster–Böhmelt | Military counterbalancing index (coup-proofing structure) |
| de Bruin | State security forces dataset |
| FAO / UNHCR | Food prices / migration flows |

## Forecast question and resolution

**Question**: Probability of sustained mass unrest in {country} within 12 months.

**Resolution** (any one triggers YES):
- Successful regime change by non-electoral means.
- Capital occupation by protest actors for >72 hours.
- Sustained mass protest movement: >100k cumulative participants, multiple cities, >2 weeks.

## Bootstrap order

See the spec for full detail. Short version:

1. Install R + RStudio + Quarto + DuckDB CLI.
2. Load V-Dem CSV into `data/panel.duckdb`, query Cuba to confirm.
3. Add WDI, ACLED, P&B, de Bruin to the panel.
4. Define event-label function from ACLED + MMP.
5. Fit logistic regression stratified by V-Dem RoW regime type.
6. Bootstrap CIs.
7. Export `artifacts/*.json` + Quarto-rendered `model-card.html`.
8. Scaffold Go API (`api/`), load artifacts at startup.
9. Scaffold SvelteKit dashboard (`web/`), fetch the forecast endpoint.
10. Deploy.

Steps 1–7 are the actual project. Don't start the API/UI before the model produces sane numbers.

## License

TBD — depends on data source license compatibility (ACLED has terms for commercial use; V-Dem is CC BY 4.0).
