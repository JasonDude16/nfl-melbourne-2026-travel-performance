# Melbourne travel-context figure

`scene.json` and `build_figure.py` are the single reproducible source for the approved travel figure. The builder exports the SVG, PDF, and PNG to `figures/final/`; no hidden build directory or duplicate script is needed.

Run from the project root:

```sh
python3 figures/editable/melbourne_travel_context/build_figure.py
```

Requirements: Python with `reportlab`, Poppler's `pdftoppm` on PATH, and Arial fonts at `/System/Library/Fonts/Supplemental/`. Adjust the font directory in the builder on other systems. The local bundled Python runtime also has the required package.

The figure retains the white center panel and neutral-gray outline. The September 25 spacing update adds 10 scene units between travel rows and 16 units above each lower team section. All three panel borders align at the top and bottom. The center comparisons use 60-unit section gaps, with equal whitespace above and below their stack beneath the fixed title. The bottom note and game-outcome panel are omitted. The canvas preserves the text size and 24-unit bottom margin, giving a 190 × approximately 107 mm publication size. The base scene includes the original outcome panel and note; the builder removes them and applies these layout refinements.

For reproducible edits, change the scene or builder. Text nodes contain both `text` and rendered `lines`; keep them consistent. The builder applies the spacing and panel refinements. For manual editing, use the final SVG, whose text and shapes remain editable. Manual SVG edits are not reflected in the source and will be replaced by rebuilding.
