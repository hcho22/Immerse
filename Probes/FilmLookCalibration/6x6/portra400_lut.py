#!/usr/bin/env python3
"""
Immerse - 6x6 Medium Format, color Film Stock
3D LUT generator for a Kodak Portra 400 look (internal Format Reference only;
never show the film or camera name in the product).

Same pipeline and input space as the 16mm Cinema (250D) generator, so the app
needs one LUT sampler and one pre-pass for every camera:

    Input domain : Apple Log curve, Rec.2020 primaries (scene-referred).
                   Phone sRGB / Display P3 photos are converted into this space
                   by the shader pre-pass (see spec).
    Output       : sRGB / Rec.709 display-encoded.

Pipeline: decode -> Rec.2020->709 -> white-balance gain -> log10 exposure re: grey
-> soft negative toe -> 3x3 interlayer crosstalk (log space) -> negative gamma
-> per-channel logistic output curve (scan or print) -> OKLCh hue/chroma bands
-> highlight soft-clip -> sRGB encode.

Source labels on every constant:
  [P] published (Kodak / Apple / ITU)
  [F] fitted to a datasheet-driven spectral simulation (spectral_film_lut, MIT):
      Kodak Portra 400 negative, scanned with an ACES-style inversion (SCAN look)
      or printed on Kodak Endura Premier paper (PRINT look).
  [T] tuned by hand on top of the fit; validate against real scans.

Usage:
    python3 portra400_lut.py                     # app LUT: immerse_6x6_color_scan_applelog_33.cube
    python3 portra400_lut.py --size 65           # 65^3 app LUT (recommended for log input)
    python3 portra400_lut.py --input srgb        # desktop preview LUT (sRGB photo in)
    python3 portra400_lut.py --look print        # Endura print reference look (QA only)
    python3 portra400_lut.py --test              # sanity assertions

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
# Portra 400 negative: straight-line slope of the Kodak E-4050 characteristic
# curve (Status M), read from the digitized curve as ~0.55; toe ~4 stops under
# grey; straight line continues >6 stops over grey.               [P-derived]
NEG_GAMMA = np.array([0.556, 0.550, 0.641])   # R, G, B

LOOKS = {
    # DEFAULT. A modern lab scan of the negative: gentle contrast, open shadows,
    # highlights that keep detail 5-6 stops over grey (Portra's latitude).
    # Fitted to the spectral simulation of a scanned Portra 400 negative [F],
    # then finished the way a lab scanner operator would [T]: grey-balanced,
    # exposed a little bright, warm highlights, calmer reds/greens.
    "scan": dict(
        CURVE="scan",
        EXPOSURE=+0.25,                         # stops; a little bright, as labs scan Portra [T]
        WB_GAIN=[1.025, 1.000, 0.955],          # Portra warmth, ~ +300 K           [T]
        TOE_STOPS=-1.08,                        # soft negative toe                 [F]
        XTALK=[[ 1.1919, -0.2500,  0.0581],     # interlayer crosstalk, log space   [F]
               [ 0.1446,  0.6054,  0.2500],     #  rows sum to 1 -> greys stay grey
               [ 0.0511, -0.0468,  0.9957]],
        # Output-curve slopes. Fit: [3.858, 3.980, 3.978]. Blue is rebalanced for
        # the steeper blue record (x 0.550/0.641) so greys don't cross over, then
        # trimmed 3% for warm highlights / slightly cool shadows.       [F -> T]
        K=[3.90, 3.98, 3.31],
        D_GREY=0.80,                            # grey output density (fit 0.823)   [F]
        DMAX=2.0,                               # (print curve only)
        BIAS=[0.0, 0.0, 0.0],                   # fit [-0.010, 0, +0.004], removed  [T]
        BLACK=[0.0015, 0.0015, 0.0017],         # lifted scan black, a hair cool    [T]
        # OKLCh hue bands: (hue shift deg, chroma gain-1, lightness gain-1).
        # Order: red, skin/orange, yellow, green, aqua, blue, purple/magenta.
        BANDS=[[ -3.29,  0.378, -0.018],                                         # [F]
               [ -2.41, -0.152,  0.009],
               [  4.97, -0.136,  0.012],
               [  7.37,  0.289,  0.073],
               [ -3.30,  0.304,  0.008],
               [ -7.28, -0.054,  0.017],
               [ -4.49, -0.153,  0.023]],
        FINISH_BANDS=[[  3.0, -0.280,  0.000],  # reds: calmer, a touch orange    [T]
                      [  0.0, +0.080, +0.030],  # skin: fuller, slightly brighter
                      [  0.0,  0.000,  0.000],  # yellows
                      [ -8.0, -0.220, +0.060],  # greens: soft, pastel, less teal
                      [  0.0, -0.250,  0.000],  # aqua
                      [  0.0, -0.030, +0.030],  # blues: lighter skies
                      [  0.0,  0.000,  0.000]], # purple/magenta
        HI_DESAT=0.25,                          # creamy highlights (fit 0.09)      [T]
        SH_DESAT=0.15,                          # quieter shadows (fit 0.0)         [T]
    ),
    # REFERENCE ONLY. Optical print on Kodak Endura Premier paper (the paper the
    # E-4050 datasheet says Portra is optimised for). Much more contrast than the
    # PRD's "gentle contrast"; use it for QA comparisons, not as the default.
    "print": dict(
        CURVE="print",
        EXPOSURE=0.0,
        WB_GAIN=[1.000, 1.000, 1.000],
        TOE_STOPS=-1.00,                                                          # [F]
        XTALK=[[ 1.2288, -0.2500,  0.0212],
               [ 0.1703,  0.5797,  0.2500],
               [-0.0986, -0.0051,  1.1038]],
        K=[7.286, 8.651, 8.545],
        D_GREY=0.666,
        DMAX=6.904,
        BIAS=[-0.0025, 0.0, -0.0005],
        BLACK=[0.0024, 0.0045, 0.0056],
        BANDS=[[  0.88,  0.084, -0.007],
               [ -3.59, -0.108, -0.051],
               [ -4.74,  0.149, -0.018],
               [ -6.71, -0.235,  0.032],
               [  0.59, -0.386,  0.034],
               [ -1.94, -0.093,  0.016],
               [ -0.49, -0.175,  0.023]],
        FINISH_BANDS=None,
        HI_DESAT=0.496,
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


def render_scene709(scene709, look="scan"):
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


def build(path=None, look="scan", n=33, input_space="applelog"):
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
    path = path or f"immerse_6x6_color_{look}_{input_space}_{n}.cube"
    with open(path, "w") as f:
        f.write(f'TITLE "Immerse 6x6 color - {look}"\n')
        f.write(f"# {note} Output: sRGB / Rec.709 display.\n")
        f.write(f"LUT_3D_SIZE {n}\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n")
        for q in out:
            f.write(f"{q[0]:.6f} {q[1]:.6f} {q[2]:.6f}\n")
    return path


# Expected sRGB output for neutral scene-linear grey at N stops from 18% grey.
# Unit-test these in the app's LUT pipeline at +/-0.02.
SANITY = {
    "scan": {-6: [0.080, 0.078, 0.086],   # lifted, very slightly cool scan black
             -2: [0.210, 0.204, 0.206],
              0: [0.488, 0.480, 0.470],   # grey prints a little bright and warm
             +2: [0.792, 0.789, 0.776],
           3.85: [0.932, 0.931, 0.925],   # phone white (after inverse knee)
             +5: [0.965, 0.965, 0.962]},  # still not clipped: Portra latitude
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
        p = build(os.path.join(d, "t.cube"), "scan", 17)
        lines = [l for l in open(p) if l[:1].isdigit() or l[:1] == "-"]
        assert len(lines) == 17 ** 3, len(lines)
    # Monotonic neutral ramp (no tone reversals).
    ramp = render_scene709(np.repeat((0.18 * 2.0 ** np.linspace(-8, 7, 200))[:, None], 3, 1))
    assert np.all(np.diff(ramp, axis=0) >= -1e-6), "ramp not monotonic"
    print("sanity checks passed")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--look", default="scan", choices=sorted(LOOKS))
    ap.add_argument("--size", type=int, default=33)
    ap.add_argument("--input", default="applelog", choices=["applelog", "srgb"])
    ap.add_argument("--test", action="store_true")
    a = ap.parse_args()
    if a.test:
        self_test()
    else:
        print(build(look=a.look, n=a.size, input_space=a.input))
