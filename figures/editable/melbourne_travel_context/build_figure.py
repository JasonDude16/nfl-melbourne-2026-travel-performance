"""Export the Melbourne travel-context figure without its game-outcome panel.

Uses the editable scene that generated the existing figure. The original figure
and scene are not modified. A temporary PDF is rendered with pdftoppm for the
manuscript-ready PNG; only the SVG and PNG are kept.
"""

from __future__ import annotations

import copy
import html
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "scene.json"
OUTPUT = ROOT.parents[2] / "figures"
OUTPUT.mkdir(parents=True, exist_ok=True)
STEM = "melbourne_travel_context_no_game_panel"
WIDTH = 1600
ROW_GAP_EXTRA = 10
SECTION_GAP_EXTRA = 16
PANEL_HEIGHT_EXTRA = 3 * ROW_GAP_EXTRA + 2 * SECTION_GAP_EXTRA
HEIGHT = 814 + PANEL_HEIGHT_EXTRA + 24
PHYSICAL_WIDTH_MM = 190

FONT_DIRECTORY = Path("/System/Library/Fonts/Supplemental")
for name, filename in (
    ("Arial", "Arial.ttf"),
    ("Arial-Bold", "Arial Bold.ttf"),
    ("Arial-Italic", "Arial Italic.ttf"),
):
    pdfmetrics.registerFont(TTFont(name, str(FONT_DIRECTORY / filename)))


def descendants(node):
    yield node
    for child in node.get("children", []):
        yield from descendants(child)


def shift_down(group, distance):
    for node in descendants(group):
        for key in ("y", "y2"):
            if key in node:
                node[key] += distance
        if "pts" in node:
            node["pts"] = [[x, y + distance] for x, y in node["pts"]]


scene = copy.deepcopy(json.loads(SOURCE.read_text()))
omitted_sections = {"06 Shared game outcome", "07 Footer note"}
scene["children"] = [
    child for child in scene["children"] if child["name"] not in omitted_sections
]
assert not any(node["name"] in omitted_sections for node in descendants(scene))

background = next(node for node in scene["children"] if node["name"] == "White background")
background["h"] = HEIGHT

# Add breathing room to both team panels while retaining the text size.
for panel in scene["children"]:
    if panel["name"] not in ("03 49ERS panel", "05 RAMS panel"):
        continue
    sections = {node["name"]: node for node in panel["children"]}
    sections["Panel background and border"]["h"] += PANEL_HEIGHT_EXTRA
    travel = sections["Travel path and timing"]
    rows = {node["name"]: node for node in travel["children"]}
    for index, name in enumerate(("Origin", "Departure", "Melbourne arrival", "Travel duration")):
        row = rows[name]
        shift_down(row, index * ROW_GAP_EXTRA)
        for node in row["children"]:
            if node["name"] == "Row divider":
                shift_down(node, ROW_GAP_EXTRA / 2)
    shift_down(sections["Preparation and travel approach"], 3 * ROW_GAP_EXTRA + SECTION_GAP_EXTRA)
    shift_down(sections["First post-Melbourne game and rest"], PANEL_HEIGHT_EXTRA)

center_panel = next(
    node for node in scene["children"] if node["name"] == "04 Center comparison panel"
)
center_background = next(
    node for node in center_panel["children"] if node["name"] == "Neutral panel background"
)
center_background["fill"] = "#FFFFFF"
center_background["stroke"] = "#808080"
center_background["sw"] = 1.5
center_background["h"] += PANEL_HEIGHT_EXTRA

# Align all panel borders, with moderately tighter comparison gaps and equal
# whitespace above and below the comparison stack beneath its fixed title.
comparison_sections = [
    next(node for node in center_panel["children"] if node["name"] == name)
    for name in (
        "Melbourne arrival timing", "Arrival to kickoff window", "Destination nights"
    )
]
section_bounds = []
for section in comparison_sections:
    heading = next(node for node in descendants(section) if node["name"] == "Comparison heading")
    boxes = [node for node in descendants(section) if node["name"] == "Tinted comparison box"]
    section_bounds.append((heading["y"], max(node["y"] + node["h"] for node in boxes)))

section_gap = 60
stack_height = sum(bottom - top for top, bottom in section_bounds) + section_gap * 2
center_title = next(node for node in center_panel["children"] if node["name"] == "Comparison title")
content_top = center_title["y"] + center_title["h"]
content_bottom = center_background["y"] + center_background["h"]
next_top = content_top + (content_bottom - content_top - stack_height) / 2
for index, (section, (top, bottom)) in enumerate(zip(comparison_sections, section_bounds)):
    shift = next_top - top
    shift_down(section, shift)
    section_bottom = bottom + shift
    if index < len(comparison_sections) - 1:
        divider_name = ("Arrival divider", "Window divider")[index]
        divider = next(node for node in center_panel["children"] if node["name"] == divider_name)
        divider["y"] = divider["y2"] = section_bottom + section_gap / 2
    next_top = section_bottom + section_gap

def svg_node(node):
    kind = node["kind"]
    ident = node.get("id", "root")
    title = f"<title>{html.escape(node['name'])}</title>"
    if kind == "group":
        label = html.escape(node["name"], quote=True)
        return (
            f'<g id="{ident}" inkscape:label="{label}">{title}'
            + "".join(svg_node(child) for child in node["children"])
            + "</g>"
        )
    fill = node.get("fill") or "none"
    stroke = node.get("stroke") or "none"
    style = f'fill="{fill}" stroke="{stroke}" stroke-width="{node.get("sw", 0)}"'
    if kind == "rect":
        return (
            f'<rect id="{ident}" x="{node["x"]}" y="{node["y"]}" '
            f'width="{node["w"]}" height="{node["h"]}" '
            f'rx="{node.get("r", 0)}" {style}>{title}</rect>'
        )
    if kind == "ellipse":
        return (
            f'<ellipse id="{ident}" cx="{node["x"] + node["w"] / 2}" '
            f'cy="{node["y"] + node["h"] / 2}" rx="{node["w"] / 2}" '
            f'ry="{node["h"] / 2}" {style}>{title}</ellipse>'
        )
    if kind == "line":
        return (
            f'<line id="{ident}" x1="{node["x"]}" y1="{node["y"]}" '
            f'x2="{node["x2"]}" y2="{node["y2"]}" {style} '
            f'stroke-linecap="round">{title}</line>'
        )
    if kind == "polygon":
        points = " ".join(f"{x},{y}" for x, y in node["pts"])
        return f'<polygon id="{ident}" points="{points}" {style}>{title}</polygon>'
    if kind == "text":
        anchor = {"left": "start", "center": "middle", "right": "end"}[node["align"]]
        offset = {"left": 0, "center": 0.5, "right": 1}[node["align"]]
        x = node["x"] + offset * node["w"]
        spans = "".join(
            f'<tspan x="{x}" y="{node["y"] + node["size"] * .905 + i * node["lh"]}">'
            f"{html.escape(line)}</tspan>"
            for i, line in enumerate(node["lines"])
        )
        return (
            f'<text id="{ident}" font-family="Arial, Helvetica, sans-serif" '
            f'font-size="{node["size"]}" font-weight="{700 if node["bold"] else 400}" '
            f'font-style="{"italic" if node["italic"] else "normal"}" '
            f'fill="{node["color"]}" text-anchor="{anchor}">{title}{spans}</text>'
        )
    raise ValueError(kind)


OUTPUT.mkdir(parents=True, exist_ok=True)
height_mm = PHYSICAL_WIDTH_MM * HEIGHT / WIDTH
svg = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" '
    f'width="{PHYSICAL_WIDTH_MM}mm" height="{height_mm:.4f}mm" '
    f'viewBox="0 0 {WIDTH} {HEIGHT}">\n'
    + svg_node(scene)
    + "</svg>"
)
(OUTPUT / f"{STEM}.svg").write_text(svg)

def draw(node, pdf):
    kind = node["kind"]
    if kind == "group":
        for child in node["children"]:
            draw(child, pdf)
        return
    pdf.saveState()
    if node.get("fill"):
        pdf.setFillColor(HexColor(node["fill"]))
    if node.get("stroke"):
        pdf.setStrokeColor(HexColor(node["stroke"]))
        pdf.setLineWidth(node["sw"])
    fill = int(bool(node.get("fill")))
    stroke = int(bool(node.get("stroke")))
    if kind == "rect":
        pdf.roundRect(
            node["x"], HEIGHT - node["y"] - node["h"], node["w"], node["h"],
            node.get("r", 0), stroke=stroke, fill=fill,
        )
    elif kind == "ellipse":
        pdf.ellipse(
            node["x"], HEIGHT - node["y"] - node["h"],
            node["x"] + node["w"], HEIGHT - node["y"], stroke=stroke, fill=fill,
        )
    elif kind == "line":
        pdf.setLineCap(1)
        pdf.line(node["x"], HEIGHT - node["y"], node["x2"], HEIGHT - node["y2"])
    elif kind == "polygon":
        path = pdf.beginPath()
        path.moveTo(node["pts"][0][0], HEIGHT - node["pts"][0][1])
        for x, y in node["pts"][1:]:
            path.lineTo(x, HEIGHT - y)
        path.close()
        pdf.drawPath(path, stroke=stroke, fill=fill)
    elif kind == "text":
        pdf.setFillColor(HexColor(node["color"]))
        font = "Arial-Bold" if node["bold"] else "Arial-Italic" if node["italic"] else "Arial"
        pdf.setFont(font, node["size"])
        for i, line in enumerate(node["lines"]):
            x = node["x"]
            y = HEIGHT - node["y"] - node["size"] * .905 - i * node["lh"]
            if node["align"] == "center":
                pdf.drawCentredString(x + node["w"] / 2, y, line)
            elif node["align"] == "right":
                pdf.drawRightString(x + node["w"], y, line)
            else:
                pdf.drawString(x, y, line)
    pdf.restoreState()


renderer = shutil.which("pdftoppm")
if renderer is None:
    raise RuntimeError("pdftoppm is required to make the PNG")
with tempfile.TemporaryDirectory(prefix="melbourne-travel-") as temporary:
    pdf_path = Path(temporary) / f"{STEM}.pdf"
    scale = PHYSICAL_WIDTH_MM / 25.4 * 72 / WIDTH
    pdf = canvas.Canvas(
        str(pdf_path),
        pagesize=(WIDTH * scale, HEIGHT * scale),
        pageCompression=1,
        initialFontName="Arial",
    )
    pdf.setTitle("2026 Melbourne travel and game context, without game-outcome panel")
    pdf.scale(scale, scale)
    draw(scene, pdf)
    pdf.showPage()
    pdf.save()
    subprocess.run(
        [renderer, "-f", "1", "-singlefile", "-r", "300", "-png",
         str(pdf_path), str(OUTPUT / STEM)],
        check=True,
    )
print(f"Created {STEM}.svg and .png in {OUTPUT}")
