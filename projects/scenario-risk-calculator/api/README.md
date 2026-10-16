# api — reserved (not built in v0)

**Status: empty.** v0 ships without a backend. The static dashboard at
`../web/index.html` reads `../artifacts/*.json` directly and runs the
forecast math (logistic + MVN-sampled confidence intervals) in the browser.

This directory is reserved for a future Go service. Likely triggers for
actually building it:

- Server-side scenario aggregation (e.g., bulk forecasts across portfolios)
- Auth or per-user state
- Endpoints that exceed what static JSON can support

## Planned endpoints (when/if built)

- `GET /api/forecast/countries` — country list with regime classification
- `GET /api/forecast/schema` — indicator definitions and snapshot date
- `GET /api/forecast/{country}?horizon=12` — probability + CI + contributions + reference class
- `GET /api/forecast/model-card` — methodology document

The artifacts in `../artifacts/` are already shaped for this — `weights.json`
carries coefficients + `vcov`, `country_snapshot.json` carries per-country
feature values + contributions, etc. The Go service would load them at
startup the same way the browser does.

## Planned bootstrap (when/if built)

```sh
cd api
go mod init github.com/yitzy/scenario-risk-calculator/api
go get github.com/go-chi/chi/v5
```

DuckDB is **not** needed at the API layer — the JSON artifacts are
self-contained. Only add `go-duckdb` if the API later needs to query the
panel directly.
