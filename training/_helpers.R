# training/_helpers.R
# Shared utilities sourced from each .qmd's setup chunk:
#   source("_helpers.R")
#
# Three things live here:
#   - srs_palette  : color constants matching the dashboard
#   - srs_theme()  : ggplot theme block used in every plot-bearing notebook
#   - z_within()   : within-country z-score with NA-safety + winsorization
#   - cow_to_iso3(): countrycode wrapper, COW numeric -> ISO3 alpha-3
#
# IMPORTANT: SRS_WINSORIZE_BOUND below MUST match the same constant in
# web/index.html's `effectiveZValue` function. Both compute the same z and
# clip to the same range. The bound is also serialized into weights.json so
# the dashboard reads it from there at runtime (single source of truth).

SRS_WINSORIZE_BOUND <- 3

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

# Within-country z-score. NA-safe; returns NAs when too few non-missing obs.
# Winsorizes at +/-SRS_WINSORIZE_BOUND so a country with a tiny historical
# baseline (e.g., UK's near-zero refugee outflow) doesn't blow up when a
# small absolute number arrives. The dashboard's `effectiveZValue` mirrors
# this logic - they must stay in sync via weights.winsorize_bound.
z_within <- function(x, min_obs = 5) {
  if (sum(!is.na(x)) < min_obs) return(rep(NA_real_, length(x)))
  m <- mean(x, na.rm = TRUE)
  s <- sd(x, na.rm = TRUE)
  if (is.na(s) || s == 0) return(rep(0, length(x)))
  z <- (x - m) / s
  pmin(pmax(z, -SRS_WINSORIZE_BOUND), SRS_WINSORIZE_BOUND)
}

# Convenience wrapper around countrycode for the common COW->ISO3 conversion.
cow_to_iso3 <- function(x) {
  countrycode::countrycode(x, "cown", "iso3c", warn = FALSE)
}
