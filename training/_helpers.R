# Shared utilities for training/ notebooks.
# Sourced from each .qmd's setup chunk: source("_helpers.R")

# Parchment palette matching web/index.html and the mocks/.
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

# ggplot theme block. Use as: ggplot(...) + ... + srs_theme()
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
z_within <- function(x, min_obs = 5) {
  if (sum(!is.na(x)) < min_obs) return(rep(NA_real_, length(x)))
  m <- mean(x, na.rm = TRUE)
  s <- sd(x, na.rm = TRUE)
  if (is.na(s) || s == 0) return(rep(0, length(x)))
  (x - m) / s
}
