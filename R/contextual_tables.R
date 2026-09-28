# Manuscript-facing context tables. The source-of-truth narrative and links are
# maintained in supplement/game_context_report.md; numerical game fields were
# checked against data/derived/game_validation.csv.

historical_context_table <- function(data, include_title = FALSE) {
  stopifnot(
    nrow(data) == 5L,
    identical(
      data$team_year,
      c("49ers, 2010", "49ers, 2013", "Rams, 2017", "Rams, 2019", "Rams, 2025")
    )
  )

  table <- data |>
    gt::gt() |>
    gt::cols_label(
      team_year = "Team / year",
      opponent_location = "Opponent / venue",
      staging_context = "Before overseas travel",
      arrival_nights = "London arrival / nights",
      travel_approach = "Travel strategy",
      pregame_context = "Pregame record",
      international_result = "International result / vs. market",
      post_rest = "Rest / bye before next game",
      first_post_result = "Next-game result / vs. market"
    ) |>
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(columns = team_year)
    ) |>
    gt::tab_style(
      style = gt::cell_borders(
        sides = "top", color = "#6B7280", weight = gt::px(2)
      ),
      locations = gt::cells_body(rows = 3)
    ) |>
    gt::cols_width(
      team_year ~ gt::px(95),
      opponent_location ~ gt::px(145),
      staging_context ~ gt::px(170),
      arrival_nights ~ gt::px(155),
      travel_approach ~ gt::px(160),
      pregame_context ~ gt::px(125),
      international_result ~ gt::px(125),
      post_rest ~ gt::px(115),
      first_post_result ~ gt::px(160)
    ) |>
    gt::tab_options(
      table.width = gt::px(1250),
      table.font.size = gt::px(10),
      heading.align = "left",
      column_labels.font.weight = "bold",
      column_labels.background.color = "#E5E7EB",
      data_row.padding = gt::px(4)
    )

  if (include_title) {
    table <- table |>
      gt::tab_header(title = gt::md(paste0("**", historical_context_title(), "**")))
  }
  table
}

historical_context_title <- function() {
  "Table 1. Historical international games, travel arrangements, and results in the next game"
}


# Match the established landscape Word export and gt's half-point font units.
save_historical_context_docx <- function(table, path) {
  word_table <- table |>
    gt::tab_style(style = gt::cell_text(size = 18),
      locations = list(gt::cells_body(), gt::cells_column_labels()))
  section <- '<w:p><w:pPr><w:sectPr><w:pgSz w:w="15840" w:h="12240" w:orient="landscape"/><w:pgMar w:top="1080" w:right="720" w:bottom="1080" w:left="720" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr></w:pPr></w:p>'
  markdown <- tempfile(fileext = ".md")
  on.exit(unlink(markdown))
  writeLines(c(paste0("**", historical_context_title(), "**"), "",
    "```{=openxml}", gt::as_word(word_table), section, "```"), markdown)
  output <- file.path(normalizePath(dirname(path)), basename(path))
  # Quarto's CLI provides Pandoc without setting RStudio's RSTUDIO_PANDOC.
  quarto <- file.path(Sys.getenv("QUARTO_BIN_PATH"), "quarto")
  if (!rmarkdown::pandoc_available() && file.exists(quarto)) {
    status <- system2(quarto, c("pandoc", shQuote(markdown), "--to=docx", "--output", shQuote(output)))
    stopifnot(status == 0L)
  } else {
    rmarkdown::pandoc_convert(markdown, to = "docx", output = output)
  }
  stopifnot(file.exists(output))
  # Make the landscape section the document's final section. Leaving a section
  # break after the table makes Pandoc append an unwanted blank portrait page.
  directory <- tempfile()
  dir.create(directory)
  utils::unzip(output, files = "word/document.xml", exdir = directory)
  document_path <- file.path(directory, "word", "document.xml")
  document <- xml2::read_xml(document_path)
  properties <- xml2::xml_find_first(document, ".//w:pPr/w:sectPr")
  xml2::xml_replace(xml2::xml_find_first(document, ".//w:body/w:sectPr"), properties)
  xml2::xml_remove(xml2::xml_find_first(document, ".//w:p[w:pPr/w:sectPr]"))
  xml2::write_xml(document, document_path)
  previous_directory <- setwd(directory)
  on.exit({ setwd(previous_directory); unlink(directory, recursive = TRUE) }, add = TRUE)
  utils::zip(output, "word/document.xml", flags = "-q")
}
