# training/_helpers.R
# Shared utilities sourced from each .qmd's setup chunk:
#   source("_helpers.R")
#
# v0.4: z_within() and SRS_WINSORIZE_BOUND are gone — the model uses raw
# cross-country feature levels. Notebooks that need to clip outliers do so
# inline (see 08_build_panel.qmd for cpi_inflation clipping).
#
# Two things live here:
#   - srs_palette  : color constants matching the dashboard
#   - srs_theme()  : ggplot theme block used in every plot-bearing notebook
#   - cow_to_iso3(): countrycode wrapper, COW numeric -> ISO3 alpha-3

srs_palette <- list(
  parchment = "#F8F3E8",
  ink       = "#2A2620",
  ink_muted = "#6B5D4F",
  border    = "#D8CFC0",
  accent    = "#1F3A60",
  crisis    = "#8B2E2E",
  positive  = "#8B3A2B",
  negative  = "#2E5D3F"
)

# ggplot theme matching the dashboard parchment design language.
# Use as:  ggplot(...) + ... + srs_theme()
srs_theme <- function(base_size = 12) {
  ggplot2::theme_minimal(base_family = "serif", base_size = base_size) +
    ggplot2::theme(
      plot.background  = ggplot2::element_rect(fill = srs_palette$parchment, color = NA),
      panel.background = ggplot2::element_rect(fill = srs_palette$parchment, color = NA),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(color = srs_palette$border),
      axis.text        = ggplot2::element_text(color = srs_palette$ink),
      axis.title       = ggplot2::element_text(color = srs_palette$ink),
      plot.caption     = ggplot2::element_text(color = srs_palette$ink_muted, face = "italic")
    )
}

# Convenience wrapper around countrycode for the common COW->ISO3 conversion.
cow_to_iso3 <- function(x) {
  countrycode::countrycode(x, "cown", "iso3c", warn = FALSE)
}

# Render a data frame as a styled HTML table in notebook output. The cosmo
# Bootstrap theme styles `.table` automatically; this wrapper just ensures
# consistent decimals, alignment, and an optional caption.
#
# big_mark = TRUE adds thousands separators — gate it on tables that are
# integer-only counts, since otherwise year columns render as "2,015".
#
# Usage:
#   srs_table(df)
#   srs_table(df, digits = 3, caption = "Cuba — selected V-Dem indices")
#   srs_table(count_df, big_mark = TRUE)
srs_table <- function(x, caption = NULL, digits = 3, align = NULL, big_mark = FALSE) {
  fa <- if (big_mark) list(big.mark = ",", scientific = FALSE) else list()
  knitr::kable(
    x,
    caption = caption,
    digits = digits,
    align = align,
    format.args = fa,
    format = "html",
    table.attr = 'class="table table-sm"'
  )
}
