# Run after the notebook in archive mode, from the project root or notebooks/.
# Fixtures preserve the submitted paper's September 24 results.
suppressPackageStartupMessages(library(tidyverse))

root <- if (file.exists("_quarto.yml")) "." else ".."
if (!file.exists(file.path(root, "_quarto.yml"))) {
  stop("Run this check from the project root or notebooks directory.")
}

project_path <- function(...) {
  return(file.path(normalizePath(root), ...))
}

result_paths <- project_path("data", "derived", c("historical_results.rds", "melbourne_results.rds"))
if (!all(file.exists(result_paths))) {
  stop('Run notebooks/analysis.qmd with data_source = "archive" before checking paper results.')
}

historical_results_list <- readRDS(result_paths[1])
melbourne_results_list <- readRDS(result_paths[2])
if (!identical(historical_results_list$provenance$source, "archive") ||
    !identical(melbourne_results_list$provenance$source, "archive") ||
    !identical(historical_results_list$snapshot_date, "2026-09-24") ||
    !identical(melbourne_results_list$snapshot_date, "2026-09-24")) {
  stop("This check requires results from the September 24, 2026 archive.")
}

df_comparisons <- bind_rows(historical_results_list$comparisons, melbourne_results_list$comparisons)
df_games <- bind_rows(historical_results_list$game_metrics, melbourne_results_list$game_metrics)
standardized_metrics <- c("off_epa_per_play", "def_epa_allowed", "off_success_rate", "def_success_rate_allowed")
stopifnot(
  nrow(df_games) == 14L, nrow(df_comparisons) == 224L,
  sum(!is.na(df_comparisons$standardized_score)) == 112L,
  all(is.na(df_comparisons$standardized_score) == !df_comparisons$metric %in% standardized_metrics)
)

check_fixture <- function(df_actual, filename, keys) {
  df_expected <- read_csv(project_path("tests", "fixtures", filename), show_col_types = FALSE)
  stopifnot(
    all(names(df_expected) %in% names(df_actual)),
    nrow(df_actual) == nrow(df_expected), !anyDuplicated(df_actual[keys]), !anyDuplicated(df_expected[keys]),
    nrow(anti_join(df_expected, df_actual, by = keys)) == 0L
  )
  df_actual <- df_expected |>
    select(all_of(keys)) |>
    left_join(df_actual, by = keys)
  values <- setdiff(names(df_expected), keys)
  max_difference <- 0
  for (column in values) {
    x <- df_actual[[column]]
    y <- df_expected[[column]]
    stopifnot(identical(is.na(x), is.na(y)))
    present <- !is.na(y)
    if (is.numeric(y)) {
      difference <- abs(x[present] - y[present])
      stopifnot(all(difference <= 1e-12))
      # Covers the paper's displayed precision, including rates multiplied by 100.
      for (digits in 0:3) stopifnot(all(round(x[present], digits) == round(y[present], digits)))
      if (column %in% c("target_value", "season_mean")) {
        stopifnot(all(round(100 * x[present], 1) == round(100 * y[present], 1)))
      }
      max_difference <- max(max_difference, difference)
    } else {
      stopifnot(all(x[present] == y[present]))
    }
  }
  df_check <- tibble(
    check = filename, rows = nrow(df_expected), fields = length(values),
    max_absolute_difference = max_difference
  )
  return(df_check)
}
df_checks <- bind_rows(
  check_fixture(df_comparisons, "paper_comparisons.csv", c("season", "team", "game_id", "phase", "metric", "adjustment")),
  check_fixture(df_games, "paper_games.csv", c("season", "team", "game_id")),
  check_fixture(historical_results_list$context, "historical_context.csv", c("season", "team")),
  check_fixture(historical_results_list$team_game_metrics, "reference_games.csv", c("season", "team", "game_id"))
)

# Verify the three distinct reference populations independently of the exports.
for (i in seq_len(nrow(df_games))) {
  df_focal <- df_games[i, ]
  year <- if (df_focal$season == 2026L) 2025L else df_focal$season
  df_season <- historical_results_list$team_game_metrics |> filter(team == df_focal$team, season == year)
  df_reference <- df_season |> filter(game_id != df_focal$game_id)
  df_observed <- df_comparisons |> filter(
    team == df_focal$team, game_id == df_focal$game_id,
    metric == "off_epa_per_play", adjustment == "Unadjusted"
  )
  stopifnot(
    nrow(df_observed) == 1L,
    df_observed$reference_n_games == nrow(df_reference),
    abs(df_observed$season_mean - weighted.mean(df_season$off_epa_per_play, df_season$offensive_plays)) < 1e-12,
    abs(df_observed$reference_mean - mean(df_reference$off_epa_per_play)) < 1e-12,
    abs(df_observed$reference_sd - sd(df_reference$off_epa_per_play)) < 1e-12
  )
  df_league <- historical_results_list$league_game_metrics |> filter(season == year)
  df_opponent <- df_league |> filter(team == df_focal$opponent, game_id != df_focal$game_id)
  expected_adjustment <- df_focal$off_epa_per_play -
    (weighted.mean(df_opponent$def_epa_allowed, df_opponent$defensive_plays) -
      weighted.mean(df_league$off_epa_per_play, df_league$offensive_plays))
  stopifnot(abs(df_focal$adj_off_epa_per_play - expected_adjustment) < 1e-12)
}
stopifnot(
  all(historical_results_list$context$n_games == c(14L, 14L, 14L, 14L, 15L)),
  all(melbourne_results_list$comparisons$reference_n_games == 17L),
  all(melbourne_results_list$game_metrics$opponent_reference_n_games == 17L)
)

dir.create(project_path("validation"), showWarnings = FALSE)
write_csv(df_checks, project_path("validation", "numerical_checks.csv"))
print(df_checks)
cat("Checked 224 comparisons, 112 standardized values, 14 selected team-games,\n",
    "98 reference games, and reference/population calculations.\n")
