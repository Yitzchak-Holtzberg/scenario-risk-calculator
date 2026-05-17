# web — static dashboard

Single-screen country-risk dashboard. Country picker → probability card (with
90% CI) → per-indicator contribution table → reference class disclosure.

**Stack**: one HTML file. Vanilla JavaScript. No build step, no Node, no
framework. The page `fetch()`es the JSON artifacts in `../artifacts/` at
load and computes everything (including the MVN-sampled confidence
intervals) client-side.

(The original spec called for SvelteKit + a Go API. v0 ships without either.
If/when interactions get richer than sliders + a country picker, that's the
upgrade path.)

## Running locally

`fetch()` is blocked on `file://`, so serve over HTTP:

```sh
cd web
python -m http.server 8080
# then open http://localhost:8080
```

Refresh the page after re-running `training/12_export_artifacts.qmd` to pick
up new artifacts.

## Files it reads

The page reads JSON directly from `../artifacts/`:

- `weights.json` — coefficients + covariance matrices per regime stratum
- `base_rates.json` — regime-type intercepts and historical base rates
- `country_snapshot.json` — current-year feature values for every country
- `calibration.json` — Brier, log loss, reliability bins
- `hanke_inflation.json` — Hanke-estimate inflation series for the optional dashboard toggle

`weights.winsorize_bound` is the single source of truth for the z-score
clip; `index.html::effectiveZValue` mirrors `training/_helpers.R::z_within`.

## Deployment

`.github/workflows/` deploys `web/` to GitHub Pages on push to `main`. The
deployment also publishes the contents of `artifacts/` so the live page can
`fetch()` them at runtime.
