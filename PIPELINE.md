# Pipeline overview — for students

This doc is your map. Read it before any of the notebooks. It explains
what the project is, what each step does, and which data-analytics
concepts each step illustrates.

The technical README (`README.md`) is for people who want to *run* the
project. This doc is for people who want to *learn* from the project.

---

## What the project does, in one paragraph

We build a tool that predicts, for each country in the world, the
probability of two kinds of political crisis in the next 12 months:
**mass mobilization** (large protests, often deadly) and **armed
violence or coup attempt**. The user picks a country in a web dashboard,
sees a probability with a confidence interval, and can move sliders
("what if inflation were 10% higher?") to explore scenarios.

The whole thing is just two trained statistical models (one per
outcome) whose coefficients live in a JSON file. The dashboard reads
the JSON and does the math in the browser. There is no backend at
runtime. The hard work — collecting data, joining sources, choosing
outcomes, fitting models — happens once in the training pipeline and
produces frozen artifacts.

## The data flow at a glance

```
                    +---------------+
                    |  RAW SOURCES  |  (downloaded from the internet)
                    +---------------+
                            |
                            v
   +-----+   +-----+   +-----+   +-----+   +-----+   +-----+
   | 00  |   | 01  |   | 02  |   | 03* |   | 04+ |   | 05+ |  ... 13 loaders
   | iso |   |VDem |   | WDI |   |event|   |refug|   |food | total
   +-----+   +-----+   +-----+   +-----+   +-----+   +-----+
       \       |        |        |          |        /
        +------+--------+--------+----------+-------+
                              |
                              v
                  +------------------------+
                  | 08 build_panel.qmd     |   one big table:
                  | country-year panel     |   one row = (country, year)
                  +------------------------+
                              |
                              v
                  +------------------------+
                  | 09 label_events.qmd    |   adds the outcome columns:
                  | outcome labels         |   did mobilization/violence
                  +------------------------+   happen next year?
                              |
                              v
                  +------------------------+
                  | 10 fit_model.qmd       |   fits two LASSO models
                  | LASSO regression       |   one per outcome
                  +------------------------+
                              |
                              v
                  +------------------------+
                  | 11 calibration.qmd     |   checks the model on
                  | holdout calibration    |   data it didn't see
                  +------------------------+
                              |
                              v
                  +------------------------+
                  | 12 export_artifacts    |   writes JSON files
                  | JSON for the dashboard |   the website will read
                  +------------------------+
                              |
                              v
                  +------------------------+
                  | web/index.html         |   country picker, sliders,
                  | static dashboard       |   probability cards
                  +------------------------+
```

Each block in the diagram corresponds to one `.qmd` file (R + Quarto
notebook) in the `training/` directory. The numbering is intentional —
files in order produce a coherent pipeline. You can re-run any single
notebook to refresh just that step.

## The two outcomes we predict

| Outcome | What it means | How we measure it |
|---|---|---|
| `outcome_mobilization` | Country-defining mass protest in the next 12 months | Did MMP record a protest with ≥0.1% of population participating? OR did V-Dem code "mass mobilization was a defining feature" (≥4 on a 0-4 scale)? OR did ACLED record ≥10 deaths in violent demonstrations? |
| `outcome_violence` | Armed conflict or coup attempt in the next 12 months | Did UCDP record ≥100 fatalities? OR did Cline Center record a coup attempt? OR did ACLED record ≥100 total fatalities? |

These are **OR-fused** from multiple data sources because no single
source catches everything. UCDP misses Mexican cartel violence; ACLED
misses pre-2018 Latin America protests; MMP ends in 2020. Combining
sources gives us coverage no single one provides. This is a real
data-analytics pattern that comes up constantly: **ensemble your data
sources, not just your models.**

## The features (predictors) we use, by category

The model has 14 predictors as of v0.7.1, grouped by what they measure:

**Regime quality** (slow-moving structural features):
- `civil_liberties` — V-Dem's 0-1 index of free speech, assembly, etc.
- `loser_consent` — V-Dem's 0-4 scale of whether election losers accept results
- `coup_proof_fragmentation` — how fragmented the military is (Pilster-Böhmelt)

**Economic stress**:
- `log_gdp_per_cap` — wealth level (rich countries are more stable)
- `gdp_growth` — annual % change (sharp drops drive unrest)
- `cpi_inflation` — annual % (clipped to handle hyperinflation outliers)
- `unemployment` — % of labor force (with curated supplements for state-managed economies)

**Recent history** (lagged by 1 year so it's available at prediction time):
- `political_violence_ord_lag1` — V-Dem 0-4 of last year's violence
- `mass_mobilization_ord_lag1` — V-Dem 0-4 of last year's protests
- `log_acled_violent_demo_fat_per_cap_lag1` — deaths in protests last year
- `log_acled_pv_fat_per_cap_lag1` — deaths in armed conflict last year

**Context**:
- `conflict_neighbors_count` — bordering countries in armed conflict
- `log_refugee_outflow` — UNHCR outflow as a stress signal

**Missing-indicator**:
- `acled_covered_lag1` — was ACLED actually covering this country last year?

## Why so much data work for "just" a logistic regression?

This is the most important pedagogical point in the project, and it
generalizes well beyond political risk:

> **The model is the easy part. The data preparation is where the
> intelligence of the analysis lives.**

The actual `glmnet::cv.glmnet(...)` call in `10_fit_model.qmd` is six
lines. The notebooks 00-09 (every step before fitting) are over 2,000
lines of code. That ratio is normal in real-world data analysis, and
it's the lesson that's hardest to internalize from a textbook.

What those 2,000 lines do:
- Pull data from 10+ different sources, each with its own format
- Reconcile country names → standard ISO codes (V-Dem uses one
  numbering, UCDP uses another, ACLED just uses country names)
- Handle missing data honestly (NA → listwise drop, not synthetic fill)
- Heavy-tail transforms (`log1p` for fatalities, clipping for hyperinflation)
- Define what we're predicting (the outcome label) carefully enough that
  the model isn't predicting itself
- Lag features by 1 year so we're not "predicting" the past

## Data-analytics concepts demonstrated, by notebook

| Notebook | Core concepts students see in action |
|---|---|
| `00_load_countries.qmd` | ISO country codes, master reference tables, joining identifier systems |
| `01_load_vdem.qmd` | Working with a complex domain dataset (~4,600 columns); selecting a relevant subset |
| `02_load_wdi.qmd` | API-driven data ingestion; REST API patterns in R |
| `02b_load_inflation_supplements.qmd` | Hand-curated data overrides; data quality flags; transparency about manual edits |
| `03a_load_mmp.qmd` | Per-capita normalization; aggregating event data to country-year |
| `03b_load_ucdp.qmd` | Working with 240MB+ raw datasets; memory-efficient column selection |
| `03c_load_coups.qmd` | Mapping between country-code systems (COW → ISO3) |
| `03d_load_fariss.qmd` | Loading data you decide NOT to use (collinearity diagnostics) |
| `03e_load_polity.qmd` | Same; honest about what was excluded from the final model |
| `03f_load_acled.qmd` | Aggregating fine-grained data (week × admin1 × event_type × sub_event_type); media-availability bias |
| `04_load_unhcr.qmd` | Origin-vs-destination accounting (net outflow ≠ gross) |
| `05_load_fao.qmd` | Time-series data at different temporal grain (monthly → annual) |
| `06_load_pb.qmd` | Auto-fetching from data repositories (Harvard Dataverse) |
| `07_load_debruin.qmd` | Recognizing when data is too sparse to use (coverage ends 2010) |
| `08_build_panel.qmd` | Multi-source joins; the COALESCE chain for source priority; heavy-tail transforms; lagged features |
| `09_label_events.qmd` | Defining outcomes carefully; multi-source OR-fusion; future-leakage (why we lag); the difference between "no data" and "no event" |
| `10_fit_model.qmd` | Logistic regression; LASSO regularization; monotonicity constraints; bootstrap confidence intervals; stratified models |
| `11_calibration.qmd` | Holdout evaluation; Brier score; Brier skill score; reliability diagrams |
| `12_export_artifacts.qmd` | Freezing model artifacts; in-browser inference; design for static deployment |
| `13_export_views_overlay.qmd` | Comparing your model against an external benchmark (ViEWS at PRIO) |
| `_helpers.R` | Shared utility functions; consistent visual style across notebooks |

## Honest limitations of the project (taught explicitly)

Real data analysis has limits. We document ours rather than hiding them:

1. **Mobilization is hard to predict at 1-year horizon.** Brier skill
   score is barely positive (+0.02). Structural features can't see the
   trigger events (a single death, a court ruling, a price hike) that
   actually start protest movements. Honest finding.
2. **Closed regimes are systematically under-reported.** ACLED, MMP,
   UCDP, V-Dem all rely on media sources that don't function inside
   North Korea / Eritrea / Turkmenistan. Our predictions for those
   countries reflect *observed* unrest, not *true* unrest. The
   structural fix is a Heckman / Bayesian censored-outcome model,
   which is queued for v1.
3. **Country-year, not country-month.** All our covariates are annual.
   A model at country-month granularity would be 12× the rows with no
   new information until we have real-time event data (ACLED can
   support that for v1).
4. **Annual cadence of structural data.** V-Dem releases yearly with a
   1-year lag. WDI revises retroactively. The model card is stamped
   with the data vintage so users know how stale the snapshot is.
5. **The ACLED license is restrictive.** Raw event data can't be
   redistributed. We aggregate to country-year inside DuckDB and only
   ship aggregates; the raw files are gitignored.

## How to run the pipeline (for students who want to reproduce results)

Install once (in R):

```r
install.packages(c("DBI", "duckdb", "ggplot2", "remotes", "WDI",
                   "httr2", "jsonlite", "countrycode", "readxl",
                   "haven", "glmnet"))
remotes::install_github("vdeminstitute/vdemdata")
```

Render notebooks in order (in a terminal at the project root):

```sh
cd training
quarto render 00_load_countries.qmd
quarto render 01_load_vdem.qmd
# ... through 12_export_artifacts.qmd
```

Or render the whole pipeline at once: `cd training && quarto render`.

Each `.qmd` produces an `.html` you can open in a browser to see the
narrative, tables, and plots from that step.

## Where to put your own work

If you're using this project to learn, here are good entry points:

- **Add a new data source** — create `03g_load_yoursource.qmd`
  following the pattern of `03c_load_coups.qmd` (it's the simplest).
  Then add a join in `08_build_panel.qmd` and an OR-channel in
  `09_label_events.qmd` if it's an outcome source.
- **Try a different model** — `10_fit_model.qmd` uses LASSO logistic
  regression. Swap in random forest, gradient boosting, or a neural
  network. Compare calibration in `11`.
- **Build a new dashboard view** — the JSON artifacts in `artifacts/`
  are what the dashboard reads. Write your own HTML/JS that consumes
  them.
- **Run a counterfactual analysis** — pick a country, change one input
  feature, see how the prediction changes. The dashboard already does
  this with sliders; you can do it more systematically.

## Glossary of domain terms

- **ACLED** — Armed Conflict Location & Event Data Project. Real-time
  event coding of political violence and protests, from news sources.
- **Brier score** — a measure of probabilistic forecast accuracy. Lower
  is better. Mathematically: average squared error between predicted
  probability and observed outcome (0 or 1).
- **Brier skill score (BSS)** — `1 − (your Brier) / (baseline Brier)`.
  Positive = your model beats predicting the base rate. Negative = your
  model is worse than ignoring the features.
- **CCP** — Cuban Conflict Observatory; one of the curated sources we
  use for hand-coded protest events.
- **Cline Center** — University of Illinois group that maintains the
  Coup d'État Project dataset.
- **CoW / COW** — Correlates of War. A country-numbering system used
  by several political-science datasets.
- **Coup proofing** — government strategies to make a successful coup
  harder (e.g., fragmenting the military into multiple competing
  branches).
- **Fariss** — Christopher Fariss's latent human-rights protection
  index, a Bayesian-derived continuous score.
- **GDELT** — Global Database of Events, Language, and Tone. Machine-
  coded events from news (we don't use it yet, but it's roadmap).
- **glmnet** — the R package that fits LASSO/ridge/elastic-net
  regularized regressions.
- **GW / Gleditsch-Ward** — another country-numbering system.
- **Heckman model** — a two-stage statistical model that corrects for
  selection bias. First stage models "is this observation visible to
  us?"; second stage models "given visibility, what's the outcome?"
- **iso3c** — three-letter ISO country code (USA, CUB, IRN, etc.).
- **LASSO** — Least Absolute Shrinkage and Selection Operator. A type
  of regularized regression that pushes some coefficients to exactly
  zero, automatically doing feature selection.
- **Listwise drop** — removing entire rows that have any missing values
  on the columns being used. The honest alternative to imputing.
- **MMP** — Mass Mobilization Project. Hand-coded large protest events
  1990-2020 from Clark & Regan.
- **Monotonicity constraint** — forcing a coefficient to be ≥0 or ≤0
  based on substantive theory. Prevents the model from learning
  counterintuitive signs from spurious correlations.
- **Pilster-Böhmelt** — the political scientists who built the
  counterbalancing dataset measuring military fragmentation.
- **PITF** — Political Instability Task Force. The U.S.-government
  funded research program (Goldstone et al.) that established the
  methodology this project descends from.
- **Polity** — a long-running dataset rating countries on a
  democracy-autocracy scale. Coverage ends 2018 so we don't use it in
  the current fit.
- **Reliability diagram** — a plot showing whether predicted
  probabilities match observed frequencies. If you predict 30% for a
  bin of country-years, ideally ~30% of them should actually have the
  event.
- **RoW** — Regimes of the World. V-Dem's 4-category regime
  classification (closed autocracy / electoral autocracy / electoral
  democracy / liberal democracy).
- **UCDP** — Uppsala Conflict Data Program. Hand-coded armed conflict
  events 1989-present.
- **V-Dem** — Varieties of Democracy. Comprehensive expert-coded
  dataset of political institutions and behaviors, ~4,600 variables.
- **WDI** — World Development Indicators (World Bank). Macroeconomic
  and demographic indicators.
- **WLF** — Woman, Life, Freedom. Iran's 2022-2023 protest movement
  after Mahsa Amini's death in custody. Canonical example of a
  mobilization episode our model needs to capture.

## A note for the instructor

This project shows real data analysis at its messy, full-scope worst:

- 10+ data sources, none of which agree on country names or year
  conventions
- Outcomes that have to be defined carefully because real-world
  "unrest" doesn't have a single ground-truth measurement
- Models that don't predict the thing students *want* to predict
  (mobilization at 1-year horizon is genuinely hard) and require
  students to confront the honest finding
- Real ethical/legal constraints (ACLED's license, censored regimes)
  that shape what the project can do

It's intentionally bigger than a textbook example. The point is for
students to see the full lifecycle of an analysis where the data is
the hard part. Suggested teaching arc:

1. **Week 1-2**: PIPELINE.md + run `00`-`02b`. Concepts: identifier
   systems, joining data from multiple sources, REST APIs in R.
2. **Week 3-4**: `03a`-`03f` + `04`-`07`. Concepts: aggregating event
   data to a panel grain, per-capita normalization, recognizing when
   data is too sparse/biased to use.
3. **Week 5-6**: `08`-`09`. Concepts: joins at scale, defining outcomes
   carefully, future-leakage and why we lag, the difference between
   "no event" and "no data."
4. **Week 7-8**: `10`-`11`. Concepts: logistic regression, LASSO,
   regularization, monotonicity constraints, bootstrap CIs, calibration.
5. **Week 9**: `12`-`13` + the dashboard. Concepts: shipping a model
   (frozen artifacts, in-browser inference), benchmarking against
   external models.
6. **Final project**: extend the pipeline. Add a new data source, swap
   in a different model, or build a new dashboard view.

Each notebook now has a teaching block at the top explaining the
concepts it demonstrates. Use those as discussion prompts.
