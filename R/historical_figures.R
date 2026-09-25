# The two historical figures use the same validated comparisons as the text.
build_historical_figures <- function(game_metrics, context, comparisons) {
  team_highlight_colors <- c(SF = "#AA0000", LA = "#003594")
  season_team_levels <- c("2010\n49ers", "2013\n49ers", "2017\nRams", "2019\nRams", "2025\nRams")
  outcome_data <- bind_rows(
    game_metrics |> select(season, team, phase, scoring_margin, performance_vs_market) |>
      mutate(comparison = if_else(phase == "international", "International game", "Following game")) |>
      select(-phase),
    context |> select(season, team, scoring_margin, performance_vs_market) |>
      mutate(comparison = "Season average")
  ) |>
    pivot_longer(c(scoring_margin, performance_vs_market), names_to = "metric", values_to = "value") |>
    mutate(
      comparison = factor(comparison, levels = c("Season average", "Following game", "International game")),
      season_team = factor(paste(season, if_else(team == "SF", "49ers", "Rams"), sep = "\n"),
                           levels = season_team_levels),
      bar_style = case_when(
        comparison == "Season average" ~ "Season average",
        team == "SF" & comparison == "International game" ~ "49ers international game",
        team == "SF" ~ "49ers following game",
        comparison == "International game" ~ "Rams international game",
        TRUE ~ "Rams following game"))
  scoring_margin_baseline_plot_data <- outcome_data |> filter(metric == "scoring_margin")
  market_baseline_plot_data <- outcome_data |> filter(metric == "performance_vs_market")
  plot_data <- comparisons |>
    filter(!is.na(standardized_score)) |>
    mutate(
      adjustment = factor(adjustment, levels = c("Unadjusted", "Opponent adjusted")),
      label = factor(label, levels = c("Defensive success rate allowed", "Defensive EPA allowed per play",
                                      "Offensive success rate", "Offensive EPA per play")),
      season_team = factor(paste(season, if_else(team == "SF", "49ers", "Rams"), sep = "\n"),
                           levels = season_team_levels),
      bar_style = case_when(adjustment == "Unadjusted" ~ "Unadjusted",
                            team == "SF" ~ "49ers opponent adjusted", TRUE ~ "Rams opponent adjusted"),
      bar_style = factor(bar_style, levels = c("Unadjusted", "49ers opponent adjusted", "Rams opponent adjusted")))
  market_bar_colors <- c(
    "49ers international game" = unname(team_highlight_colors["SF"]),
    "49ers following game" = "#D65A4A",
    "Rams international game" = unname(team_highlight_colors["LA"]),
    "Rams following game" = "#5B7DBE",
    "Season average" = "gray60"
  )

  make_outcome_baseline_plot <- function(data, panel_title, axis_title) {
    ggplot(
      data,
      aes(x = comparison, y = value, fill = bar_style)
    ) +
      geom_col(width = 0.46) +
      geom_hline(yintercept = 0, color = "#666666", linewidth = 0.45) +
      geom_text(
        aes(
          label = sprintf("%+.1f", value),
          hjust = if_else(value >= 0, -0.15, 1.15)
        ),
        color = "#111827",
        size = 2.95
      ) +
      coord_flip(clip = "off") +
      facet_wrap(vars(season_team), nrow = 1) +
      scale_fill_manual(values = market_bar_colors, guide = "none") +
      scale_y_continuous(
        # Leave room for end labels inside every facet at publication width.
        limits = c(-20, 50),
        breaks = seq(-20, 40, by = 20),
        expand = expansion(mult = c(0, 0))
      ) +
      labs(
        title = panel_title,
        x = NULL,
        y = axis_title,
        fill = NULL
      ) +
      manuscript_theme() +
      theme(
        text = element_text(family = "sans", color = "#111827"),
        panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(color = "#E5E7EB", linewidth = 0.3),
        panel.spacing.x = grid::unit(0.7, "lines"),
        strip.background = element_blank(),
        strip.text = element_text(face = "bold", size = 10),
        axis.title = element_text(size = 10),
        axis.text.x = element_text(size = 8.5, color = "#374151"),
        axis.text.y = element_text(size = 9.5, color = "#111827"),
        legend.position = "none",
        plot.title = element_text(face = "bold", size = 13,
                                  margin = margin(b = 8)),
        plot.margin = margin(10, 5.5, 5.5, 5.5)
      )
  }

  scoring_margin_baseline_plot <- make_outcome_baseline_plot(
    scoring_margin_baseline_plot_data,
    "(A) Scoring margin",
    "Scoring margin (points)"
  )

  market_baseline_plot <- make_outcome_baseline_plot(
    market_baseline_plot_data,
    "(B) Performance versus market",
    "Points above or below market expectation"
  )

  historical_outcome_baseline_plot <- patchwork::wrap_plots(
    scoring_margin_baseline_plot,
    market_baseline_plot,
    ncol = 1
  )


  baseline_bar_colors <- c(
    "Unadjusted" = "gray60",
    "49ers opponent adjusted" = unname(team_highlight_colors["SF"]),
    "Rams opponent adjusted" = unname(team_highlight_colors["LA"])
  )

  historical_return_figure_metrics <- c(
    "off_epa_per_play",
    "off_success_rate",
    "def_epa_allowed",
    "def_success_rate_allowed"
  )

  historical_international_plot_data <- plot_data |>
    filter(phase == "international") |>
    filter(metric %in% historical_return_figure_metrics)

  historical_return_plot_data <- plot_data |>
    filter(phase == "return") |>
    filter(metric %in% historical_return_figure_metrics)

  stopifnot(
    nrow(historical_international_plot_data) == 40L,
    nrow(historical_return_plot_data) == 40L,
    !anyNA(historical_international_plot_data$standardized_score),
    !anyNA(historical_return_plot_data$standardized_score)
  )

  full_season_standardized_axis_limit <- ceiling(
    max(
      abs(historical_international_plot_data$standardized_score),
      abs(historical_return_plot_data$standardized_score),
      na.rm = TRUE
    ) * 2
  ) / 2

  make_baseline_bar_plot <- function(
    data,
    value_column,
    panel_title,
    axis_limit,
    break_interval = 1
  ) {
    axis_break_limit <- floor(axis_limit / break_interval) * break_interval

    ggplot(
      data,
      aes(
        x = label,
        y = .data[[value_column]],
        fill = bar_style,
        group = adjustment
      )
    ) +
      geom_col(
        position = position_dodge(width = 0.62),
        width = 0.52
      ) +
      geom_hline(yintercept = 0, color = "#666666", linewidth = 0.45) +
      coord_flip() +
      facet_wrap(vars(season_team), nrow = 1) +
      scale_fill_manual(
        values = baseline_bar_colors,
        breaks = c("49ers opponent adjusted", "Rams opponent adjusted", "Unadjusted")
      ) +
      scale_y_continuous(
        limits = c(-(axis_limit + 1), axis_limit + 1),
        breaks = seq(
          -axis_break_limit,
          axis_break_limit,
          by = break_interval
        )
      ) +
      labs(
        title = panel_title,
        x = NULL,
        y = "Standardized difference from baseline",
        fill = NULL
      ) +
      manuscript_theme() +
      theme(
        text = element_text(family = "sans", color = "#111827"),
        legend.position = "bottom",
        panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(color = "#E5E7EB", linewidth = 0.3),
        panel.spacing.x = grid::unit(0.7, "lines"),
        strip.background = element_blank(),
        strip.text = element_text(face = "bold", size = 10),
        axis.title = element_text(size = 10),
        axis.text.x = element_text(size = 8.5, color = "#374151"),
        axis.text.y = element_text(size = 9.5, color = "#111827"),
        legend.text = element_text(size = 9),
        legend.key.size = grid::unit(11, "pt"),
        legend.spacing.x = grid::unit(4, "pt"),
        plot.title = element_text(face = "bold", size = 13,
                                  margin = margin(b = 8)),
        plot.margin = margin(10, 5.5, 5.5, 5.5)
      )
  }

  full_season_plot <- make_baseline_bar_plot(
    historical_international_plot_data,
    "standardized_score",
    "(A) International game",
    full_season_standardized_axis_limit,
    break_interval = 2
  ) +
    labs(y = NULL)

  return_full_season_plot <- make_baseline_bar_plot(
    historical_return_plot_data,
    "standardized_score",
    "(B) Following game",
    full_season_standardized_axis_limit,
    break_interval = 2
  )

  international_return_full_season_plot <- patchwork::wrap_plots(
    full_season_plot,
    return_full_season_plot,
    ncol = 1
  ) +
    patchwork::plot_layout(guides = "collect") &
    theme(legend.position = "bottom")


  list(outcomes = historical_outcome_baseline_plot, performance = international_return_full_season_plot)
}
