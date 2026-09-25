# NFL Melbourne 2026: travel and performance

`nfl-melbourne-2026-travel-performance` contains the manuscript and analysis code for **Should I Stay or Should I Go Now? A Case Study of Contrasting International Travel Strategies and NFL Performance**.

The study describes performance surrounding the San Francisco 49ers’ and Los Angeles Rams’ contrasting arrival schedules for the 2026 Melbourne game. Selected historical London games and the first games after each trip provide context. These observational comparisons cannot establish whether arrival timing caused differences in performance.

Reproduce the descriptive analyses using one [RStudio/Quarto notebook](notebooks/analysis.qmd). The analysis uses the archived September 24, 2026 nflverse data and does not download or replace source data during execution.

## Run the analysis

Open [`nfl-melbourne-2026-travel-performance.Rproj`](nfl-melbourne-2026-travel-performance.Rproj). Install the required R packages once:

```r
install.packages(c("tidyverse", "rmarkdown", "knitr", "gt", "webshot2", "patchwork", "xml2"))
```

Open **[NFL Melbourne 2026: reproducible analysis](notebooks/analysis.qmd)** and use Run All or render it to HTML. The notebook follows the manuscript's Methods and Results:

1. Study design and game selection, including historical travel context (Table 1).
2. Football data, validation, outcome definitions, and game-level calculations.
3. Opponent adjustment, season references, and standardized comparisons.
4. Melbourne results, including both following games and Figure 2.
5. Historical 49ers and Rams results, with Figures 3 and 4.
6. Dataset exports, numerical verification, and publication exports.

The notebook runs from archived inputs in a fresh R session without pre-existing derived files. Calculations pass objects between sections in memory. The core functions and their explanations are visible in the notebook; `R/` contains only figure and table presentation helpers. Rendered HTML displays the code, tables, and figures. Quarto execution caching is disabled. Table PNG export requires Chrome/Chromium; Word export requires Pandoc, bundled with RStudio/Quarto.

## Data availability

The data snapshots in `data/raw/nflverse/` are local archives. The current project settings exclude both raw and derived data from Git, so publishing the code alone will not make these datasets available. A public location for the archived inputs must be documented before readers can reproduce the analysis from the repository alone.

All six September 24 play-by-play files and the combined schedule file must be present. Missing or invalid files cause an error. Restore the actual snapshots to reproduce the paper; downloading today's nflverse data under the old filename would not reproduce the archived source. `nflreadr` was used to obtain the snapshots but is not required to reanalyze them.

## What is calculated

The paper includes scoring margin, market residual, offensive and defensive EPA/success rates, CPOE, and offensive/defensive sack rates. Seven play outcomes also receive opponent adjustment. Only the four EPA/success measures are standardized. Reference-game counts are retained for statements such as “lower than all 17 games.”

The reference calculations follow the final Methods:

| Comparison | Season weighting | Historical exclusions |
| --- | --- | --- |
| Native-unit results | Equal games for scoring/market; plays, pass attempts, or dropbacks for play metrics | None |
| Standardized differences and reference-game counts | Equal games; sample standard deviation | Only the focal game |
| Historical scoring/market figure | Equal games | Both London and following games |

Historical opponent ratings exclude the game being adjusted; league ratings include all regular-season games that year. Melbourne and post-Melbourne use complete 2025 opponent/league ratings and all 17 team reference games. Positive standardized differences indicate better performance. The [data dictionary](supplement/data_dictionary.md) explains the saved results and units.

## Outputs and verification

- `data/derived/`: validated inputs, historical and Melbourne result bundles, and readable CSVs. Melbourne outputs include both teams' following games; use `phase` to distinguish them.
- `figures/final/`: the four paper figures, with PNG and PDF exports; the travel figure also has an editable SVG.
- `tables/final/`: Table 1 in PNG and Word formats.
- `tests/fixtures/`: numerical baselines captured before the code cleanup, using the final September 24 analysis.

The notebook runs the numerical checks automatically. To repeat them independently from the project root:

```r
source("tests/check_paper_results.R")
```

This compares all focal results, standardized values, reference games, and denominators with the frozen baseline, and writes `validation/numerical_checks.csv`. Standalone checks extract the notebook's definition chunks without executing the analysis or its exports.

## Travel figure and manuscript

The travel figure has one [editable source and builder](figures/editable/melbourne_travel_context/README.md). It is independent of the football calculations and need only be rebuilt when its source changes.

### Export the manuscript

The manuscript supports HTML, Word, and PDF. The HTML page lists **MS Word** and **PDF** under **Other Formats**. PDF uses Quarto's bundled Typst engine, so a separate LaTeX installation is not needed.

To refresh all three manuscript formats without rerunning the analysis:

```sh
quarto render index.qmd --to all --no-execute --use-freezer -M notebook-view:false -M notebook-links:false
```

The files are saved as `_manuscript/index.html`, `_manuscript/index.docx`, and `_manuscript/index.pdf`. In RStudio's Render menu, choose **Typst** to export only the PDF. Rendering only HTML refreshes the page, not its downloadable files.

Edit the manuscript in [`index.qmd`](index.qmd) and the analysis in [`notebooks/analysis.qmd`](notebooks/analysis.qmd). Rendering the manuscript uses the existing figures and tables; rerun the analysis first if the calculations or their presentation have changed. The bibliography is stored in `references/references.bib`.
