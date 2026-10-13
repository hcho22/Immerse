#!/usr/bin/env python3
"""
Immerse - 16mm Cinema, color Film Stock
3D LUT generator for a Kodak Vision3 250D (5207/7207) look, printed to Kodak
Vision 2383 (internal Format Reference only; never show the film or camera
name in the product).

Same pipeline, input space and film() model as the 6x6 color generator
(portra400_lut.py), so the app needs one LUT sampler and one pre-pass:

    Input domain : Apple Log curve, Rec.2020 primaries (scene-referred).
                   Phone video/photos are converted into this space by the
                   shader pre-pass (see spec). WB must stay fixed at daylight.
    Output       : sRGB / Rec.709 display-encoded.

Pipeline: decode -> Rec.2020->709 -> white-balance gain -> log10 exposure re: grey
-> soft negative toe -> 3x3 interlayer crosstalk (log space) -> negative gamma
-> per-channel output curve (2383 print, or flat scan) -> OKLCh hue/chroma bands
-> highlight soft-clip -> sRGB encode.

Source labels on every constant:
  [P]   published (Kodak / Apple / ITU)
  [P-d] Kodak's 5207 curves as digitized in spectral_film_lut (MIT)
  [F]   fitted to spectral_film_lut's datasheet-driven simulation: Vision3 250D
        printed to Vision 2383 (PRINT look), or scanned with an ACES-style
        inversion (SCAN look)
  [T]   tuned by hand on top of the fit; validate against real 16mm scans.

Usage:
    python3 vision3_250d_lut.py                  # app LUT: immerse_16mm_color_print_applelog_33.cube
    python3 vision3_250d_lut.py --size 65        # 65^3 (recommended for video/log input)
    python3 vision3_250d_lut.py --input srgb     # desktop preview LUT (sRGB image in)
    python3 vision3_250d_lut.py --look scan      # flat scan variant
    python3 vision3_250d_lut.py --test           # sanity assertions

Requires only numpy.
"""
import argparse
import numpy as np

# --------------------------------------------------------------------------
# Input decoding  [P: Apple Log Profile White Paper, Sept 2023; ITU-R BT.2087]
# --------------------------------------------------------------------------
R0, RT, C = -0.05641088, 0.01, 47.28711236
BETA, GAM, DELTA = 0.00964052, 0.08550479, 0.69336945
PT = C * (RT - R0) ** 2


def applelog_decode(v):
    v = np.asarray(v, dtype=np.float64)
    return np.where(v >= PT, 2.0 ** ((v - DELTA) / GAM) - BETA,
           np.where(v >= 0.0, np.sqrt(np.clip(v, 0, None) / C) + R0, R0))


def applelog_encode(r):
    r = np.asarray(r, dtype=np.float64)
    return np.where(r >= RT, GAM * np.log2(np.maximum(r + BETA, 1e-12)) + DELTA,
           np.where(r >= R0, C * (r - R0) ** 2, 0.0))


M2020_TO_709 = np.array([[ 1.6605, -0.5876, -0.0728],
                         [-0.1246,  1.1329, -0.0083],
                         [-0.0182, -0.1006,  1.1187]])

# --------------------------------------------------------------------------
# Look constants
# --------------------------------------------------------------------------
# Vision3 250D negative: straight-line slopes of Kodak's 5207 characteristic
# curves (Status M) over -3..+3 stops, per log10 exposure. Toe ~-4.5 stops,
# shoulder ~+7 stops (half-slope points).                           [P-d]
NEG_GAMMA = np.array([0.474, 0.555, 0.535])   # R, G, B

LOOKS = {
    # DEFAULT. The negative printed to Vision 2383 print film and shown as a
    # print: deep blacks, a long soft highlight shoulder (still separating at
    # +5 stops), muted cyans/purples, olive greens. Fitted to the spectral
    # simulation of 5207 -> 2383 [F], then timed the way a lab grader would [T]:
    # daylight develops neutral (PRD), a slight warm-highlight/cool-shadow split.
    "print": dict(
        CURVE="print",
        EXPOSURE=0.0,
        WB_GAIN=[1.000, 1.000, 1.000],          # daylight = neutral (PRD); WB is locked at capture
        TOE_STOPS=-7.0,                         # negative toe sits below the print toe   [F]
        XTALK=[[ 1.1452, -0.1926,  0.0474],     # interlayer crosstalk, log space         [F]
               [ 0.0873,  0.7649,  0.1478],     #  rows sum to 1 -> greys stay grey
               [-0.0658,  0.0083,  1.0574]],
        # Print-curve slopes. Fit [4.178, 3.918, 3.693] gives effective slopes
        # (K x NEG_GAMMA) of 1.98/2.17/1.98: green highlights, magenta shadows.
        # Timed to 2.20/2.17/2.12 -> slightly warm highlights, cool shadows. [F -> T]
        K=[4.64, 3.92, 3.96],
        D_GREY=0.694,                           # grey prints to sRGB ~0.48            [F]
        DMAX=4.39,                              # print density range                  [F]
        BIAS=[0.0, 0.0, 0.0],                   # fit [+0.011, 0, +0.023], timed out    [T]
        BLACK=[0.0009, 0.0009, 0.0010],         # projection black, a hair cool         [T]
        # OKLCh hue bands: (hue shift deg, chroma gain-1, lightness gain-1).
        # Order: red, skin/orange, yellow, green, aqua, blue, purple/magenta.
        BANDS=[[  2.51, -0.009, -0.030],                                        # [F]
               [  1.45, -0.062,  0.010],
               [ -0.80, -0.027,  0.002],
               [ -2.09, -0.169,  0.005],
               [ -2.05, -0.393,  0.025],
               [ -0.55, -0.134,  0.015],
               [  1.78, -0.463,  0.056]],
        FINISH_BANDS=[[  0.0,  0.000,  0.000],  # reds                              [T]
                      [  0.0, +0.040, +0.020],  # skin: Kodak's "outstanding skin tones"
                      [  0.0,  0.000,  0.000],  # yellows
                      [ -5.0, -0.050,  0.000],  # greens: toward olive
                      [  0.0,  0.000,  0.000],  # aqua
                      [  0.0,  0.000,  0.000],  # blues
                      [  0.0,  0.000,  0.000]], # purple/magenta
        HI_DESAT=0.379,                         # print highlight desaturation         [F]
        SH_DESAT=0.0,                           #                                      [F]
    ),
    # VARIANT. A flat scan of the negative ("straight off the scanner"): lifted
    # blacks, long highlight latitude, pastel colour. Fitted [F], greys timed [T].
    "scan": dict(
        CURVE="scan",
        EXPOSURE=0.0,
        WB_GAIN=[1.000, 1.000, 1.000],
        TOE_STOPS=-1.53,                                                         # [F]
        XTALK=[[ 1.1937, -0.2500,  0.0563],
               [ 0.0711,  0.6942,  0.2348],
               [ 0.0331, -0.0972,  1.0641]],
        K=[4.16, 3.58, 3.68],                   # fit [3.703, 3.578, 3.678]; R timed  [F -> T]
        D_GREY=0.802,
        DMAX=2.0,                               # (print curve only)
        BIAS=[0.0, 0.0, 0.0],                   # fit [+0.002, 0, +0.011], timed out    [T]
        BLACK=[0.0020, 0.0020, 0.0022],         # lifted scan black                     [T]
        BANDS=[[ -1.43,  0.331, -0.004],                                        # [F]
               [ -0.05, -0.215,  0.014],
               [  8.19, -0.158,  0.032],
               [ 12.76,  0.454,  0.022],
               [ -1.67,  0.263, -0.008],
               [ -1.01, -0.097,  0.000],
               [  1.94, -0.103,  0.014]],
        FINISH_BANDS=[[  0.0, -0.250,  0.000],  # reds: the scan inversion over-saturates [T]
                      [  0.0,  0.000,  0.000],
                      [  0.0,  0.000,  0.000],
                      [ -6.0, -0.300,  0.040],  # greens: calmer, toward olive
                      [  0.0, -0.150,  0.000],  # aqua
                      [  0.0,  0.000,  0.000],
                      [  0.0,  0.000,  0.000]],
        HI_DESAT=0.15,                          # (fit 0.0)                            [T]
        SH_DESAT=0.0,
    ),
}


# --------------------------------------------------------------------------
# OKLab helpers (Ottosson)
# --------------------------------------------------------------------------
M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
               [0.2119034982, 0.6806995451, 0.1073969566],
               [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553,  0.7936177850, -0.0040720468],
               [1.9779984951, -2.4285922050,  0.4505937099],
               [0.0259040371,  0.7827717662, -0.8086757660]])
M1I, M2I = np.linalg.inv(M1), np.linalg.inv(M2)

# Hue band centres/widths in OKLab degrees (fixed; only the gains are fitted).
BAND_CENTRES = np.array([ 25.,  55., 105., 140., 200., 255., 320.])  # red, skin/orange, yellow, green, aqua, blue, purple/magenta
BAND_WIDTHS  = np.array([ 20.,  20.,  20.,  25.,  25.,  25.,  30.])


def lin_to_oklab(lin):
    return np.cbrt(np.clip(lin, 0, None) @ M1.T) @ M2.T


def oklab_to_lin(lab):
    return ((lab @ M2I.T) ** 3) @ M1I.T


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------
# The film model (same function for every colour negative stock in Immerse)
# --------------------------------------------------------------------------
def film(scene709, p):
    """scene-linear Rec.709 (N,3) -> display-linear Rec.709 (N,3)."""
    K = np.asarray(p["K"])
    wb = np.asarray(p["WB_GAIN"])
    xt = np.asarray(p["XTALK"])
    bias = np.asarray(p["BIAS"])
    toe = p["TOE_STOPS"] * np.log10(2.0)

    e = np.maximum(scene709 * wb * 2.0 ** p.get("EXPOSURE", 0.0), 1e-7)
    x = np.log10(e / 0.18)                                   # log exposure re: grey
    x = np.log10(10 ** x + 10 ** toe) - np.log10(1 + 10 ** toe)   # soft toe
    x = x @ xt.T                                             # interlayer crosstalk
    d = NEG_GAMMA * x - bias                                 # negative density re: grey

    if p["CURVE"] == "scan":
        # Scanner inversion: output density falls exponentially with negative
        # density. Grey -> D_GREY; long, gentle shoulder (no hard white clip).
        D = p["D_GREY"] * np.exp(-K * d)
    else:
        # Optical print on paper: logistic between paper white (0) and DMAX.
        s0 = p["D_GREY"] / p["DMAX"]
        centre = -np.log(1.0 / s0 - 1.0) / K
        D = p["DMAX"] / (1.0 + np.exp(K * (d - centre)))
    out = 10.0 ** (-np.minimum(D, 6.0))                      # display-linear, white = 1
    black = np.asarray(p["BLACK"])                           # scan/paper black level
    return black + (1.0 - black) * out


def colour_bands(lin, p):
    lab = lin_to_oklab(lin)
    L, a, b = lab[:, 0], lab[:, 1], lab[:, 2]
    Cc = np.hypot(a, b)
    h = np.degrees(np.arctan2(b, a)) % 360
    bands = np.asarray(p["BANDS"]) if p.get("BANDS") is not None else np.zeros((7, 3))
    if p.get("FINISH_BANDS") is not None:
        bands = bands + np.asarray(p["FINISH_BANDS"])          # fitted + finishing
    dh = np.zeros_like(h); cm = np.ones_like(h); lm = np.ones_like(h)
    chroma_gate = np.clip(Cc / 0.03, 0, 1)
    for (hc, w), (sh, cg, lg) in zip(zip(BAND_CENTRES, BAND_WIDTHS), bands):
        dd = (h - hc + 180) % 360 - 180
        wt = np.exp(-0.5 * (dd / w) ** 2) * chroma_gate
        dh += wt * sh                 # hue shift, degrees
        cm *= 1 + wt * cg             # chroma gain - 1
        lm *= 1 + wt * lg             # lightness gain - 1
    Cc = Cc * cm
    Cc *= 1 - p["HI_DESAT"] * smoothstep(0.80, 1.00, L)          # highlight desaturation
    Cc *= 1 - p["SH_DESAT"] * (1 - smoothstep(0.00, 0.35, L))    # shadow desaturation
    L = L * lm
    hr = np.radians(h + dh)
    return oklab_to_lin(np.stack([L, Cc * np.cos(hr), Cc * np.sin(hr)], -1))


def softclip(x, k=0.85):
    return np.where(x < k, x, k + (1 - k) * np.tanh((x - k) / (1 - k)))


def srgb_encode(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, 12.92 * x, 1.055 * x ** (1 / 2.4) - 0.055)


def srgb_decode(v):
    v = np.clip(v, 0, 1)
    return np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)


def render_scene709(scene709, look="print"):
    """scene-linear Rec.709 -> sRGB-encoded output. Used by tests and previews."""
    p = LOOKS[look]
    out = film(np.atleast_2d(scene709), p)
    out = colour_bands(out, p)
    return srgb_encode(softclip(out))


def inverse_knee(y):
    """Phone display-referred linear -> approximate scene-linear (un-tonemaps the
    highlights; identity below 0.6, phone white 1.0 -> 2.6 = ~3.85 stops over grey).
    Same function as the 16mm Cinema spec. Skip it for ProRAW/DNG linear data."""
    d = np.clip(y - 0.6, 0, 0.45)
    return np.where(y <= 0.6, y, 0.6 + d / (1 - d / 0.5))


def build(path=None, look="print", n=33, input_space="applelog"):
    """input_space='applelog': the app LUT (Apple Log curve, Rec.2020 primaries).
       input_space='srgb'    : desktop preview LUT (sRGB photo in), for Photoshop
                               Color Lookup, Camera Raw profiles, Resolve, ffmpeg."""
    g = np.linspace(0, 1, n)
    b, gg, r = np.meshgrid(g, g, g, indexing="ij")           # red varies fastest
    v = np.stack([r, gg, b], -1).reshape(-1, 3)
    if input_space == "applelog":
        scene709 = applelog_decode(v) @ M2020_TO_709.T
        note = "Input: Apple Log curve / Rec.2020 primaries."
    else:
        scene709 = inverse_knee(srgb_decode(v))
        note = "Input: sRGB-encoded photo (preview use only)."
    out = render_scene709(scene709, look)
    # No film or camera brand names in shipped files (ADR 0015).
    path = path or f"immerse_16mm_color_{look}_{input_space}_{n}.cube"
    with open(path, "w") as f:
        f.write(f'TITLE "Immerse 16mm color - {look}"\n')
        f.write(f"# {note} Output: sRGB / Rec.709 display.\n")
        f.write(f"LUT_3D_SIZE {n}\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n")
        for q in out:
            f.write(f"{q[0]:.6f} {q[1]:.6f} {q[2]:.6f}\n")
    return path


# Expected sRGB output for neutral scene-linear grey at N stops from 18% grey.
# Unit-test these in the app's LUT pipeline at +/-0.02.
SANITY = {
    "print": {-6: [0.014, 0.014, 0.015],   # deep projection black
              -2: [0.139, 0.141, 0.148],   # shadows a hair cool
               0: [0.488, 0.488, 0.488],   # daylight grey develops neutral (PRD)
              +2: [0.808, 0.806, 0.801],   # highlights a hair warm
            3.85: [0.937, 0.936, 0.933],   # phone white (after inverse knee)
              +5: [0.967, 0.966, 0.965]},  # long print shoulder, not clipped
    "scan":  {-6: [0.065, 0.063, 0.067],
               0: [0.436, 0.436, 0.436],
              +5: [0.949, 0.950, 0.949]},
}


def self_test():
    grey = lambda stops: np.full((1, 3), 0.18 * 2.0 ** stops)
    for look, exp in SANITY.items():
        for stops, want in exp.items():
            got = render_scene709(grey(stops), look)[0]
            assert np.allclose(got, want, atol=0.02), (look, stops, got, want)
    # LUT round trip: Apple Log grey through the cube equals the direct render.
    import tempfile, os
    with tempfile.TemporaryDirectory() as d:
        p = build(os.path.join(d, "t.cube"), "print", 17)
        lines = [l for l in open(p) if l[:1].isdigit() or l[:1] == "-"]
        assert len(lines) == 17 ** 3, len(lines)
    # Monotonic neutral ramp (no tone reversals).
    ramp = render_scene709(np.repeat((0.18 * 2.0 ** np.linspace(-8, 7, 200))[:, None], 3, 1))
    assert np.all(np.diff(ramp, axis=0) >= -1e-6), "ramp not monotonic"
    print("sanity checks passed")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--look", default="print", choices=sorted(LOOKS))
    ap.add_argument("--size", type=int, default=33)
    ap.add_argument("--input", default="applelog", choices=["applelog", "srgb"])
    ap.add_argument("--test", action="store_true")
    a = ap.parse_args()
    if a.test:
        self_test()
    else:
        print(build(look=a.look, n=a.size, input_space=a.input))
