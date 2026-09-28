# NFL Melbourne 2026 travel and performance

Data, analysis code, and manuscript source for **Should I Stay or Should I Go Now? A Case Study of Contrasting International Travel Strategies and NFL Performance**.

This study examines the San Francisco 49ers’ and Los Angeles Rams’ performance around their contrasting arrival schedules for the 2026 Melbourne game. Selected historical London games and the first games after each trip provide context. The comparisons are descriptive and cannot establish whether arrival timing caused differences in performance.

## Repository contents

| File or folder | Contents |
| --- | --- |
| `index.qmd` | Quarto manuscript source |
| `notebooks/analysis.qmd` | Analysis notebook with calculations, explanations, and results |
| `data/raw/nflverse/` | Archived NFL play-by-play and schedule data |
| `R/` | Figure and table presentation helpers |
| `figures/` | Exported manuscript figures |
| `figures/editable/` | Source files and builder for the Melbourne travel figure |
| `tables/` | Table 1 in PNG and Word formats |
| `references.bib` | Manuscript bibliography |
| `tests/` | Optional paper-results check and reference results |
| `validation/` | Generated paper-results check report (excluded from Git) |
| `_quarto.yml` | Rendering configuration |
| `styles.css` | Display adjustments for HTML output |

## Reproduce the analysis

Use R and Quarto, preferably through RStudio. Open `nfl-melbourne-2026-travel-performance.Rproj` and install the required R packages:

```r
install.packages(c(
  "tidyverse", "rmarkdown", "knitr", "gt",
  "webshot2", "patchwork", "xml2"
))
```

Open `notebooks/analysis.qmd` and run all chunks in order, or render the notebook to HTML.

The notebook follows the manuscript: study design and game selection, outcome calculations, opponent adjustments, season comparisons, Melbourne results, and historical results. It then saves the derived datasets and exports the statistical figures and Table 1.

Figures are exported as PNGs. If a vector PDF is needed, add `export_pdf = TRUE` to the corresponding `save_paper_figure()` call. Standalone figure PDFs are excluded from version control.

Table PNG export requires Chrome or Chromium. Word export requires Pandoc, available through RStudio or Quarto.

## Data

The repository includes nflverse data archived on September 24, 2026, covering the 2010, 2013, 2017, 2019, 2025, and 2026 seasons used in the analysis. By default, `data_source <- "archive"` reads these files directly without downloading or replacing them.

Use the archived files to reproduce the reported results. Later nflverse downloads may contain revisions.

To rerun the calculations with currently available data, install `nflreadr` and set `data_source <- "nflverse"` in the notebook. Both modes load the selected seasons once. The source switch does not change the selected international games or Melbourne's 2025 reference season. The notebook lists the selected teams and international game IDs, then derives game details and each team's first following regular-season game from the loaded schedule.

The notebook records the source and archive or retrieval date in the result bundles and `data_source.csv`. Fresh-run results, figures, and tables are saved under `outputs/nflverse/<run timestamp>/`, which is excluded from Git. These runs leave the archived inputs and paper outputs in place. The manuscript continues to use the paper figures in `figures/`.

Archive-mode derived datasets are generated in `data/derived/` and are excluded from version control. They do not need to exist before running the notebook.

## Optional: reproduce the submitted paper’s results

After running the notebook in archive mode, compare its saved results with the submitted analysis by running this from the project root. The check also works in a fresh R session:

```r
source("tests/check_paper_results.R")
```

The check reads `data/derived/` and the fixed reference files in `tests/fixtures/`, then writes `validation/numerical_checks.csv`. It does not run automatically or evaluate the separate nflverse outputs. From the `notebooks/` directory, use `source("../tests/check_paper_results.R")`. Intentional changes to the analysis—such as using a different reference season—are expected to produce differences; retain the fixtures as the submitted-paper baseline.

## Render the manuscript

The manuscript can be rendered to HTML, Word, and PDF using the existing figures and tables:

```sh
quarto render index.qmd --to all --no-execute --use-freezer -M notebook-view:false -M notebook-links:false
```

Outputs are saved in `_manuscript/`. This command refreshes the manuscript documents without rerunning the analysis.

Edit manuscript text in `index.qmd` and references in `references.bib`. Changes to calculations should be made in `notebooks/analysis.qmd`; rerun the notebook before rendering the manuscript if those changes affect its results, figures, or table.

Journal submission files are maintained separately and are not included in the repository.

## Melbourne travel figure

The travel figure is maintained separately from the statistical analysis. Its source files and rebuild instructions are in `figures/editable/melbourne_travel_context/`.

The exported figure is included in `figures/`, so rebuilding it is only necessary when changing its content or design.
