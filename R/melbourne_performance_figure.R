# Build the approved four-measure Melbourne figure from analysis results.
# The figure selects EPA and success rates; the analysis retains all seven outcomes.
build_melbourne_performance_figure <- function(comparison, adjusted_comparison, game_metrics) {
  team_colors <- c("SF" = "#AA0000", "LA" = "#003594")
  unadjusted_color <- "gray60"
  zero_line_color <- "#666666"
  zero_line_width <- 0.45
  bar_dodge <- position_dodge(width = 0.76)
  legend_order <- c("49ers opponent adjusted", "Rams opponent adjusted", "Unadjusted")

  # Compact enough to retain readable labels when reduced to a two-column page.
  publication_theme <- function() {
    manuscript_theme() +
      theme(
        text = element_text(family = "sans", color = "#111827"),
        plot.title.position = "plot",
        plot.title = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(color = "#4B5563", size = 9,
                                     margin = margin(b = 7)),
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 9, color = "#374151"),
        panel.grid.major.x = element_line(color = "#E5E7EB", linewidth = 0.3),
        legend.text = element_text(size = 9),
        legend.key.size = grid::unit(11, "pt"),
        legend.spacing.x = grid::unit(4, "pt")
      )
  }

  plot_metrics <- c(
    "off_epa_per_play",
    "off_success_rate",
    "def_epa_allowed",
    "def_success_rate_allowed"
  )

  metric_label_lookup <- c(
    "off_epa_per_play" = "Offensive EPA per play",
    "off_success_rate" = "Offensive success rate",
    "def_epa_allowed" = "Defensive EPA allowed per play",
    "def_success_rate_allowed" = "Defensive success rate allowed"
  )

  format_native_value <- function(metric, value) {
    case_when(
      metric %in% c("off_epa_per_play", "def_epa_allowed") ~
        sprintf("%+.3f", value),
      metric %in% c(
        "off_success_rate",
        "def_success_rate_allowed"
      ) ~ sprintf("%.1f%%", value * 100),
      TRUE ~ as.character(value)
    )
  }

  prepare_plot_data <- function(metrics) {
    raw_data <- comparison |>
      filter(metric %in% metrics) |>
      transmute(
        team,
        metric,
        native_value = target_value,
        native_label = format_native_value(metric, target_value)
      )

    standardized_data <- bind_rows(
      comparison |>
        filter(metric %in% metrics) |>
        transmute(
          team,
          metric,
          adjustment = "Unadjusted",
          native_value = target_value,
          standardized_score
        ),
      adjusted_comparison |>
        filter(metric %in% metrics) |>
        transmute(
          team,
          metric,
          adjustment = "Opponent adjusted",
          native_value = target_value,
          standardized_score
        )
    )

    expected_pairs <- tidyr::expand_grid(team = c("SF", "LA"), metric = metrics)
    raw_pairs <- raw_data |> distinct(team, metric)
    standardized_pairs <- standardized_data |> distinct(team, metric, adjustment)

    stopifnot(
      nrow(raw_data) == length(metrics) * 2L,
      nrow(standardized_data) == length(metrics) * 4L,
      nrow(anti_join(expected_pairs, raw_pairs, by = c("team", "metric"))) == 0L,
      nrow(standardized_pairs) == length(metrics) * 4L,
      !anyNA(raw_data$native_value),
      !anyNA(standardized_data$native_value),
      !anyNA(standardized_data$standardized_score)
    )

    raw_check <- game_metrics |>
      select(team, all_of(metrics)) |>
      tidyr::pivot_longer(
        cols = all_of(metrics),
        names_to = "metric",
        values_to = "game_value"
      ) |>
      inner_join(raw_data, by = c("team", "metric"))

    stopifnot(
      nrow(raw_check) == length(metrics) * 2L,
      all(near(raw_check$game_value, raw_check$native_value))
    )

    adjusted_check <- game_metrics |>
      select(team, all_of(paste0("adj_", metrics))) |>
      tidyr::pivot_longer(
        cols = starts_with("adj_"),
        names_to = "metric",
        names_prefix = "adj_",
        values_to = "game_value"
      ) |>
      inner_join(
        standardized_data |> filter(adjustment == "Opponent adjusted"),
        by = c("team", "metric")
      )

    stopifnot(
      nrow(adjusted_check) == length(metrics) * 2L,
      all(near(adjusted_check$game_value, adjusted_check$native_value))
    )

    common_mutations <- function(data) {
      data |>
        mutate(
          team_panel = factor(
            team,
            levels = c("LA", "SF"),
            labels = c("Rams", "49ers")
          ),
          metric_panel = factor(
            metric,
            levels = metrics,
            labels = unname(metric_label_lookup[metrics])
          )
        )
    }

    list(
      raw = common_mutations(raw_data),
      standardized = common_mutations(standardized_data) |>
        mutate(
          adjustment = factor(
            adjustment,
            levels = c("Unadjusted", "Opponent adjusted")
          ),
          bar_style = case_when(
            adjustment == "Unadjusted" ~ "Unadjusted",
            team == "SF" ~ "49ers opponent adjusted",
            TRUE ~ "Rams opponent adjusted"
          ),
          bar_style = factor(
            bar_style,
            levels = c(
              "Unadjusted",
              "49ers opponent adjusted",
              "Rams opponent adjusted"
            )
          ),
          native_label = format_native_value(metric, native_value),
          standardized_label = sprintf("%+.2f", standardized_score),
          label_hjust = if_else(standardized_score >= 0, -0.12, 1.12)
        )
    )
  }

  make_market_panel <- function() {
    outcome <- game_metrics |>
      filter(team == "SF") |>
      transmute(
        market_expectation = expected_margin,
        actual_margin = scoring_margin,
        market_residual = performance_vs_market
      )

    stopifnot(
      nrow(outcome) == 1L,
      near(outcome$market_expectation, -3.5),
      near(outcome$actual_margin, 20),
      near(outcome$market_residual, 23.5),
      near(outcome$actual_margin - outcome$market_expectation,
           outcome$market_residual)
    )

    points <- tibble(
      stage = c("Market expectation", "Final margin"),
      value = c(outcome$market_expectation, outcome$actual_margin),
      label = c(
        sprintf("Market: Rams by %g", -outcome$market_expectation),
        sprintf("Final: 49ers by %g", outcome$actual_margin)
      )
    )

    ggplot(points, aes(x = value, y = 1)) +
      geom_vline(xintercept = 0, color = zero_line_color, linewidth = zero_line_width) +
      # Draw the final marker beneath the arrowhead, retaining exact endpoints.
      geom_point(data = filter(points, stage == "Final margin"),
                 aes(fill = stage), shape = 21, size = 6,
                 color = "white", stroke = 0.9) +
      geom_segment(
        data = outcome,
        aes(x = market_expectation, xend = actual_margin,
            y = 1, yend = 1),
        inherit.aes = FALSE,
        color = "#475569",
        linewidth = 1.6,
        arrow = grid::arrow(length = grid::unit(0.18, "inches"), type = "closed")
      ) +
      geom_point(data = filter(points, stage == "Market expectation"),
                 aes(fill = stage), shape = 21, size = 6,
                 color = "white", stroke = 0.9) +
      geom_text(aes(label = label), nudge_y = -0.28,
                fontface = "bold", size = 3.7) +
      annotate(
        "text", x = mean(points$value), y = 1.27,
        label = sprintf("%+.1f points versus market", outcome$market_residual),
        color = "#374151", fontface = "bold", size = 4.0
      ) +
      annotate("text", x = -9.6, y = 0.35, label = "Rams advantage", hjust = 0,
               color = team_colors[["LA"]], fontface = "bold", size = 3.4) +
      annotate("text", x = 12.5, y = 0.35, label = "49ers advantage",
               color = team_colors[["SF"]], fontface = "bold", size = 3.4) +
      scale_fill_manual(
        values = c("Market expectation" = unadjusted_color,
                   "Final margin" = team_colors[["SF"]]),
        guide = "none"
      ) +
      scale_x_continuous(limits = c(-10, 25), breaks = seq(-10, 20, 10),
                         expand = expansion(mult = 0)) +
      scale_y_continuous(limits = c(0.26, 1.42), breaks = NULL) +
      labs(
        title = "(A) Game outcome versus market expectation",
        x = "Margin from the 49ers' perspective (points)", y = NULL
      ) +
      publication_theme() +
      theme(
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        axis.line.x = element_line(color = "#9CA3AF", linewidth = 0.45),
        axis.ticks.x = element_line(color = "#9CA3AF", linewidth = 0.45),
        panel.grid.major.y = element_blank(),
        plot.title = element_text(margin = margin(b = 16)),
        plot.margin = margin(5.5, 5.5, 10, 5.5)
      )
  }

  make_split_figure <- function(metrics) {
    plot_data <- prepare_plot_data(metrics)

    raw_plot <- ggplot(
      plot_data$standardized,
      aes(
        x = native_value,
        y = team_panel,
        fill = bar_style,
        group = adjustment
      )
    ) +
      geom_col(
        position = bar_dodge,
        width = 0.66
      ) +
      geom_vline(xintercept = 0, color = zero_line_color, linewidth = zero_line_width) +
      geom_text(
        aes(
          label = native_label,
          hjust = if_else(native_value >= 0, -0.12, 1.12)
        ),
        position = bar_dodge,
        color = "#111827",
        size = 2.95,
        show.legend = FALSE
      ) +
      facet_wrap(vars(metric_panel), ncol = 1, scales = "free_x") +
      scale_fill_manual(
        breaks = legend_order,
        values = c(
          "Unadjusted" = unadjusted_color,
          "49ers opponent adjusted" = unname(team_colors["SF"]),
          "Rams opponent adjusted" = unname(team_colors["LA"])
        )
      ) +
      scale_x_continuous(
        breaks = NULL,
        expand = expansion(mult = c(0.23, 0.27), add = 0.02)
      ) +
      labs(
        title = "(B) EPA per play and success rate",
        subtitle = "Observed and opponent adjusted; row-specific scales",
        x = NULL,
        y = NULL,
        fill = NULL
      ) +
      publication_theme() +
      theme(
        panel.grid = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.text.y = element_text(color = "#111827", size = 9.5),
        strip.text = element_text(face = "bold", hjust = 0, size = 10),
        strip.background = element_blank(),
        panel.spacing.y = grid::unit(1.2, "lines"),
        plot.margin = margin(15.5, 10, 5.5, 5.5)
      )

    standardized_plot <- ggplot(
      plot_data$standardized,
      aes(
        x = standardized_score,
        y = team_panel,
        fill = bar_style,
        group = adjustment
      )
    ) +
      geom_col(
        position = bar_dodge,
        width = 0.66
      ) +
      geom_vline(xintercept = 0, color = zero_line_color, linewidth = zero_line_width) +
      geom_text(
        aes(label = standardized_label, hjust = label_hjust),
        position = bar_dodge,
        color = "#111827",
        size = 2.95,
        show.legend = FALSE
      ) +
      facet_wrap(vars(metric_panel), ncol = 1) +
      scale_fill_manual(
        breaks = legend_order,
        values = c(
          "Unadjusted" = unadjusted_color,
          "49ers opponent adjusted" = unname(team_colors["SF"]),
          "Rams opponent adjusted" = unname(team_colors["LA"])
        )
      ) +
      scale_x_continuous(
        limits = c(-3.5, 3.5),
        breaks = seq(-3, 3, by = 1),
        expand = expansion(mult = c(0, 0))
      ) +
      labs(
        title = "(C) Standardized performance",
        subtitle = "2025 full-season reference; positive is better",
        x = "Standardized difference from 2025 reference",
        y = NULL,
        fill = NULL
      ) +
      publication_theme() +
      theme(
        legend.position = "bottom",
        panel.grid.major.y = element_blank(),
        axis.text.y = element_text(color = "#111827", size = 9.5),
        strip.text = element_text(
          face = "bold",
          hjust = 0,
          size = 10,
          color = "transparent"
        ),
        strip.background = element_blank(),
        panel.spacing.y = grid::unit(1.2, "lines"),
        plot.margin = margin(15.5, 5.5, 5.5, 10)
      )

    performance_panel <- (raw_plot + standardized_plot +
      plot_layout(widths = c(1, 1.15), guides = "collect")) &
      theme(legend.position = "bottom")

    # Match the market plotting area's left edge to the performance plotting area,
    # while keeping all panel headings aligned to their outer left margins.
    market_grob <- ggplotGrob(make_market_panel())
    raw_grob <- ggplotGrob(raw_plot)
    market_col <- market_grob$layout$l[market_grob$layout$name == "panel"]
    raw_col <- min(raw_grob$layout$l[grepl("^panel", raw_grob$layout$name)])
    market_grob$widths[market_col - 1L] <-
      sum(raw_grob$widths[seq_len(raw_col - 1L)]) -
      sum(market_grob$widths[seq_len(market_col - 2L)])

    figure <- wrap_plots(
      wrap_elements(full = market_grob),
      performance_panel,
      ncol = 1,
      heights = c(2.4, 7.25)
    ) &
      theme(legend.position = "bottom")

    figure
  }

  make_split_figure(plot_metrics)
}
