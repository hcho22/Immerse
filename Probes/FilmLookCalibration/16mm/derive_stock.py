"""Measure a shipped look: drift from the simulation, Lightroom tone curve, per-colour OKLab behaviour,
LUT-path agreement and LUT-size agreement.

    python3 derive_stock.py vision3_250d_lut print "Kodak Vision3 250D 5207" "Kodak Vision 2383"
    python3 derive_stock.py portra400_lut scan "Kodak Portra 400"
"""
import sys, importlib, warnings, colorsys
import numpy as np, colour, skimage.data as sd
from PIL import Image
warnings.filterwarnings("ignore")
MOD, LOOK, NEG = sys.argv[1], sys.argv[2], sys.argv[3]
PRINT = sys.argv[4] if len(sys.argv) > 4 else None
P = importlib.import_module(MOD)
from ref_stock import ref

M709_TO_2020 = np.linalg.inv(P.M2020_TO_709)
TET = colour.algebra.table_interpolation_tetrahedral
de = lambda a, b: colour.delta_E(colour.XYZ_to_Lab(colour.sRGB_to_XYZ(a)), colour.XYZ_to_Lab(colour.sRGB_to_XYZ(b)), method="CIE 2000")

lut33 = colour.read_LUT(P.build("/tmp/claude-0/d33.cube", LOOK, 33))
lut65 = colour.read_LUT(P.build("/tmp/claude-0/d65.cube", LOOK, 65))
lutS = colour.read_LUT(P.build("/tmp/claude-0/dS.cube", LOOK, 33, input_space="srgb"))

def via_log(img_u8, lut):
    v = img_u8.astype(float) / 255
    alog = P.applelog_encode(P.inverse_knee(P.srgb_decode(v)) @ M709_TO_2020.T)
    return np.clip(lut.apply(alog, interpolator=TET), 0, 1)

# 1) drift of the shipped look from the simulation on the ColorChecker
ill = colour.SDS_ILLUMINANTS["D65"]
xyz = np.array([colour.sd_to_XYZ(s, illuminant=ill) / 100 for s in colour.SDS_COLOURCHECKERS["ColorChecker N Ohta"].values()])
cc = colour.XYZ_to_RGB(xyz, "ITU-R BT.709", apply_cctf_encoding=False); cc *= 0.18 / cc[21].mean()
kw = dict(inversion=True, inversion_gamma=2.5) if LOOK == "scan" else {}
sim = np.clip(ref(cc @ M709_TO_2020.T, NEG, None if LOOK == "scan" else PRINT, **kw), 0, 1)
d = de(P.render_scene709(cc, LOOK), sim)
names = list(colour.SDS_COLOURCHECKERS["ColorChecker N Ohta"].keys())
print(f"shipped vs simulation, chart dE2000: mean {d.mean():.2f} max {d.max():.2f} ({names[int(d.argmax())]}); skin {np.round(d[:2], 2)}")

# 2) LUT path and size agreement on test photos
for n in ("coffee", "chelsea", "rocket"):
    im = getattr(sd, n)()
    a = via_log(im, lut33); b = np.clip(lutS.apply(im / 255.0, interpolator=TET), 0, 1); c = via_log(im, lut65)
    print(f"  {n}: applelog33 vs srgb33 dE mean {de(a, b).mean():.2f} p99 {np.percentile(de(a, b), 99):.2f} | 33 vs 65 mean {de(a, c).mean():.2f} p99 {np.percentile(de(a, c), 99):.2f}")

# 3) Lightroom tone curve through the real LUT path
xs = np.array([0, 16, 32, 64, 96, 128, 160, 192, 224, 240, 255])
out = (via_log(np.repeat(xs[:, None], 3, 1)[:, None, :].astype(np.uint8), lut33)[:, 0] * 255 + 0.5).astype(int)
print("tone curve in -> R G B"); [print(f"  {x:3d} -> {o}") for x, o in zip(xs, out)]

# 4) per-colour behaviour in OKLab vs a neutral of the same luma
print("colour: dHue(deg) chroma-ratio dL")
for n, h in {"Red": 0, "Orange": 30, "Yellow": 60, "Green": 120, "Aqua": 180, "Blue": 225, "Purple": 270, "Magenta": 315}.items():
    r, g, b = colorsys.hls_to_rgb(h / 360, 0.5, 0.55)
    px = (np.array([[[r, g, b]]]) * 255 + 0.5).astype(np.uint8); o = via_log(px, lut33)[0, 0]
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    gp = (np.full((1, 1, 3), y) * 255 + 0.5).astype(np.uint8); go = via_log(gp, lut33)[0, 0]
    L0, L1 = P.lin_to_oklab(P.srgb_decode(np.array([[r, g, b]])))[0], P.lin_to_oklab(P.srgb_decode(o[None]))[0]
    n0, n1 = P.lin_to_oklab(P.srgb_decode(gp[0] / 255))[0], P.lin_to_oklab(P.srgb_decode(go[None]))[0]
    dh = (np.degrees(np.arctan2(L1[2], L1[1]) - np.arctan2(L0[2], L0[1])) + 180) % 360 - 180
    print(f"  {n:8s} {dh:+6.1f} {np.hypot(*L1[1:]) / np.hypot(*L0[1:]):5.2f} {(L1[0] - L0[0]) - (n1[0] - n0[0]):+.3f}")
