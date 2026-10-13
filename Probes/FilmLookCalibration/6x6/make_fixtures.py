#!/usr/bin/env python3
"""Writes the fixtures the app's tests hold the 6x6 Medium Format color look to, from the captain's files beside this
script (portra400_lut.py, the table it wrote, and sections 2 and 5 of his spec), none of which is changed.

    python3 make_fixtures.py <output directory>

Needs numpy, scipy, pillow and colour-science. Every color comes from his generator or from his table read
tetrahedrally, with the reader his own preview.py uses. The 6x6 has no reference file for its passes, so this script
writes them out from section 5 of his spec, using his 16mm reference's own functions where the spec says the shader is
the same; this script chooses only the colors and the test frame they are asked about.
"""
import json
import os
import shutil
import sys

import colour
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "16mm"))

import effects_16mm_reference as E  # noqa: E402
import portra400_lut as P  # noqa: E402

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
LOOK = "scan"
TABLE = "immerse_6x6_color_scan_applelog_33.cube"
TETRAHEDRAL = colour.algebra.table_interpolation_tetrahedral
rng = np.random.default_rng(20261012)

# --- section 2 of his spec: a photograph's way in -------------------------------------------------------------------
# Display P3 (sRGB transfer) -> linear -> inverse_knee() -> P3->Rec.2020 matrix, "computed with colour-science".
P3_TO_2020 = colour.matrix_RGB_to_RGB(colour.RGB_COLOURSPACES["Display P3"], colour.RGB_COLOURSPACES["ITU-R BT.2020"],
                                      chromatic_adaptation_transform=None)
REC709_TO_P3 = colour.matrix_RGB_to_RGB(colour.RGB_COLOURSPACES["ITU-R BT.709"], colour.RGB_COLOURSPACES["Display P3"],
                                        chromatic_adaptation_transform=None)
M709_TO_2020 = np.linalg.inv(P.M2020_TO_709)

# --- section 5 of his spec: the 6x6's passes, as written there --------------------------------------------------------
REF_W = 3024                                    # "The default assumes a 3024 x 3024 square crop"
GRAIN_SIGMA = np.array([0.0011, 0.0014, 0.0025])  # per-pixel, Apple Log units, strength 1.0
GRAIN_STRENGTH = 1.5                            # "Product default: grainStrength = 1.5"
GRAIN_SIZE = 0.00027                            # x W
GRAIN_OCTAVE2 = (2.5, 0.25)                     # "a second octave at 2.5x the size with 25% weight"
GRAIN_LUMA_SHARE = 0.7                          # "same shader as the 16mm spec", whose shader shares 70 percent
GRAIN_CEILING = 0.6                             # "Never exceed 0.6x the 16mm Cinema's grain"
VIGNETTE_AMOUNT, VIGNETTE_START, VIGNETTE_END, VIGNETTE_POWER = 0.18, 0.30, 1.0, 1.6
SIXTEEN = {"deviation": E.GRAIN_SIGMA.tolist(), "strength": E.GRAIN_STRENGTH}   # his 16mm grain, for the ceiling


def scene2020(p3_display):
    """A Display P3 picture's tones as the scene's light on Rec.2020 primaries."""
    return P.inverse_knee(P.srgb_decode(np.asarray(p3_display, dtype=np.float64))) @ P3_TO_2020.T


def vignette(lin):
    """rgb *= 1 - 0.18 * pow(smoothstep(0.30, 1.0, r), 1.6), where r = 1 at the corners."""
    h, w = lin.shape[:2]
    fall = E.smoothstep(VIGNETTE_START, VIGNETTE_END, E.radius(h, w)) ** VIGNETTE_POWER
    return lin * (1.0 - VIGNETTE_AMOUNT * fall)[..., None]


def add_grain(alog, W, draw):
    """His 16mm grain shader with the 6x6's numbers."""
    kept = (E.GRAIN_SIGMA, E.GRAIN_SIZE, E.GRAIN_OCTAVE2, E.GRAIN_LUMA_SHARE, E.REF_W)
    E.GRAIN_SIGMA, E.GRAIN_SIZE, E.GRAIN_OCTAVE2, E.GRAIN_LUMA_SHARE, E.REF_W = (
        GRAIN_SIGMA, GRAIN_SIZE, GRAIN_OCTAVE2, GRAIN_LUMA_SHARE, REF_W)
    try:
        return E.add_grain(alog, W, draw, strength=GRAIN_STRENGTH)
    finally:
        E.GRAIN_SIGMA, E.GRAIN_SIZE, E.GRAIN_OCTAVE2, E.GRAIN_LUMA_SHARE, E.REF_W = kept


def rows(a):
    return [[round(float(v), 6) for v in row] for row in np.asarray(a).reshape(-1, 3)]


# --- his table --------------------------------------------------------------------------------------------------------
# His generator must write the table he sent, byte for byte, in whatever environment this runs.
rewritten = os.path.join(OUT, "rewritten.cube")
P.build(rewritten, LOOK, 33)
assert open(rewritten, "rb").read() == open(os.path.join(HERE, TABLE), "rb").read(), "the generator no longer writes his table"
os.remove(rewritten)
shutil.copyfile(os.path.join(HERE, TABLE), os.path.join(OUT, TABLE))
table = colour.read_LUT(os.path.join(HERE, TABLE)).table


def read(alog):
    """His table at Apple Log tones, read tetrahedrally."""
    shape = np.asarray(alog).shape
    return np.clip(TETRAHEDRAL(np.clip(np.asarray(alog).reshape(-1, 3), 0, 1), table), 0, 1).reshape(shape)


def exact(alog):
    """His function at Apple Log tones."""
    shape = np.asarray(alog).shape
    return P.render_scene709(P.applelog_decode(np.asarray(alog).reshape(-1, 3)) @ P.M2020_TO_709.T, LOOK).reshape(shape)


# --- colors -----------------------------------------------------------------------------------------------------------
stops = np.linspace(-8, 7, 61)
ramp = np.repeat((0.18 * 2.0 ** stops)[:, None], 3, 1)
grid = np.linspace(0, 1, 7)
display_grid = np.stack(np.meshgrid(grid, grid, grid, indexing="ij"), -1).reshape(-1, 3)
random_scene = rng.uniform(0, 1, (300, 3)) ** 1.5 * (0.18 * 2.0 ** rng.uniform(-6, 5, 300))[:, None] / 0.25
scene = np.concatenate([ramp, P.inverse_knee(P.srgb_decode(display_grid)), random_scene])
alog_grid = np.stack(np.meshgrid(*[np.linspace(0, 1, 5)] * 3, indexing="ij"), -1).reshape(-1, 3)
alog = np.concatenate([alog_grid, rng.uniform(0, 1, (300, 3))])
# Tones between the table's own, for a test's tetrahedral reader to be checked against this one.
table_tones = np.round(rng.uniform(0, 1, (3000, 3)), 6)
# The picture as the phone made it: a 6 x 6 x 6 grid of Display P3 colors, which the pipeline test lays out as an image.
display = np.stack(np.meshgrid(*[np.linspace(0, 1, 6)] * 3, indexing="ij"), -1).reshape(-1, 3)
display_alog = np.clip(P.applelog_encode(scene2020(display)), 0, 1)
look = P.LOOKS[LOOK]
constants = {
    "curve": look["CURVE"], "negativeGamma": P.NEG_GAMMA.tolist(), "exposure": look.get("EXPOSURE", 0.0),
    "balance": look["WB_GAIN"], "toe": look["TOE_STOPS"], "crosstalk": look["XTALK"], "slope": look["K"],
    "grayDensity": look["D_GREY"], "maximumDensity": look["DMAX"], "bias": look["BIAS"], "black": look["BLACK"],
    "bands": look["BANDS"], "finish": look["FINISH_BANDS"], "highlightDesaturation": look["HI_DESAT"],
    "shadowDesaturation": look["SH_DESAT"], "bandCenters": P.BAND_CENTRES.tolist(), "bandWidths": P.BAND_WIDTHS.tolist(),
}
json.dump({
    "sanity": {str(k): v for k, v in P.SANITY[LOOK].items()}, "constants": constants,
    "scene": rows(scene), "sceneDeveloped": rows(P.render_scene709(scene, LOOK)),
    "appleLog": rows(alog), "appleLogDeveloped": rows(exact(alog)),
    "tableTones": rows(table_tones), "tableRead": rows(read(table_tones)),
    "display": rows(display), "displayDeveloped": rows(exact(display_alog)), "displayTable": rows(read(display_alog)),
    "displayP3ToRec2020": P3_TO_2020.tolist(), "rec709ToDisplayP3": REC709_TO_P3.tolist(),
}, open(os.path.join(OUT, "colors.json"), "w"), separators=(",", ":"))


# --- a test frame -----------------------------------------------------------------------------------------------------
def test_frame(side=240):
    """A small square scene as a phone would deliver it (Display P3 tones): a sky, dark ground, color patches, bright
    windows, fine detail and an even gray field."""
    y, x = np.mgrid[0:side, 0:side]
    u, v = x / (side - 1), y / (side - 1)
    img = np.zeros((side, side, 3))
    sky = np.stack([0.45 + 0.25 * v, 0.62 + 0.2 * v, 0.9 - 0.05 * v], -1)
    ground = np.stack([0.20 - 0.1 * u, 0.24 - 0.08 * u, 0.13 - 0.06 * u], -1)
    img[:] = np.where((v < 0.5)[..., None], sky, ground)
    patches = [(0.76, 0.57, 0.47), (0.70, 0.20, 0.18), (0.25, 0.55, 0.25), (0.20, 0.30, 0.70), (0.85, 0.75, 0.20),
               (0.20, 0.65, 0.70), (0.55, 0.30, 0.60), (0.95, 0.95, 0.95), (0.60, 0.60, 0.60), (0.30, 0.30, 0.30),
               (0.10, 0.10, 0.10), (0.90, 0.55, 0.15)]
    for i, c in enumerate(patches):
        r, k = divmod(i, 4)
        img[14 + r * 26:38 + r * 26, 12 + k * 30:38 + k * 30] = c
    img[128:208, 12:92] = 0.46                                    # an even middle gray
    check = ((x // 2 + y // 2) % 2).astype(float)
    img[128:208, 104:164] = (0.25 + 0.5 * check)[128:208, 104:164, None]   # fine detail
    img[120:228, 172:232] = 0.03                                  # deep shade
    for cx, cy, rad, col in [(190, 150, 5, (1.0, 1.0, 1.0)), (215, 165, 3, (1.0, 0.95, 0.8)), (200, 205, 8, (1.0, 1.0, 1.0)),
                             (150, 8, 6, (1.0, 1.0, 1.0))]:
        img[np.hypot(x - cx, y - cy) <= rad] = col
    return (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)


def save(name, arr):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, name))


frame = test_frame()
# The frame's bytes are Display P3 tones; the file carries no profile, and the tests read it as Display P3.
Image.fromarray(frame).save(os.path.join(OUT, "frame.png"))
light = scene2020(frame / 255.0)
W = light.shape[1]

save("frame-look-only.png", read(np.clip(P.applelog_encode(light), 0, 1)))
dark = vignette(light)
save("frame-vignette.png", read(np.clip(P.applelog_encode(dark), 0, 1)))
# The whole photograph as the spec develops it: vignette, no softening, Apple Log, grain, the table.
grained = add_grain(P.applelog_encode(dark), W, np.random.default_rng(3))
save("frame-developed.png", read(np.clip(grained, 0, 1)))

# Grain: what the field measures at the width the app develops a 6x6 photograph, on a strip of that width.
GW, GH = 3072, 384
g = add_grain(np.full((GH, GW, 3), 0.5), GW, np.random.default_rng(11)) - 0.5
unit = g / g.std(axis=(0, 1), keepdims=True)


def correlation(a, b):
    return float(np.mean((a - a.mean()) * (b - b.mean())) / (a.std() * b.std()))


grain = {
    "width": GW,
    "deviation": g.std(axis=(0, 1)).tolist(),
    "expectedDeviation": (GRAIN_SIGMA * GRAIN_STRENGTH * GW / REF_W).tolist(),
    "redGreen": correlation(unit[..., 0], unit[..., 1]), "redBlue": correlation(unit[..., 0], unit[..., 2]),
    "greenBlue": correlation(unit[..., 1], unit[..., 2]),
    "lags": [1, 2, 3, 4, 6, 8],
    "greenAcrossLags": [correlation(unit[:, :-k, 1], unit[:, k:, 1]) for k in (1, 2, 3, 4, 6, 8)],
    "greenDownLags": [correlation(unit[:-k, :, 1], unit[k:, :, 1]) for k in (1, 2, 3, 4, 6, 8)],
    "redAcrossLags": [correlation(unit[:, :-k, 0], unit[:, k:, 0]) for k in (1, 2, 3, 4, 6, 8)],
}
# How visible the grain is on an even middle gray, as display tones through the table: section 5 puts strength 1.0 at
# about 0.7 of an 8-bit step.
gray_alog = np.full((GH, GW, 3), float(P.applelog_encode(0.18)))
visible = read(np.clip(add_grain(gray_alog, GW, np.random.default_rng(12)), 0, 1))
grain["spreadOnMiddleGray"] = visible.std(axis=(0, 1)).tolist()
constants = {
    "vignette": {"amount": VIGNETTE_AMOUNT, "start": VIGNETTE_START, "end": VIGNETTE_END, "power": VIGNETTE_POWER},
    "grain": {"deviation": GRAIN_SIGMA.tolist(), "strength": GRAIN_STRENGTH, "size": GRAIN_SIZE,
              "secondOctave": list(GRAIN_OCTAVE2), "shared": GRAIN_LUMA_SHARE, "ceiling": GRAIN_CEILING},
    "sixteenMillimeterGrain": SIXTEEN,
    "referenceWidth": REF_W,
}
json.dump({"grain": grain, "constants": constants}, open(os.path.join(OUT, "passes.json"), "w"), indent=1)
print("wrote", sorted(os.listdir(OUT)))
