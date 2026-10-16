# pipelines — shared data loaders (R + Quarto)

Source-by-source loaders shared by every project in this repo. Each notebook
pulls one source, tidies it to a standard grain (usually `iso3c × year`), and
lands one or more named tables in the shared DuckDB file at
`../data/panel.duckdb`. **No modelling or project-specific feature engineering
happens here** — that lives under `../projects/<name>/analysis/`.

Rule of thumb: if two projects could use it, it's a pipeline. If it encodes
one project's modelling choices (feature transforms, outcome labels, fits),
it belongs to that project.

## Bootstrap

Install R, Quarto, and the R packages:

```r
install.packages(c("DBI", "duckdb", "ggplot2", "remotes", "WDI",
                   "httr2", "jsonlite", "countrycode", "readxl", "haven"))
remotes::install_github("vdeminstitute/vdemdata")
```

ACLED credentials (if refreshing via API) go in `~/.Renviron` — on Windows
that's `Documents\.Renviron`, not the user-profile root:

```
ACLED_EMAIL=your_email
ACLED_PASSWORD=your_password
```

## Loaders

Run `00` first — every other loader joins through its `countries` table.
After that, loaders are independent; re-render any one to refresh its tables.

| Step | Notebook | Lands table(s) | Notes |
|---|---|---|---|
| 0 | `00_load_countries.qmd` | `countries` | Master reference: ISO3, Gleditsch-Ward, V-Dem id, region |
| 1 | `01_load_vdem.qmd` | `vdem` | V-Dem v16, ~28K country-years (wide) |
| 2 | `02_load_wdi.qmd` | `wdi` | World Bank WDI |
| 2b | `02b_load_inflation_supplements.qmd` | `imf_inflation`, `imf_weo`, `imf_weo_gdp_growth`, `imf_weo_gdp_pc`, `hanke_inflation`, `unemployment_curated` | IMF WEO + hand-curated backfills (reads `../data/curated/`) |
| 3a | `03a_load_mmp.qmd` | `mmp_annual` | Mass Mobilization Project, 1990–2020 |
| 3b | `03b_load_ucdp.qmd` | `ucdp_annual` | UCDP GED v25.1, fatalities by country-year |
| 3c | `03c_load_coups.qmd` | `coups_annual` | Cline Center coups, 1945– |
| 3d | `03d_load_fariss.qmd` | `fariss_hr` | Fariss latent human-rights scores |
| 3e | `03e_load_polity.qmd` | `polity5` | Polity5, 1800–2018 |
| 3f | `03f_load_acled.qmd` | `acled_annual` | ACLED country-year aggregates (raw files gitignored — no redistribution) |
| 4 | `04_load_unhcr.qmd` | `unhcr`, `unhcr_inflow` | UNHCR by origin / destination |
| 5 | `05_load_fao.qmd` | `fao` | FAO Food Price Index, monthly global |
| 6 | `06_load_pb.qmd` | `pb_counterbalancing` | Pilster-Böhmelt coup-proofing |
| 7 | `07_load_debruin.qmd` | `security_forces` | de Bruin State Security Forces, 1960–2010 |

Manual downloads and where to put them are listed in [`../data/README.md`](../data/README.md).

## Rendering

```sh
cd pipelines
quarto render 00_load_countries.qmd   # one loader
quarto render                         # all loaders
```

## Shared helpers

`_helpers.R` is sourced by loaders here and by project notebooks
(`source("../../../pipelines/_helpers.R")`):

- `srs_palette`, `srs_theme()` — shared plot styling
- `cow_to_iso3(x)` — Correlates-of-War numeric → ISO3
- `srs_table()` — consistent HTML tables in notebook output

## Adding a loader

Copy `03c_load_coups.qmd` (the simplest), give it the next free number, write
one table keyed on `(iso3c, year)` joined through `countries`, and add a row
to the table above and to [`../data/README.md`](../data/README.md).
