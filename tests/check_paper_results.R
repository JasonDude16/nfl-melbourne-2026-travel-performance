# Run from the project root after notebooks/analysis.qmd. Fixtures were captured from
# the final September 24 outputs before the September 25 code cleanup.
suppressPackageStartupMessages(library(tidyverse))

# Extract only chunks explicitly marked purl: true. These contain definitions,
# not data loading, analysis execution, exports, or calls back to this check.
# During notebook execution the definitions already exist in the parent session.
load_analysis_definitions <- function(envir) {
  output <- tempfile(fileext = ".R")
  notebook <- if (file.exists("notebooks/analysis.qmd")) {
    "notebooks/analysis.qmd"
  } else {
    "../notebooks/analysis.qmd"
  }
  previous_options <- knitr::opts_chunk$get()
  on.exit(
    {
      unlink(output)
      knitr::opts_chunk$restore(previous_options)
    },
    add = TRUE
  )

  knitr::opts_chunk$set(purl = FALSE)
  knitr::purl(
    notebook,
    output = output,
    documentation = 0L,
    quiet = TRUE
  )
  sys.source(output, envir = envir)
}

if (!exists("compare_with_reference", mode = "function", inherits = TRUE)) {
  load_analysis_definitions(environment())
}
historical <- readRDS(project_path("data", "derived", "historical_results.rds"))
melbourne <- readRDS(project_path("data", "derived", "melbourne_results.rds"))
comparisons <- bind_rows(historical$comparisons, melbourne$comparisons)
games <- bind_rows(historical$game_metrics, melbourne$game_metrics)
four <- metric_spec$metric[metric_spec$standardize]
stopifnot(
  nrow(games) == 14L, nrow(comparisons) == 224L,
  sum(!is.na(comparisons$standardized_score)) == 112L,
  all(is.na(comparisons$standardized_score) == !comparisons$metric %in% four),
  identical(historical$snapshot_date, "2026-09-24"),
  identical(melbourne$snapshot_date, historical$snapshot_date)
)

check_fixture <- function(actual, filename, keys) {
  expected <- read_csv(project_path("tests", "fixtures", filename), show_col_types = FALSE)
  stopifnot(
    nrow(actual) == nrow(expected), !anyDuplicated(actual[keys]), !anyDuplicated(expected[keys]),
    nrow(anti_join(expected, actual, by = keys)) == 0L
  )
  actual <- expected |>
    select(all_of(keys)) |>
    left_join(actual, by = keys)
  values <- setdiff(names(expected), keys)
  max_difference <- 0
  for (column in values) {
    x <- actual[[column]]
    y <- expected[[column]]
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
  tibble(
    check = filename, rows = nrow(expected), fields = length(values),
    max_absolute_difference = max_difference, passed = TRUE
  )
}
checks <- bind_rows(
  check_fixture(comparisons, "paper_comparisons.csv", c("season", "team", "game_id", "phase", "metric", "adjustment")),
  check_fixture(games, "paper_games.csv", c("season", "team", "game_id")),
  check_fixture(historical$context, "historical_context.csv", c("season", "team")),
  check_fixture(historical$team_game_metrics, "reference_games.csv", c("season", "team", "game_id"))
)

# Verify the three distinct reference populations independently of the exports.
for (i in seq_len(nrow(games))) {
  focal <- games[i, ]
  year <- if (focal$season == 2026L) 2025L else focal$season
  season <- historical$team_game_metrics |> filter(team == focal$team, season == year)
  reference <- season |> filter(game_id != focal$game_id)
  observed <- comparisons |> filter(
    team == focal$team, game_id == focal$game_id,
    metric == "off_epa_per_play", adjustment == "Unadjusted"
  )
  stopifnot(
    observed$reference_n_games == nrow(reference),
    abs(observed$season_mean - weighted.mean(season$off_epa_per_play, season$offensive_plays)) < 1e-12,
    abs(observed$reference_mean - mean(reference$off_epa_per_play)) < 1e-12,
    abs(observed$reference_sd - sd(reference$off_epa_per_play)) < 1e-12
  )
  league <- historical$league_game_metrics |> filter(season == year)
  opponent <- league |> filter(team == focal$opponent, game_id != focal$game_id)
  expected_adjustment <- focal$off_epa_per_play -
    (weighted.mean(opponent$def_epa_allowed, opponent$defensive_plays) -
      weighted.mean(league$off_epa_per_play, league$offensive_plays))
  stopifnot(abs(focal$adj_off_epa_per_play - expected_adjustment) < 1e-12)
}
stopifnot(
  all(historical$context$n_games == c(14L, 14L, 14L, 14L, 15L)),
  all(melbourne$comparisons$reference_n_games == 17L),
  all(melbourne$game_metrics$opponent_reference_n_games == 17L)
)

# Check that exceptional but eligible plays survive, and flagged kneels/spikes
# cannot enter any outcome even if a future source supplies run/pass flags.
pbp <- read_snapshot(project_path("data", "raw", "nflverse", "pbp_2010_asof_2026-09-24.rds"))
plays <- regular_plays(pbp)
stopifnot(
  !any(plays$qb_kneel == 1 | plays$qb_spike == 1, na.rm = TRUE),
  any(plays$game_id == "2010_10_STL_SF" & plays$qtr > 4 & !is.na(plays$epa)),
  any(plays$play_type == "no_play" & (plays$rush == 1 | plays$pass == 1) & !is.na(plays$epa)),
  any(plays$two_point_attempt == 1 & (plays$rush == 1 | plays$pass == 1) & !is.na(plays$epa))
)
probe <- plays |>
  slice(1) |>
  select(season_type, posteam, defteam, qb_kneel, qb_spike)
probe <- bind_rows(
  probe |> mutate(qb_kneel = 1, qb_spike = 0),
  probe |> mutate(qb_kneel = 0, qb_spike = 1)
)
stopifnot(nrow(regular_plays(probe)) == 0L)

write_analysis_csv(checks, project_path("validation", "numerical_checks.csv"))
print(checks)
cat(
  "PASS: 224 outcome comparisons, 112 standardized values, 14 game denominators,\n",
  "98 reference games, and reference/population checks.\n"
)
