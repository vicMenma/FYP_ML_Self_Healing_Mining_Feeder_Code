"""Figure C.1 - Indicative field deployment architecture.

Drawn to match the existing thesis block diagrams (Figures 3.1, 3.6, 3.7):
pure black-on-white, serif type, thin rectangles, solid arrows for the
measurement path and dashed outlines for grouping / not-yet-enabled paths.
"""
from PIL import Image, ImageDraw, ImageFont

S = 2                      # supersample factor
W, H = 1240 * S, 1560 * S
BG, FG = 255, 0

img = Image.new("L", (W, H), BG)
d = ImageDraw.Draw(img)

TIMES = r"C:\Windows\Fonts\times.ttf"
TIMESB = r"C:\Windows\Fonts\timesbd.ttf"
TIMESI = r"C:\Windows\Fonts\timesi.ttf"


def f(size, path=TIMES):
    return ImageFont.truetype(path, int(size * S))


F_BOX = f(25)
F_BOXB = f(25, TIMESB)
F_SM = f(21)
F_SMI = f(21, TIMESI)
F_TIER = f(23, TIMESI)

LW = max(2, int(1.6 * S))


def text_size(txt, font):
    x0, y0, x1, y1 = d.textbbox((0, 0), txt, font=font)
    return x1 - x0, y1 - y0


def box(x, y, w, h, lines, dashed=False, lw=LW, fonts=None, pad=0):
    """Rectangle with centred, vertically-centred multi-line text."""
    if dashed:
        dash(x, y, x + w, y, lw)
        dash(x, y + h, x + w, y + h, lw)
        dash(x, y, x, y + h, lw)
        dash(x + w, y, x + w, y + h, lw)
    else:
        d.rectangle([x, y, x + w, y + h], outline=FG, width=lw)
    if fonts is None:
        fonts = [F_BOX] * len(lines)
    lh = [text_size(t, ft)[1] for t, ft in zip(lines, fonts)]
    gap = int(9 * S)
    total = sum(lh) + gap * (len(lines) - 1)
    cy = y + (h - total) / 2
    for t, ft, hh in zip(lines, fonts, lh):
        tw, _ = text_size(t, ft)
        # textbbox y0 offset differs per font; draw with anchor for consistency
        d.text((x + w / 2, cy + hh / 2), t, font=ft, fill=FG, anchor="mm")
        cy += hh + gap


def dash(x0, y0, x1, y1, lw=LW, on=int(9 * S), off=int(7 * S)):
    import math
    dist = math.hypot(x1 - x0, y1 - y0)
    if dist == 0:
        return
    ux, uy = (x1 - x0) / dist, (y1 - y0) / dist
    t = 0.0
    while t < dist:
        t2 = min(t + on, dist)
        d.line([x0 + ux * t, y0 + uy * t, x0 + ux * t2, y0 + uy * t2], fill=FG, width=lw)
        t = t2 + off


def arrow(x0, y0, x1, y1, dashed=False, head=int(9 * S), lw=LW):
    import math
    ang = math.atan2(y1 - y0, x1 - x0)
    bx, by = x1 - head * math.cos(ang), y1 - head * math.sin(ang)
    if dashed:
        dash(x0, y0, bx, by, lw)
    else:
        d.line([x0, y0, bx, by], fill=FG, width=lw)
    l = (x1 - head * 1.35 * math.cos(ang - 0.42), y1 - head * 1.35 * math.sin(ang - 0.42))
    r = (x1 - head * 1.35 * math.cos(ang + 0.42), y1 - head * 1.35 * math.sin(ang + 0.42))
    d.polygon([(x1, y1), l, r], fill=FG)


def label(x, y, txt, font=F_SM, anchor="mm"):
    d.text((x, y), txt, font=font, fill=FG, anchor=anchor)


# ----------------------------------------------------------------- geometry
M = 40 * S                      # outer margin
CW = W - 2 * M                  # content width
TIERX = M + 132 * S             # left edge of the tier boxes
TW = W - TIERX - M - 108 * S    # tier box width
CX = TIERX + TW / 2             # centre line of the stack

y = 30 * S

# ---- Title-less: caption is supplied by the document ----

# Tier 1: primary plant -----------------------------------------------------
h1 = 118 * S
box(TIERX, y, TW, h1,
    ["11 kV feeder primary plant",
     "Buses B2\u2013B5  \u00b7  circuit breakers CB2\u2013CB5  \u00b7  normally-open tie switch  \u00b7  NER-earthed neutral"],
    fonts=[F_BOXB, F_SM])
label(TIERX - 14 * S, y + h1 / 2, "Plant", F_TIER, anchor="rm")
y1b = y + h1
y += h1 + 46 * S

# Tier 2: measurement + protection ------------------------------------------
h2 = 132 * S
gapc = 26 * S
cw = (TW - gapc) / 2
box(TIERX, y, cw, h2,
    ["Instrument transformers",
     "CTs (5P20) and VTs (cl. 0.5)",
     "at B2\u2013B5"],
    fonts=[F_BOXB, F_SM, F_SM])
box(TIERX + cw + gapc, y, cw, h2,
    ["Protection IEDs at B2\u2013B5",
     "Independent IDMT overcurrent",
     "and earth-fault \u2014 retained,",
     "unchanged, as primary protection"],
    fonts=[F_BOXB, F_SM, F_SM, F_SM])
label(TIERX - 14 * S, y + h2 / 2, "Process", F_TIER, anchor="rm")
label(TIERX - 14 * S, y + h2 / 2 + 26 * S, "interface", F_TIER, anchor="rm")
y2t, y2b = y, y + h2
y += h2 + 46 * S

# arrows plant -> both boxes
arrow(TIERX + cw / 2, y1b, TIERX + cw / 2, y2t)
arrow(TIERX + cw + gapc + cw / 2, y1b, TIERX + cw + gapc + cw / 2, y2t)

# Tier 3: station bus -------------------------------------------------------
h3 = 112 * S
box(TIERX, y, TW, h3,
    ["Substation station bus",
     "Redundant switched Ethernet  \u00b7  IEC 61850 (MMS reporting, GOOSE status/command)",
     "Time synchronisation IEEE 1588 PTP or IRIG-B (\u2264 1 ms)"],
    fonts=[F_BOXB, F_SM, F_SM])
label(TIERX - 14 * S, y + h3 / 2, "Station", F_TIER, anchor="rm")
label(TIERX - 14 * S, y + h3 / 2 + 26 * S, "bus", F_TIER, anchor="rm")
y3t, y3b = y, y + h3
arrow(TIERX + cw / 2, y2b, TIERX + cw / 2, y3t)
arrow(TIERX + cw + gapc + cw / 2, y2b, TIERX + cw + gapc + cw / 2, y3t)
label(TIERX + cw / 2 - 10 * S, (y2b + y3t) / 2, "24 RMS features", F_SMI, anchor="rm")
y += h3 + 46 * S

# Tier 4: FDIR controller (dashed group) ------------------------------------
gx, gy = TIERX, y
inner_w = TW - 2 * (22 * S)
ix = gx + 22 * S
bh = 74 * S
vg = 20 * S
gh = 34 * S + 4 * bh + 3 * vg + 22 * S

dash(gx, gy, gx + TW, gy)
dash(gx, gy + gh, gx + TW, gy + gh)
dash(gx, gy, gx, gy + gh)
dash(gx + TW, gy, gx + TW, gy + gh)
label(gx + TW / 2, gy + 20 * S, "FDIR edge controller  (this study, Sections 3.4\u20133.6 and 4.8)", F_BOXB)

iy = gy + 34 * S
steps = [
    ["Feature assembly \u2014 24-element RMS vector, fixed ordering, quality and range checks"],
    ["Random Forest classifier \u2014 500 trees, 13 classes (Healthy, 12 fault type/zone), < 50 ms"],
    ["Deterministic zone-to-breaker isolation policy \u2014 auditable, not learned"],
    ["Restoration interlocks \u2014 T2 capacity (Eq. 3.5), 0.95\u20131.05 pu band (Eq. 3.6), B4/B5 lockout"],
]
prev_b = None
for st in steps:
    box(ix, iy, inner_w, bh, st, fonts=[F_SM])
    if prev_b is not None:
        arrow(ix + inner_w / 2, prev_b, ix + inner_w / 2, iy, head=int(8 * S))
    prev_b = iy + bh
    iy += bh + vg
label(TIERX - 14 * S, gy + gh / 2, "Application", F_TIER, anchor="rm")
arrow(TIERX + TW / 2, y3b, TIERX + TW / 2, gy)
y4b = gy + gh
y += gh + 46 * S

# Tier 5: supervisory -------------------------------------------------------
h5 = 132 * S
box(TIERX, y, TW, h5,
    ["Supervisory layer",
     "SCADA / HMI  \u00b7  event log and historian  \u00b7  operator",
     "Mode selector:   Monitoring   \u2192   Advisory   \u2192   Supervised control",
     "IEC 62443 zone-and-conduit segregation; authenticated, logged control actions"],
    fonts=[F_BOXB, F_SM, F_SM, F_SM])
label(TIERX - 14 * S, y + h5 / 2, "Supervisory", F_TIER, anchor="rm")
y5t, y5b = y, y + h5
arrow(TIERX + TW / 2, y4b, TIERX + TW / 2, y5t)
label(TIERX + TW / 2 - 10 * S, (y4b + y5t) / 2, "predicted class, proposed switching, event record", F_SMI, anchor="rm")

# ---- return control path (dashed, right-hand side) ------------------------
rx = TIERX + TW + 54 * S
dash(TIERX + TW, y5t + h5 / 2, rx, y5t + h5 / 2)
dash(rx, y5t + h5 / 2, rx, y1b - 34 * S)
arrow(rx, y1b - 34 * S, TIERX + TW, y1b - 34 * S, dashed=True)
# vertical label along the return path
lab = Image.new("L", (760 * S, 34 * S), BG)
ld = ImageDraw.Draw(lab)
ld.text((380 * S, 17 * S), "control commands \u2014 enabled in supervised mode only",
        font=F_SMI, fill=FG, anchor="mm")
lab = lab.rotate(-90, expand=True)
img.paste(lab, (int(rx + 6 * S), int((y1b + y5t) / 2 - 380 * S)))

# tick the control path where it re-enters the plant
label((rx + TIERX + TW) / 2, y1b - 34 * S - 18 * S, "", F_SM)

# ---- footnote row ---------------------------------------------------------
yf = y5b + 34 * S
d.text((M, yf), "Solid arrows: measurement path.   Dashed arrows: control path, inhibited in monitoring "
                "and advisory modes.", font=F_SMI, fill=FG, anchor="lt")
d.text((M, yf + 30 * S), "Primary IED protection operates independently of the FDIR controller at all times.",
       font=F_SMI, fill=FG, anchor="lt")

# ---- crop to content and downsample --------------------------------------
bbox = img.point(lambda p: 255 if p < 250 else 0).getbbox()
pad = 18 * S
img = img.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                min(W, bbox[2] + pad), min(H, bbox[3] + pad)))
img = img.resize((img.width // S, img.height // S), Image.LANCZOS)
img = img.convert("RGB")
img.save("Figure_C_01_deployment_architecture.png", dpi=(300, 300))
print("saved", img.size)
