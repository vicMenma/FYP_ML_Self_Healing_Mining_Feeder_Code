# -*- coding: utf-8 -*-
"""Project_Gantt_Chart.xlsx - a formula-driven project plan and native Excel
Gantt chart for the BEng thesis timeline.

Structure follows normal project-planning practice: a WBS with phase summary
rows, explicit start/finish dates, durations, predecessors, milestones and
percent-complete, with the chart plotted from helper columns on the same sheet.
"""
import datetime as dt
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.chart import BarChart, Reference, Series
from openpyxl.chart.marker import DataPoint
from openpyxl.chart.legend import LegendEntry
from openpyxl.chart.shapes import GraphicalProperties
from openpyxl.chart.data_source import NumDataSource, NumRef
from openpyxl.drawing.line import LineProperties
from openpyxl.worksheet.datavalidation import DataValidation

D = dt.date

# ---------------------------------------------------------------- plan data
# (wbs, name, type, predecessor, start, finish, pct, evidence)
PLAN = [
    ("1",   "Conception and proposal",                      "Phase",     "",     None, None, None,
     "Chapter 1"),
    ("1.1", "Topic conception (after KCM site visit)",       "Task",      "",     D(2025, 7, 1),  D(2025, 9, 15),  1.00,
     "Section 1.1"),
    ("1.2", "FYP proposal development",                      "Task",      "1.1",  D(2025, 9, 16), D(2025, 12, 15), 1.00,
     "Sections 1.2-1.4"),
    ("M1",  "Proposal submitted",                            "Milestone", "1.2",  D(2025, 12, 15), D(2025, 12, 15), 1.00,
     "-"),
    ("1.3", "Concept development and refinement",            "Task",      "1.2",  D(2025, 10, 25), D(2026, 1, 15),  1.00,
     "Chapter 2; Section 2.5"),
    ("1.4", "Scope simplification and title finalisation",   "Task",      "1.3",  D(2026, 1, 16), D(2026, 2, 15),  1.00,
     "Section 1.5"),
    ("M2",  "Title and scope finalised",                     "Milestone", "1.4",  D(2026, 2, 15), D(2026, 2, 15),  1.00,
     "-"),
    ("2",   "Modelling, dataset and machine learning",       "Phase",     "1",    None, None, None,
     "Chapters 3-5"),
    ("2.1", "Feeder Simulink modelling",                     "Task",      "1.4",  D(2026, 3, 1),  D(2026, 7, 5),   1.00,
     "Chapter 4; Sections 4.2-4.5"),
    ("2.2", "Topology rebuild and dataset generation",       "Task",      "2.1",  D(2026, 6, 5),  D(2026, 7, 10),  1.00,
     "Section 3.3; Table 3.3"),
    ("M3",  "Labelled dataset complete",      "Milestone", "2.2",  D(2026, 7, 10), D(2026, 7, 10),  1.00,
     "-"),
    ("2.3", "Machine learning and robustness analysis",      "Task",      "2.2",  D(2026, 6, 5),  D(2026, 7, 12),  1.00,
     "Sections 5.4, 5.7"),
    ("2.4", "Autonomous FDIR implementation",                "Task",      "2.3",  D(2026, 6, 5),  D(2026, 8, 7),   1.00,
     "Sections 4.8, 5.8"),
    ("3",   "Writing and submission",                        "Phase",     "",     None, None, None,
     "Chapters 1-6"),
    ("3.1", "Thesis drafting",                               "Task",      "",     D(2026, 5, 1),  D(2026, 8, 8),   1.00,
     "Chapters 1-6"),
    ("3.2", "Corrections, documentation and submission",     "Task",      "3.1",  D(2026, 6, 1),  D(2026, 8, 15),  0.90,
     "Appendices A-C"),
    ("M4",  "Thesis submission",                             "Milestone", "3.2",  D(2026, 8, 15), D(2026, 8, 15),  0.00,
     "-"),
]

PHASE_CHILDREN = {"1": (2, 7), "2": (9, 13), "3": (15, 17)}   # 1-based row index within PLAN

HDR_ROW = 9
FIRST = HDR_ROW + 1
LAST = HDR_ROW + len(PLAN)

# greyscale, to match the black-and-white figures used throughout the thesis
C_PHASE = "404040"
C_TASK = {"1": "808080", "2": "8C8C8C", "3": "A6A6A6"}
C_MILESTONE = "000000"
C_REMAIN = "D9D9D9"
C_HEADER = "404040"
C_BAND = "F2F2F2"

wb = Workbook()
ws = wb.active
ws.title = "Project Plan"

thin = Side(style="thin", color="BFBFBF")
box = Border(left=thin, right=thin, top=thin, bottom=thin)


def cell(ref, value, *, bold=False, size=10, color="000000", fill=None,
         align=None, fmt=None, border=False, wrap=False, italic=False):
    c = ws[ref]
    c.value = value
    c.font = Font(name="Arial", size=size, bold=bold, italic=italic, color=color)
    if fill:
        c.fill = PatternFill("solid", fgColor=fill)
    if align or wrap:
        c.alignment = Alignment(horizontal=align, vertical="center", wrap_text=wrap)
    if fmt:
        c.number_format = fmt
    if border:
        c.border = box
    return c


# ------------------------------------------------------------------- header
cell("A1", "Project Development Plan and Gantt Chart", bold=True, size=14, color="1F3864")
cell("A2", "ML-Assisted Self-Healing of a Mining Distribution Feeder with "
           "Selective Fault Isolation", size=10, color="404040")
cell("A3", "BEng Thesis - Victoire C. Chimundu", size=10, color="404040")

for r in (5, 6, 7):
    ws.merge_cells("A%d:B%d" % (r, r))
    ws.merge_cells("E%d:F%d" % (r, r))
    ws.merge_cells("G%d:H%d" % (r, r))

cell("A5", "Project start", bold=True, size=10)
cell("C5", "=MIN(E%d:E%d)" % (FIRST, LAST), fmt="dd-mmm-yyyy", align="left")
cell("A6", "Project finish", bold=True, size=10)
cell("C6", "=MAX(F%d:F%d)" % (FIRST, LAST), fmt="dd-mmm-yyyy", align="left")
cell("A7", "Total duration (calendar days)", bold=True, size=10)
cell("C7", "=C6-C5+1", fmt="0", align="left")

cell("E5", "Status date", bold=True, size=10)
cell("G5", D(2026, 8, 10), fmt="dd-mmm-yyyy", align="left", color="0000FF")
cell("E6", "Overall complete", bold=True, size=10)
cell("G6", "=SUMPRODUCT(G%d:G%d,H%d:H%d,--(C%d:C%d=\"Task\"))/"
           "SUMPRODUCT(G%d:G%d,--(C%d:C%d=\"Task\"))"
     % (FIRST, LAST, FIRST, LAST, FIRST, LAST, FIRST, LAST, FIRST, LAST),
     fmt="0%", align="left")
cell("E7", "Tasks / milestones", bold=True, size=10)
cell("G7", "=COUNTIF(C%d:C%d,\"Task\")&\" / \"&COUNTIF(C%d:C%d,\"Milestone\")"
     % (FIRST, LAST, FIRST, LAST), align="left")

# ------------------------------------------------------------------ headings
HEADERS = [("WBS", 7), ("Task / milestone", 40), ("Type", 11), ("Pred.", 8),
           ("Start", 12), ("Finish", 12), ("Days", 7), ("%", 7),
           ("Status", 13), ("Evidence in thesis", 24),
           ("Plot start", 11), ("Plot days", 10), ("Complete", 9), ("Remaining", 10),
           ("Chart label", 42)]
for i, (h, w) in enumerate(HEADERS, start=1):
    col = get_column_letter(i)
    ws.column_dimensions[col].width = w
    helper = i >= 11
    cell("%s%d" % (col, HDR_ROW), h, bold=True, size=10, color="FFFFFF",
         fill="7F7F7F" if helper else C_HEADER, align="center", border=True, wrap=True)
cell("K%d" % (HDR_ROW - 1), "Chart data - do not edit", bold=True, size=9,
     italic=True, color="7F7F7F", align="center")
ws.merge_cells("K%d:O%d" % (HDR_ROW - 1, HDR_ROW - 1))

# --------------------------------------------------------------------- rows
for i, (wbs, name, typ, pred, start, finish, pct, evid) in enumerate(PLAN):
    r = FIRST + i
    is_phase = typ == "Phase"
    is_ms = typ == "Milestone"
    shade = C_BAND if is_phase else None
    cell("A%d" % r, wbs, bold=is_phase, size=10, align="center", fill=shade, border=True)
    cell("B%d" % r, ("  " if not is_phase else "") + name, bold=is_phase, size=10,
         fill=shade, border=True)
    cell("C%d" % r, typ, size=10, align="center", fill=shade, border=True)
    cell("D%d" % r, pred or "-", size=10, align="center", fill=shade, border=True)

    if is_phase:
        a, b = PHASE_CHILDREN[wbs]
        ra, rb = HDR_ROW + a, HDR_ROW + b
        cell("E%d" % r, "=MIN(E%d:E%d)" % (ra, rb), bold=True, fmt="dd-mmm-yy",
             align="center", fill=shade, border=True)
        cell("F%d" % r, "=MAX(F%d:F%d)" % (ra, rb), bold=True, fmt="dd-mmm-yy",
             align="center", fill=shade, border=True)
        cell("H%d" % r, "=SUMPRODUCT(G%d:G%d,H%d:H%d)/SUM(G%d:G%d)" % (ra, rb, ra, rb, ra, rb),
             bold=True, fmt="0%", align="center", fill=shade, border=True)
    else:
        # dates are inputs: blue, per financial-model convention
        cell("E%d" % r, start, fmt="dd-mmm-yy", align="center", color="0000FF", border=True)
        cell("F%d" % r, finish, fmt="dd-mmm-yy", align="center", color="0000FF", border=True)
        cell("H%d" % r, pct, fmt="0%", align="center", color="0000FF", border=True)

    cell("G%d" % r, "=F%d-E%d+1" % (r, r), bold=is_phase, fmt="0", align="center",
         fill=shade, border=True)
    cell("I%d" % r, '=IF(H{r}>=1,"Complete",IF(H{r}<=0,"Not started","In progress"))'.format(r=r),
         size=10, align="center", fill=shade, border=True)
    cell("J%d" % r, evid, size=9, fill=shade, border=True, wrap=True)

    # helper (chart) columns
    grey = "F2F2F2"
    cell("K%d" % r, '=IF($C{r}="Milestone",E{r}-3,E{r})'.format(r=r), size=9,
         fmt="dd-mmm-yy", align="center", fill=grey, border=True, color="7F7F7F")
    cell("L%d" % r, '=IF($C{r}="Milestone",6,G{r})'.format(r=r), size=9, fmt="0",
         align="center", fill=grey, border=True, color="7F7F7F")
    cell("M%d" % r, "=ROUND(L{r}*H{r},0)".format(r=r), size=9, fmt="0",
         align="center", fill=grey, border=True, color="7F7F7F")
    cell("N%d" % r, "=L{r}-M{r}".format(r=r), size=9, fmt="0",
         align="center", fill=grey, border=True, color="7F7F7F")
    cell("O%d" % r, '=A{r}&"   "&TRIM(B{r})'.format(r=r), size=9, fill=grey,
         border=True, color="7F7F7F")

    ws.row_dimensions[r].height = 20

# ------------------------------------------------------------------- legend
n = LAST + 2
cell("A%d" % n, "How to use this sheet", bold=True, size=10, color="1F3864")
notes = [
    "Blue cells (Start, Finish, %) are the only inputs - edit those and everything else, "
    "including the Gantt chart, updates automatically.",
    "Black cells are formulas. Phase rows roll up from their child tasks; Days = Finish - Start + 1; "
    "the % on a phase row is duration-weighted.",
    "Columns K-O drive the chart only. Milestones are stored with Start = Finish (zero duration) and are "
    "widened to a 6-day marker so they remain visible at this time scale.",
    "The chart plots three stacked series: Plot start (no fill, positions the bar), Complete and "
    "Remaining. Shading: phase rows black, tasks grey, milestones solid black markers, outstanding "
    "work light grey.",
    "Dates were reconstructed from the project record; adjust any that differ from your own log and the "
    "chart will follow.",
]
for k, t in enumerate(notes):
    cell("A%d" % (n + 1 + k), "- " + t, size=9, color="404040")
    ws.merge_cells("A%d:O%d" % (n + 1 + k, n + 1 + k))

ws.freeze_panes = "A%d" % FIRST
ws.sheet_view.showGridLines = False

dv = DataValidation(type="list", formula1='"Phase,Task,Milestone"', allow_blank=False)
ws.add_data_validation(dv)
dv.add("C%d:C%d" % (FIRST, LAST))

# -------------------------------------------------------------------- chart
chart = BarChart()
chart.type = "bar"
chart.grouping = "stacked"
chart.overlap = 100
chart.gapWidth = 40
chart.title = None

cats = Reference(ws, min_col=15, min_row=FIRST, max_row=LAST)
s_start = Series(Reference(ws, min_col=11, min_row=HDR_ROW, max_row=LAST), title_from_data=True)
s_done = Series(Reference(ws, min_col=13, min_row=HDR_ROW, max_row=LAST), title_from_data=True)
s_left = Series(Reference(ws, min_col=14, min_row=HDR_ROW, max_row=LAST), title_from_data=True)
chart.series = [s_start, s_done, s_left]
chart.set_categories(cats)

# series 1 positions the bars and must be invisible
s_start.graphicalProperties = GraphicalProperties(noFill=True)
s_start.graphicalProperties.line = LineProperties(noFill=True)

# colour each completed bar by WBS level: phase, task-by-phase, milestone
pts = []
for i, (wbs, _n, typ, *_rest) in enumerate(PLAN):
    if typ == "Phase":
        col = C_PHASE
    elif typ == "Milestone":
        col = C_MILESTONE
    else:
        col = C_TASK[wbs.split(".")[0]]
    gp = GraphicalProperties(solidFill=col)
    gp.line = LineProperties(solidFill="FFFFFF", w=6350)
    pts.append(DataPoint(idx=i, spPr=gp))
s_done.data_points = pts

s_left.graphicalProperties = GraphicalProperties(solidFill=C_REMAIN)
s_left.graphicalProperties.line = LineProperties(solidFill="A6A6A6", w=6350)

# categories reversed => first task at the top AND Excel moves the date axis to the top
chart.x_axis.scaling.orientation = "maxMin"
chart.x_axis.delete = False
chart.x_axis.majorTickMark = "none"
chart.x_axis.majorGridlines = None

chart.y_axis.delete = False
chart.y_axis.scaling.min = D(2025, 7, 1).toordinal() - D(1899, 12, 30).toordinal()
chart.y_axis.scaling.max = D(2026, 9, 1).toordinal() - D(1899, 12, 30).toordinal()
chart.y_axis.majorUnit = 92          # quarterly labels; format hides the day, so no drift shows
chart.y_axis.minorUnit = 30.667      # monthly gridlines, unlabelled
chart.y_axis.number_format = "mmm yyyy"
chart.y_axis.majorTickMark = "out"
chart.y_axis.minorTickMark = "none"

chart.legend = None

chart.height = 11.5
chart.width = 19
ws.add_chart(chart, "A%d" % (LAST + 10))

wb.save("Project_Gantt_Chart.xlsx")
print("written Project_Gantt_Chart.xlsx  rows %d-%d" % (FIRST, LAST))
