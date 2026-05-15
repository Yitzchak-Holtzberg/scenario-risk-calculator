# artifacts

Frozen outputs of the training pipeline. **Committed** (small, deterministic, version-controlled).

```
artifacts/
├── weights.json          # logistic regression coefficients + standard errors
├── base_rates.json       # regime-type intercepts (4 V-Dem RoW categories)
├── country_snapshot.json # current indicator values per country
├── calibration.json      # Brier score, log loss, reliability diagram bins
└── model-card.html       # Quarto-rendered methodology document
```

The Go API loads these at startup and serves them. Re-train and re-commit on a quarterly cadence.

Each artifact carries a `modelVersion` and `snapshotDate` so the API can echo them in responses.
