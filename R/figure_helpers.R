manuscript_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold", size = 15),
      plot.subtitle = ggplot2::element_text(color = "#4B5563"),
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "bottom"
    )
}

# Use the same devices, dimensions, and resolution as the approved figures.
save_paper_figure <- function(figure, stem, width, height) {
  directory <- project_path("figures", "final")
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  vector_device <- function(filename, width, height, bg, ...) {
    if (capabilities("aqua")) {
      grDevices::quartz(type = "pdf", file = filename, width = width, height = height, bg = bg, ...)
    } else {
      grDevices::cairo_pdf(filename = filename, width = width, height = height, bg = bg, ...)
    }
  }
  ggplot2::ggsave(file.path(directory, paste0(stem, ".png")), figure,
                  width = width, height = height, dpi = 600, bg = "white")
  ggplot2::ggsave(file.path(directory, paste0(stem, ".pdf")), figure, device = vector_device,
                  width = width, height = height, bg = "white")
}
