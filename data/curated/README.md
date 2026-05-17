# Curated supplement data

Small hand-maintained CSVs that fill specific gaps in our bulk data sources.
Tracked in git (unlike `data/raw/` which is gitignored) because they're
intentional, sourced, and reviewed.

## Why hand-curated?

The bulk APIs we use (World Bank WDI, V-Dem, UCDP, etc.) have known coverage
gaps for politically sensitive countries — Cuba doesn't report CPI inflation,
North Korea doesn't report anything, etc. The fallback sources (IMF, Hanke)
either block programmatic bulk access (IMF) or have no API at all (Hanke).

So we maintain small CSVs with values pulled from published reports, sourced
in the CSV header comments. Updated manually when new releases drop.

## Files

### `imf_inflation_supplement.csv`
IMF Staff inflation estimates for countries where WDI is missing or
unreliable. Sourced from IMF WEO October 2024 + Article IV consultations.
Schema: `iso3c, year, cpi_inflation, source`.

Used by [`08_build_panel.qmd`](../../training/08_build_panel.qmd) via
`COALESCE(wdi.cpi_inflation, imf.cpi_inflation)` — WDI wins where it has
data, IMF backfills the gaps.

### `hanke_inflation_estimates.csv`
Steve Hanke's Troubled Currencies Project estimates (Johns Hopkins / Cato).
Hanke uses free-market exchange-rate decay as an inflation proxy and his
numbers are 2–10× higher than IMF for crisis economies. These are what
journalists cite when reporting "hyperinflation."
Schema: `iso3c, year, cpi_inflation_hanke, source`.

Loaded into the `hanke_inflation` DuckDB table by
[`02b_load_inflation_supplements.qmd`](../../training/02b_load_inflation_supplements.qmd)
and exported as `artifacts/hanke_inflation.json` for the dashboard's
"Inflation source" toggle.

## When to update

| Source | Cadence | What to look for |
|---|---|---|
| IMF WEO | Twice yearly (April, October) | Visit https://www.imf.org/en/publications/weo/weo-database and refresh Cuba/Venezuela/Argentina/Sudan/Zimbabwe/Lebanon entries |
| Hanke Troubled Currencies | Annual or as published | Watch the Cato Institute / Hopkins publications; he tweets updates too |

After editing, re-render `02b_load_inflation_supplements.qmd` (which lands
the data in DuckDB) and `08_build_panel.qmd` onward to refresh the model.
