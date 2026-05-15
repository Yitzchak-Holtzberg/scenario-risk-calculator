# api — Go forecast API

Stateless JSON API. Loads frozen artifacts from `../artifacts/` at startup; serves four endpoints.

## Endpoints

- `GET /api/forecast/countries` — country list with regime classification
- `GET /api/forecast/schema` — indicator definitions and snapshot date
- `GET /api/forecast/{country}?horizon=12` — probability + CI + contributions + reference class
- `GET /api/forecast/model-card` — methodology document

## Bootstrap

```sh
cd api
go mod init github.com/yitzy/scenario-risk-calculator/api
go get github.com/go-chi/chi/v5
go get github.com/marcboeker/go-duckdb
```

DuckDB is only needed if the API queries the panel directly. For v0 the artifacts are JSON files so go-duckdb is optional.
