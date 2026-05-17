# artifacts

Frozen outputs of the training pipeline. **Committed** (small, deterministic,
version-controlled). The static dashboard `fetch()`es these at page load.

```
artifacts/
├── weights.json          # logistic regression coefficients + vcov per regime stratum
├── base_rates.json       # regime-type intercepts (4 V-Dem RoW categories) and historical rates
├── country_snapshot.json # current-year indicator values + per-feature contributions per country
├── calibration.json      # Brier, log loss, reliability diagram bins (2023 holdout)
├── hanke_inflation.json  # Hanke-estimate inflation series for the dashboard toggle
└── curated/              # hand-maintained reference files (see data/README.md)
```

All artifacts carry a `model_version` field. `weights.json` additionally
carries `fitted_at`, `train_years`, and the `winsorize_bound` constant
(currently 3) that the dashboard mirrors when computing scenarios.

## Refresh cadence

Re-run `training/12_export_artifacts.qmd` after re-training and commit the
JSON diff. Quarterly is a reasonable default; sooner when a new data source
comes online or a calibration fix lands.

## Why frozen JSON instead of an API

The R fit produces coefficients and a covariance matrix — both are small,
fully deterministic, and don't need a server to be useful. Shipping them as
JSON means the dashboard runs as a static page (GitHub Pages compatible),
and re-deploying the model is `quarto render 12 && git commit`.

The original spec proposed a Go API loading these. The forecast math is
simple enough (a logistic + MVN sampling) that the browser handles it
directly. If we ever need server-side scenario aggregation or auth, the API
is reserved in `../api/`.
