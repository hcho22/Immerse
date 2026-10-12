import numpy as np, colour, warnings, json
warnings.filterwarnings("ignore")
import portra400_lut as P
from preview import inverse_knee, apply, load_cube

lut = load_cube(P.build("/tmp/claude-0/final_scan.cube", "scan", 33))

# 1) how far finishing moved from the fit, on the chart (vs simulation reference)
from ref_eval import ref
ill = colour.SDS_ILLUMINANTS["D65"]
xyz = np.array([colour.sd_to_XYZ(s, illuminant=ill)/100 for s in colour.SDS_COLOURCHECKERS["ColorChecker N Ohta"].values()])
cc = colour.XYZ_to_RGB(xyz, "ITU-R BT.709", apply_cctf_encoding=False); cc *= 0.18/cc[21].mean()
M709_TO_2020 = np.linalg.inv(P.M2020_TO_709)
sim = np.clip(ref(cc @ M709_TO_2020.T, None, inversion=True, inversion_gamma=2.5), 0, 1)
fin = P.render_scene709(cc, "scan")
de = lambda a,b: colour.delta_E(colour.XYZ_to_Lab(colour.sRGB_to_XYZ(a)), colour.XYZ_to_Lab(colour.sRGB_to_XYZ(b)), method="CIE 2000")
d = de(fin, sim)
names = list(colour.SDS_COLOURCHECKERS["ColorChecker N Ohta"].keys())
print("finished look vs simulation: chart dE2000 mean %.2f max %.2f (%s)" % (d.mean(), d.max(), names[int(d.argmax())]))
print("  skin patches:", np.round(d[:2],2))

# 2) tone curve as Lightroom sees it (phone sRGB in -> sRGB out), from the real LUT path
xs = np.array([0, 16, 32, 64, 96, 128, 160, 192, 224, 240, 255])
ramp = np.repeat(xs[:, None], 3, 1)[:, None, :].astype(np.uint8)
out = apply(ramp, lut)[:, 0, :].astype(int)
print("\ninput -> R G B out")
for x, o in zip(xs, out): print(f"  {x:3d} -> {o}")
json.dump({"in": xs.tolist(), "out": out.tolist()}, open("lr_curve.json", "w"))

# 3) per-colour behaviour for HSL estimates: mid-saturation patches of each LR colour
lr_hues = {"Red": 0, "Orange": 30, "Yellow": 60, "Green": 120, "Aqua": 180, "Blue": 225, "Purple": 270, "Magenta": 315}
import colorsys
print("\ncolour: OKLab dHue(deg)  chroma ratio  dL (vs neutral of same luma)")
for n, h in lr_hues.items():
    r, g, b = colorsys.hls_to_rgb(h/360, 0.5, 0.55)
    px = (np.array([[[r, g, b]]]) * 255 + 0.5).astype(np.uint8)
    o = apply(px, lut)[0, 0] / 255
    lab0 = P.lin_to_oklab(P.srgb_decode(np.array([[r, g, b]])))[0]
    lab1 = P.lin_to_oklab(P.srgb_decode(o[None]))[0]
    y = 0.2126*r + 0.7152*g + 0.0722*b
    gp = (np.full((1, 1, 3), y) * 255 + 0.5).astype(np.uint8); go = apply(gp, lut)[0, 0] / 255
    n0 = P.lin_to_oklab(P.srgb_decode(gp[0] / 255))[0]; n1 = P.lin_to_oklab(P.srgb_decode(go[None]))[0]
    h0, h1 = np.degrees(np.arctan2(lab0[2], lab0[1])), np.degrees(np.arctan2(lab1[2], lab1[1]))
    dh = (h1 - h0 + 180) % 360 - 180
    cr = np.hypot(*lab1[1:]) / np.hypot(*lab0[1:])
    dl = (lab1[0] - lab0[0]) - (n1[0] - n0[0])
    print(f"  {n:8s} {dh:+6.1f}   {cr:5.2f}   {dl:+.3f}")
