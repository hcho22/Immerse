#!/usr/bin/env python3
"""
Immerse - 16mm Cinema: numpy reference implementation of the per-frame passes.

This is the ground truth the Metal shaders should match (diff a few frames
against it in a unit test). Order follows the PRD rules for the 16mm Cinema:
visible grain, red highlight halation on color (deliberate departure from the
Format Reference), minor jitter and weave, soft darkened edges, NO brightness
flicker, NO dust/hair, no aging, fixed daylight balance.

    frame (scene-linear Rec.709 or 2020, HxWx3, WB locked at daylight)
      -> halation      (linear, before anything blurs)
      -> soft edges    (linear: radial blur + vignette)
      -> MTF softness  (linear)
      -> Apple Log encode
      -> grain         (Apple Log units, new pattern every frame)
      -> 3D LUT        (vision3_250d_lut.py)
      -> weave/jitter  (sub-pixel resample, over-scaled to hide edges)
      -> crop to 4:3   (3:4 for portrait Movie Orientation)

All constants are [T] (tuned) unless labelled. Lengths scale with frame width W;
the reference width is 1440 px (4:3 at 1080 lines).
"""
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates

REF_W = 1440

# ---- halation: red glow around strong highlights (PRD deliberate departure) ----
HAL_THRESHOLD = 1.0          # scene-linear (~2.5 stops over grey; phone sRGB peaks at ~2.6)
HAL_SIGMA_NEAR = 0.004       # x W
HAL_SIGMA_FAR = 0.015        # x W
HAL_TINT_NEAR = np.array([1.00, 0.45, 0.10])
HAL_TINT_FAR = np.array([1.00, 0.12, 0.02])
HAL_STRENGTH = 0.45          # visible red glow (PRD departure); Vision3's real backing ~0.05

# ---- soft, darkened edges (PRD: soft focus with vignetting toward the edges) ----
EDGE_BLUR_SIGMA = 0.0030     # x W, reached at the corners
EDGE_START, EDGE_END = 0.45, 1.05   # radius (1 = corner) where softening ramps in
VIGNETTE_AMOUNT = 0.22       # 1 - 0.22 at the corner = about -0.35 stop

# ---- overall 16mm softness ----
MTF_SIGMA = 0.0005           # x W  (0.7 px at 1440)

# ---- grain (Apple Log units; per-layer ratio from Kodak 5207 granularity) ----
GRAIN_SIGMA = np.array([0.0028, 0.0034, 0.0062])   # per-pixel at REF_W, strength 1.0
GRAIN_STRENGTH = 1.5         # product default ("visible grain")
GRAIN_SIZE = 0.00042         # x W blur of white noise (0.6 px at 1440)
GRAIN_OCTAVE2 = (2.5, 0.35)  # second octave: size x2.5, weight 35% (clumping)
GRAIN_LUMA_SHARE = 0.7       # 70% of each channel's noise is shared (luma-correlated)

# ---- weave / jitter (minor; pro 16mm cameras are pin-registered) ----
WEAVE_AMP = np.array([0.0006, 0.0008])   # x W, horizontal / vertical (~0.9 / 1.2 px)
WEAVE_FREQS = (0.7, 1.9)     # Hz, two summed sines per axis with random phases
JITTER_PX = 0.2              # per-frame random offset at REF_W
ROT_DEG = 0.015              # max rotation
OVERSCALE = 1.006            # hide moving edges

# ---- frame ----
ASPECT = 4 / 3               # PRD FR-05 4:3 rule; true standard-16 gate is 1.37:1

APPLE = dict(R0=-0.05641088, RT=0.01, C=47.28711236, B=0.00964052, G=0.08550479, D=0.69336945)


def applelog_encode(r):
    a = APPLE
    return np.where(r >= a["RT"], a["G"] * np.log2(np.maximum(r + a["B"], 1e-12)) + a["D"],
           np.where(r >= a["R0"], a["C"] * (r - a["R0"]) ** 2, 0.0))


def radius(h, w):
    y, x = np.mgrid[0:h, 0:w]
    ny, nx = (y - (h - 1) / 2) / ((h - 1) / 2), (x - (w - 1) / 2) / ((w - 1) / 2)
    return np.sqrt(nx ** 2 + ny ** 2) / np.sqrt(2)          # 1.0 at the corners


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def blur(img, sigma_px):
    return np.stack([gaussian_filter(img[..., c], sigma_px) for c in range(3)], -1)


def halation(lin, W, strength=HAL_STRENGTH):
    lum = lin @ np.array([0.2126, 0.7152, 0.0722])
    hi = np.maximum(lum - HAL_THRESHOLD, 0.0)
    b1 = gaussian_filter(hi, HAL_SIGMA_NEAR * W)
    b2 = gaussian_filter(hi, HAL_SIGMA_FAR * W)
    return lin + strength * (0.4 * b1[..., None] * HAL_TINT_NEAR + 0.6 * b2[..., None] * HAL_TINT_FAR)


def soft_edges(lin, W):
    h, w = lin.shape[:2]
    r = radius(h, w)
    soft = blur(lin, EDGE_BLUR_SIGMA * W)
    m = smoothstep(EDGE_START, EDGE_END, r)[..., None]
    out = lin * (1 - m) + soft * m
    return out * (1.0 - VIGNETTE_AMOUNT * smoothstep(0.35, 1.0, r) ** 1.5)[..., None]


def grain_field(h, w, W, rng):
    def octave(scale):
        n = rng.standard_normal((h, w, 3))
        n = blur(n, max(GRAIN_SIZE * W * scale, 1e-6))
        return n / n.std(axis=(0, 1), keepdims=True)          # renormalise to unit variance
    n = octave(1.0) + GRAIN_OCTAVE2[1] * octave(GRAIN_OCTAVE2[0])
    n /= n.std(axis=(0, 1), keepdims=True)
    n = (1 - GRAIN_LUMA_SHARE) * n + GRAIN_LUMA_SHARE * n[..., 1:2]
    return n / n.std(axis=(0, 1), keepdims=True)


def add_grain(alog, W, rng, strength=GRAIN_STRENGTH):
    h, w = alog.shape[:2]
    # per-pixel RMS scales with film area per pixel: sigma x (W / REF_W) for the same gate
    return alog + grain_field(h, w, W, rng) * GRAIN_SIGMA * strength * (W / REF_W)


def weave_offset(t, W, rng_phase):
    ph = rng_phase.uniform(0, 2 * np.pi, (2, 2))
    s = np.array([sum(np.sin(2 * np.pi * f * t + ph[a, i]) for i, f in enumerate(WEAVE_FREQS)) / 2
                  for a in range(2)])
    return s * WEAVE_AMP * W


def weave(img, t, W, rng, rng_phase):
    h, w = img.shape[:2]
    dx, dy = weave_offset(t, W, rng_phase) + rng.normal(0, JITTER_PX * W / REF_W, 2)
    th = np.radians(rng.uniform(-ROT_DEG, ROT_DEG))
    y, x = np.mgrid[0:h, 0:w].astype(float)
    cy, cx = (h - 1) / 2, (w - 1) / 2
    xs, ys = (x - cx) / OVERSCALE, (y - cy) / OVERSCALE
    xr = np.cos(th) * xs - np.sin(th) * ys + cx - dx
    yr = np.sin(th) * xs + np.cos(th) * ys + cy - dy
    return np.stack([map_coordinates(img[..., c], [yr, xr], order=1, mode="nearest") for c in range(3)], -1)


def crop_aspect(img, aspect=ASPECT, portrait=False):
    h, w = img.shape[:2]
    a = 1 / aspect if portrait else aspect
    if w / h > a:
        nw = int(round(h * a)); x0 = (w - nw) // 2
        return img[:, x0:x0 + nw]
    nh = int(round(w / a)); y0 = (h - nh) // 2
    return img[y0:y0 + nh]


def develop_frame(scene709, lut, t=0.0, seed=0, apply_lut=None, M709_TO_2020=None):
    """scene709: HxWx3 scene-linear Rec.709 with WB locked at daylight.
    lut / apply_lut: a function mapping Apple Log Rec.2020 HxWx3 -> sRGB HxWx3."""
    rng = np.random.default_rng(seed)
    rng_phase = np.random.default_rng(12345)           # fixed per clip so weave is continuous
    W = scene709.shape[1]
    lin = halation(scene709, W)
    lin = soft_edges(lin, W)
    lin = blur(lin, MTF_SIGMA * W)
    alog = applelog_encode(lin @ M709_TO_2020.T)
    alog = add_grain(alog, W, rng)
    out = apply_lut(np.clip(alog, 0, 1))
    out = weave(out, t, W, rng, rng_phase)
    return crop_aspect(out)


def self_test():
    rng = np.random.default_rng(0)
    W = 320; h = 240
    flat = np.full((h, W, 3), 0.18)
    assert np.allclose(halation(flat, W), flat), "halation must not touch anything below threshold"
    spot = flat.copy(); spot[118:122, 158:162] = 8.0
    glow = halation(spot, W) - spot
    assert glow[120, 175, 0] > glow[120, 175, 1] > glow[120, 175, 2] >= 0, "glow must be red > green > blue"
    v = soft_edges(np.ones((h, W, 3)), W)
    assert abs(v[0, 0, 0] - (1 - VIGNETTE_AMOUNT)) < 0.02 and abs(v[h // 2, W // 2, 0] - 1) < 1e-6
    g = add_grain(np.full((h, W, 3), 0.5), W, rng, strength=1.0) - 0.5
    want = GRAIN_SIGMA * W / REF_W
    assert np.allclose(g.std(axis=(0, 1)), want, rtol=0.05), (g.std(axis=(0, 1)), want)
    off = np.array([weave_offset(t, REF_W, np.random.default_rng(1)) for t in np.linspace(0, 10, 241)])
    assert np.all(np.abs(off) <= WEAVE_AMP * REF_W + 1e-9), "weave exceeds its amplitude"
    c = crop_aspect(np.zeros((1080, 1920, 3)))
    assert c.shape[:2] == (1080, 1440)
    assert crop_aspect(np.zeros((1920, 1080, 3)), portrait=True).shape[:2] == (1440, 1080)
    print("effects self-test passed")


if __name__ == "__main__":
    self_test()
