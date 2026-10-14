"""Generate the README figure directly from the stint data in data/.

Uses only the Python standard library (reads .xlsx via zipfile) and writes
an SVG to figures/. The fitted lines are ordinary least squares, matching
lm(milliseconds ~ lap) in R/tire_degradation.R.

    python3 scripts/make_figures.py
"""

import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA, OUT = ROOT / "data", ROOT / "figures"

FONT = "-apple-system, 'Segoe UI', Helvetica, Arial, sans-serif"
INK, MUTED, GRID = "#1f2328", "#656d76", "#d0d7de"
STINT_COLORS = ["#0969da", "#8250df", "#cf222e"]


def read_xlsx(path):
    """Return (lap, milliseconds) pairs from the first sheet of a simple workbook."""
    with zipfile.ZipFile(path) as z:
        sheet = z.read("xl/worksheets/sheet1.xml").decode()
    rows = []
    for row in re.findall(r"<row[^>]*>(.*?)</row>", sheet)[1:]:  # skip header
        values = re.findall(r"<v>(.*?)</v>", row)
        if len(values) >= 2:
            rows.append((float(values[0]), float(values[1])))
    return rows


def ols(points):
    n = len(points)
    mx = sum(x for x, _ in points) / n
    my = sum(y for _, y in points) / n
    sxx = sum((x - mx) ** 2 for x, _ in points)
    b1 = sum((x - mx) * (y - my) for x, y in points) / sxx
    b0 = my - b1 * mx
    sse = sum((y - b0 - b1 * x) ** 2 for x, y in points)
    sst = sum((y - my) ** 2 for _, y in points)
    return b0, b1, 1 - sse / sst


def text(x, y, s, size=13, fill=INK, anchor="start", weight="normal"):
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{fill}" '
            f'text-anchor="{anchor}" font-weight="{weight}">{s}</text>\n')


def stint_figure(stints):
    width, height = 820, 440
    left, right, top, bottom = 80, 790, 100, 370
    x_lo, x_hi, y_lo, y_hi = 0, 60, 89.5, 95.0  # seconds

    def px(v):
        return left + (v - x_lo) / (x_hi - x_lo) * (right - left)

    def py(v):
        return bottom - (v - y_lo) / (y_hi - y_lo) * (bottom - top)

    body = text(24, 34, "Lap time rises through each stint as the tyres wear", 18, weight="600")
    body += text(24, 56, "Lewis Hamilton, 2011 Australian GP. Points are lap times; lines are per-stint least-squares fits.", 12, MUTED)

    for yv in range(90, 96):
        body += f'<line x1="{left}" y1="{py(yv):.1f}" x2="{right}" y2="{py(yv):.1f}" stroke="{GRID}"/>\n'
        body += text(left - 10, py(yv) + 4, f"{yv}.0 s", 12, MUTED, "end")
    for xv in range(0, 61, 10):
        body += text(px(xv), bottom + 20, str(xv), 12, MUTED, "middle")
    body += text((left + right) / 2, bottom + 44, "Lap number", 12, MUTED, "middle")

    for pit in (16, 36):
        body += (f'<line x1="{px(pit):.1f}" y1="{top}" x2="{px(pit):.1f}" y2="{bottom}" '
                 f'stroke="{MUTED}" stroke-dasharray="4,4"/>\n')
        body += text(px(pit), top - 8, f"pit, lap {pit}", 11, MUTED, "middle")

    for i, (points, color) in enumerate(zip(stints, STINT_COLORS)):
        b0, b1, r2 = ols(points)
        for x, y in points:
            body += f'<circle cx="{px(x):.1f}" cy="{py(y / 1000):.1f}" r="4" fill="{color}" fill-opacity="0.75"/>\n'
        x0, x1 = points[0][0], points[-1][0]
        body += (f'<line x1="{px(x0):.1f}" y1="{py((b0 + b1 * x0) / 1000):.1f}" '
                 f'x2="{px(x1):.1f}" y2="{py((b0 + b1 * x1) / 1000):.1f}" '
                 f'stroke="{color}" stroke-width="3"/>\n')
        lx = px((x0 + x1) / 2)
        body += text(lx, 80, f"Stint {i + 1}: +{b1:.0f} ms/lap", 13, color, "middle", "600")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}" font-family="{FONT}">\n'
            f'<rect width="{width}" height="{height}" fill="#ffffff"/>\n{body}</svg>\n')


def main():
    stints = [read_xlsx(DATA / f"hamilton_stint{i}.xlsx") for i in (1, 2, 3)]
    OUT.mkdir(exist_ok=True)
    (OUT / "stint_degradation.svg").write_text(stint_figure(stints))
    for i, s in enumerate(stints, 1):
        b0, b1, r2 = ols(s)
        print(f"Stint {i}: slope {b1:.2f} ms/lap, intercept {b0:.2f}, R^2 {r2:.4f}")
    print(f"Wrote figures to {OUT}")


if __name__ == "__main__":
    main()
