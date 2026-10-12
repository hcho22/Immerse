#!/usr/bin/env python3
"""Writes the fixtures the app's tests hold the 16mm Cinema color look to, from the captain's reference files beside
this script (vision3_250d_lut.py and effects_16mm_reference.py), which are not changed.

    python3 make_fixtures.py <output directory>

Needs numpy, scipy and pillow. Every number and picture written here comes from his functions; this script only chooses
the colors and the test frame they are asked about.

One constant of the look is not his file's. On 2026-10-12, with his files applied and shown on the 16mm review board,
he wrote "the blacks are too strong for color. please tone it down" and then "please bring the black up to 4 percent".
The look the app develops with is therefore his "print" look with its black level, BLACK, raised so that black
develops to 4 percent of the tone scale, its slight cool tint kept. His file still holds his own value.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

import effects_16mm_reference as E
import vision3_250d_lut as V

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
# His "print" look, with the black he asked for on the board (see above); his file's own is 0.0009, 0.0009, 0.0010.
CAPTAINS_BLACK = [0.0030, 0.0030, 0.0033]
V.LOOKS["applied"] = dict(V.LOOKS["print"], BLACK=CAPTAINS_BLACK)
LOOK = "applied"
M709_TO_2020 = np.linalg.inv(V.M2020_TO_709)
rng = np.random.default_rng(20261012)


def rows(a):
    return [[round(float(v), 6) for v in row] for row in np.asarray(a).reshape(-1, 3)]


# --- colors -----------------------------------------------------------------------------------------------------
stops = np.linspace(-8, 7, 61)
ramp = np.repeat((0.18 * 2.0 ** stops)[:, None], 3, 1)
grid = np.linspace(0, 1, 7)
display_grid = np.stack(np.meshgrid(grid, grid, grid, indexing="ij"), -1).reshape(-1, 3)
random_scene = rng.uniform(0, 1, (300, 3)) ** 1.5 * (0.18 * 2.0 ** rng.uniform(-6, 5, 300))[:, None] / 0.25
scene = np.concatenate([ramp, V.inverse_knee(V.srgb_decode(display_grid)), random_scene])
alog_grid = np.stack(np.meshgrid(*[np.linspace(0, 1, 5)] * 3, indexing="ij"), -1).reshape(-1, 3)
alog = np.concatenate([alog_grid, rng.uniform(0, 1, (300, 3))])
# The picture as the phone made it: a 6 x 6 x 6 grid of display colors, which the pipeline test lays out as an image.
display = np.stack(np.meshgrid(*[np.linspace(0, 1, 6)] * 3, indexing="ij"), -1).reshape(-1, 3)
# His table of neutral values for the "print" look, and the same tones with the black he asked for.
sanity = {str(k): v for k, v in V.SANITY["print"].items()}
sanity_applied = {str(k): rows(V.render_scene709(np.full((1, 3), 0.18 * 2.0 ** k), LOOK))[0] for k in V.SANITY["print"]}
# His constants as his file holds them, for a test to read the app's own values back against.
look = V.LOOKS["print"]
constants = {
    "curve": look["CURVE"], "negativeGamma": V.NEG_GAMMA.tolist(), "exposure": look.get("EXPOSURE", 0.0),
    "balance": look["WB_GAIN"], "toe": look["TOE_STOPS"], "crosstalk": look["XTALK"], "slope": look["K"],
    "grayDensity": look["D_GREY"], "maximumDensity": look["DMAX"], "bias": look["BIAS"], "black": look["BLACK"],
    "bands": look["BANDS"], "finish": look["FINISH_BANDS"], "highlightDesaturation": look["HI_DESAT"],
    "shadowDesaturation": look["SH_DESAT"], "bandCenters": V.BAND_CENTRES.tolist(), "bandWidths": V.BAND_WIDTHS.tolist(),
}
json.dump({
    "sanity": sanity, "sanityApplied": sanity_applied, "constants": constants, "appliedBlack": CAPTAINS_BLACK,
    "scene": rows(scene), "sceneDeveloped": rows(V.render_scene709(scene, LOOK)),
    "appleLog": rows(alog), "appleLogDeveloped": rows(V.render_scene709(V.applelog_decode(alog) @ V.M2020_TO_709.T, LOOK)),
    "display": rows(display), "displayDeveloped": rows(V.render_scene709(V.inverse_knee(V.srgb_decode(display)), LOOK)),
}, open(os.path.join(OUT, "colors.json"), "w"), separators=(",", ":"))


# --- a test frame -----------------------------------------------------------------------------------------------
def test_frame(w=320, h=240):
    """A small 4:3 scene as a phone would deliver it (display sRGB): a sky, dark ground, color patches, lamps bright
    enough to glow, fine detail and an even gray field."""
    y, x = np.mgrid[0:h, 0:w]
    u, v = x / (w - 1), y / (h - 1)
    img = np.zeros((h, w, 3))
    sky = np.stack([0.45 + 0.25 * v, 0.62 + 0.2 * v, 0.9 - 0.05 * v], -1)
    ground = np.stack([0.20 - 0.1 * u, 0.17 - 0.08 * u, 0.13 - 0.06 * u], -1)
    img[:] = np.where((v < 0.55)[..., None], sky, ground)
    patches = [(0.76, 0.57, 0.47), (0.70, 0.20, 0.18), (0.25, 0.55, 0.25), (0.20, 0.30, 0.70), (0.85, 0.75, 0.20),
               (0.20, 0.65, 0.70), (0.55, 0.30, 0.60), (0.95, 0.95, 0.95), (0.60, 0.60, 0.60), (0.30, 0.30, 0.30),
               (0.10, 0.10, 0.10), (0.90, 0.55, 0.15)]
    for i, c in enumerate(patches):
        r, k = divmod(i, 4)
        img[20 + r * 26:44 + r * 26, 16 + k * 30:42 + k * 30] = c
    img[130:210, 16:96] = 0.46                                    # an even middle gray
    check = ((x // 2 + y // 2) % 2).astype(float)
    img[130:210, 110:190] = (0.25 + 0.5 * check)[130:210, 110:190, None]   # fine detail
    img[120:230, 200:310] = 0.03                                  # night
    for cx, cy, rad, col in [(230, 150, 5, (1.0, 1.0, 1.0)), (275, 165, 3, (1.0, 0.95, 0.8)), (250, 205, 8, (1.0, 1.0, 1.0)),
                             (60, 8, 6, (1.0, 1.0, 1.0))]:
        img[np.hypot(x - cx, y - cy) <= rad] = col
    return (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)


def exact_lut(alog):
    shape = alog.shape
    return V.render_scene709(V.applelog_decode(alog.reshape(-1, 3)) @ V.M2020_TO_709.T, LOOK).reshape(shape)


def save(name, arr):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, name))


frame = test_frame()
Image.fromarray(frame).save(os.path.join(OUT, "frame.png"))
scene_frame = V.inverse_knee(V.srgb_decode(frame / 255.0))
W = scene_frame.shape[1]

# The passes with nothing random: halation, soft edges, softness, Apple Log, the look. No grain, no weave.
lin = E.halation(scene_frame, W)
lin = E.soft_edges(lin, W)
lin = E.blur(lin, E.MTF_SIGMA * W)
passes = exact_lut(np.clip(E.applelog_encode(lin @ M709_TO_2020.T), 0, 1))
save("frame-passes.png", passes)
# Each pass alone before the look, for a failing test to say which pass differs.
save("frame-look-only.png", exact_lut(np.clip(E.applelog_encode(scene_frame @ M709_TO_2020.T), 0, 1)))
save("frame-halation.png", exact_lut(np.clip(E.applelog_encode(E.halation(scene_frame, W) @ M709_TO_2020.T), 0, 1)))
save("frame-soft-edges.png", exact_lut(np.clip(E.applelog_encode(E.soft_edges(scene_frame, W) @ M709_TO_2020.T), 0, 1)))

# The whole frame as his reference develops it, with its grain and weave.
developed = E.develop_frame(scene_frame, None, t=0.4, seed=3, apply_lut=exact_lut, M709_TO_2020=M709_TO_2020)
save("frame-developed.png", developed)

# Weave alone, with the numbers it drew, on the frame after its passes.
t, seed = 0.4, 5
offset = E.weave_offset(t, W, np.random.default_rng(12345))
draw = np.random.default_rng(seed)
jitter = draw.normal(0, E.JITTER_PX * W / E.REF_W, 2)
degrees = float(draw.uniform(-E.ROT_DEG, E.ROT_DEG))
save("frame-weave.png", E.weave(passes, t, W, np.random.default_rng(seed), np.random.default_rng(12345)))
phases = np.random.default_rng(12345).uniform(0, 2 * np.pi, (2, 2))
times = [0.0, 0.25, 0.4, 1.0, 2.5, 7.75]
weave = {
    "frame": {"time": t, "dx": float(offset[0] + jitter[0]), "dy": float(offset[1] + jitter[1]), "degrees": degrees},
    "phases": phases.tolist(),
    "times": times,
    "offsetsAtReferenceWidth": [E.weave_offset(tt, E.REF_W, np.random.default_rng(12345)).tolist() for tt in times],
}

# Grain: what his field measures, at the width the app develops a landscape Movie.
GW, GH = 1920, 512
g = E.add_grain(np.full((GH, GW, 3), 0.5), GW, np.random.default_rng(11)) - 0.5
unit = g / g.std(axis=(0, 1), keepdims=True)


def correlation(a, b):
    return float(np.mean((a - a.mean()) * (b - b.mean())) / (a.std() * b.std()))


grain = {
    "width": GW,
    "deviation": g.std(axis=(0, 1)).tolist(),
    "expectedDeviation": (E.GRAIN_SIGMA * E.GRAIN_STRENGTH * GW / E.REF_W).tolist(),
    "redGreen": correlation(unit[..., 0], unit[..., 1]), "redBlue": correlation(unit[..., 0], unit[..., 2]),
    "greenBlue": correlation(unit[..., 1], unit[..., 2]),
    "lags": [1, 2, 3, 4, 6, 8],
    "greenAcrossLags": [correlation(unit[:, :-k, 1], unit[:, k:, 1]) for k in (1, 2, 3, 4, 6, 8)],
    "greenDownLags": [correlation(unit[:-k, :, 1], unit[k:, :, 1]) for k in (1, 2, 3, 4, 6, 8)],
    "redAcrossLags": [correlation(unit[:, :-k, 0], unit[:, k:, 0]) for k in (1, 2, 3, 4, 6, 8)],
}
constants = {
    "halation": {"threshold": E.HAL_THRESHOLD, "near": E.HAL_SIGMA_NEAR, "far": E.HAL_SIGMA_FAR,
                 "nearTint": E.HAL_TINT_NEAR.tolist(), "farTint": E.HAL_TINT_FAR.tolist(), "strength": E.HAL_STRENGTH},
    "edges": {"blur": E.EDGE_BLUR_SIGMA, "start": E.EDGE_START, "end": E.EDGE_END, "vignette": E.VIGNETTE_AMOUNT},
    "softness": E.MTF_SIGMA,
    "grain": {"deviation": E.GRAIN_SIGMA.tolist(), "strength": E.GRAIN_STRENGTH, "size": E.GRAIN_SIZE,
              "secondOctave": list(E.GRAIN_OCTAVE2), "shared": E.GRAIN_LUMA_SHARE},
    "weave": {"amplitude": E.WEAVE_AMP.tolist(), "frequencies": list(E.WEAVE_FREQS), "jitter": E.JITTER_PX,
              "rotation": E.ROT_DEG, "overscale": E.OVERSCALE},
    "referenceWidth": E.REF_W,
}
json.dump({"weave": weave, "grain": grain, "constants": constants}, open(os.path.join(OUT, "passes.json"), "w"), indent=1)
print("wrote", sorted(os.listdir(OUT)))
