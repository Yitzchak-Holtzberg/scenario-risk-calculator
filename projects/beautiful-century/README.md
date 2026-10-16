# Beautiful Century

Testing a thesis with data: **is long-run peace among rich democracies real,
and is it spreading?**

The argument being tested, in short:

1. Conquest has stopped paying, and rich democracies don't fight each other.
2. Once a country is a rich, durable democracy, it doesn't go back.
3. Abundance (wealth, health) makes populations harder to mobilize for war.
4. So as democracy and abundance spread, war among the major powers becomes
   a long-run anomaly — the "beautiful century."

The strongest counter-arguments to keep in view: the post-1945 peace is still
statistically young (Clauset 2018); Braumoeller (*Only the Dead*, 2019) finds
war-initiation rates haven't really fallen; rich autocracies (China, the Gulf)
aren't democratizing; and states can pay for or automate their way around a
reluctant population.

## Tests

| # | Question | Data | Status |
|---|---|---|---|
| 1 | **Democratic peace, electoral definition.** Do democracies coded on elections alone (ignoring rights indices) still never fight each other? How much does the answer move with the threshold? | V-Dem + dyadic war data (`peacesciencer`: COW MIDs / UCDP dyads) | Needs a dyadic loader |
| 2 | **Abundance peace.** Do richer, healthier countries *start* fewer wars once regime type is controlled for? (Gat vs. Braumoeller) | V-Dem `e_gdppc`, WDI health, war initiation | Needs a war-initiation loader |
| 3 | **Democratic ratchet.** Above what income level has no durable democracy ever broken down? (Przeworski et al.) List every reversal. | V-Dem only (already loaded) | `analysis/01_democratic_ratchet.qmd` — first draft |
| 4 | **Diversionary war.** Do growth slowdowns in autocracies precede conflict? (the China question) | V-Dem, WDI/IMF growth, UCDP / MIDs | Needs dyadic + initiation data |

Side track (not data-pipeline work): structured tests of Chinese-lab LLMs —
abstract vs. China-applied principles, Chinese vs. English prompts, and
agentic behaviour vs. stated values.

## Data

Reads the shared tables in `data/panel.duckdb` built by the loaders in
[`../../pipelines/`](../../pipelines/README.md). Tables this project writes
are prefixed `bc_` so they never collide with another project's.

New sources this project will need (add them as shared loaders under
`pipelines/`, since other projects could use them):

- **Dyadic conflict** — Correlates of War MIDs / wars, or UCDP dyadic, most
  easily via the R package [`peacesciencer`](https://svmiller.com/peacesciencer/),
  which builds country-pair-year panels with these merged.
- **War initiation** — who started it (COW originator / MID side A).

## Layout

```
projects/beautiful-century/
├── README.md
└── analysis/
    └── 01_democratic_ratchet.qmd   ← test 3
```

## Running

```sh
cd pipelines && quarto render 00_load_countries.qmd 01_load_vdem.qmd
cd ../projects/beautiful-century/analysis && quarto render
```

## Caveat that applies to every test

Rich countries are also democratic, US-allied, and nuclear-protected, so
separating causes is hard. Wars are rare and fat-tailed. Treat every result
as suggestive, not proof.
