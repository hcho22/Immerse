"""Fit a film_lut generator's constants to the spectral_film_lut simulation.

    python3 fit_stock.py <generator module> <look: print|scan> <negative> [print stock]
    e.g. python3 fit_stock.py vision3_250d_lut print "Kodak Vision3 250D 5207" "Kodak Vision 2383"
         python3 fit_stock.py portra400_lut scan "Kodak Portra 400"

Two stages: (1) tone on a neutral exposure ramp, (2) colour with tone locked
(crosstalk rows sum to 1 and the hue bands are chroma-gated, so greys can't move).
To calibrate to real scans instead, replace reference() with measured patch values.
"""
import sys, json, importlib, warnings
import numpy as np, colour
from scipy.optimize import least_squares
warnings.filterwarnings("ignore")

MOD, LOOK, NEG = sys.argv[1], sys.argv[2], sys.argv[3]
PRINT = sys.argv[4] if len(sys.argv) > 4 else None
P = importlib.import_module(MOD)
from ref_stock import ref

rng = np.random.default_rng(7)
M709_TO_2020 = np.linalg.inv(P.M2020_TO_709)

stops = np.arange(-6, 6.01, 0.25)
grey = np.repeat((0.18 * 2.0 ** stops)[:, None], 3, 1)
ill = colour.SDS_ILLUMINANTS["D65"]
cc_xyz = np.array([colour.sd_to_XYZ(sd, illuminant=ill) / 100.0
                   for sd in colour.SDS_COLOURCHECKERS["ColorChecker N Ohta"].values()])
cc709 = colour.XYZ_to_RGB(cc_xyz, "ITU-R BT.709", apply_cctf_encoding=False)
cc709 = cc709 * (0.18 / cc709[21].mean())
cc = np.concatenate([cc709 * 2.0 ** e for e in (-3, -2, -1, 0, 1, 2, 3)])
cc_w = np.tile(np.where(np.isin(np.arange(24), [0, 1]), 4.0, 2.0), 7)
rnd = rng.uniform(0, 1, (2500, 3)) ** 1.5
rnd /= (rnd @ np.array([0.2126, 0.7152, 0.0722]))[:, None] + 1e-6
rnd *= (0.18 * 2.0 ** rng.uniform(-5, 4, 2500))[:, None]
X = np.concatenate([grey, cc, np.clip(rnd, 0, None)])
W = np.concatenate([np.full(len(grey), 4.0), cc_w, np.ones(len(rnd))])

def reference(x709):
    r2020 = x709 @ M709_TO_2020.T
    if LOOK == "scan":
        return ref(r2020, NEG, None, inversion=True, inversion_gamma=2.5)
    return ref(r2020, NEG, PRINT)

Y = np.clip(reference(X), 0, 1)
Ylab = P.lin_to_oklab(P.srgb_decode(Y))

NP = 42
def unpack(t):
    off = t[0:6]
    xt = np.array([[0, off[0], off[1]], [off[2], 0, off[3]], [off[4], off[5], 0]])
    xt[np.diag_indices(3)] = 1 - xt.sum(1)
    return dict(CURVE=LOOK, EXPOSURE=0.0, WB_GAIN=[1.0, 1.0, 1.0], XTALK=xt.tolist(),
                TOE_STOPS=t[6], K=list(np.exp(t[7:10])), DMAX=2.0 + np.exp(t[10]),
                D_GREY=t[11], BIAS=[t[12], 0.0, t[13]], BANDS=t[14:35].reshape(7, 3).tolist(),
                FINISH_BANDS=None, HI_DESAT=t[35], SH_DESAT=t[36], BLACK=list(np.exp(t[37:40])))

t0 = np.zeros(NP)
t0[6] = -4.5; t0[7:10] = np.log(3.0); t0[10] = np.log(2.0); t0[11] = 0.9; t0[37:40] = np.log(0.002)
lo = np.full(NP, -np.inf); hi = np.full(NP, np.inf)
lo[0:6], hi[0:6] = -0.25, 0.25
lo[6], hi[6] = -7, -1
lo[11], hi[11] = 0.3, 1.8
lo[14:35], hi[14:35] = np.tile([-25, -0.6, -0.4], 7), np.tile([25, 0.6, 0.4], 7)
lo[35:37], hi[35:37] = 0, 0.8
lo[37:40], hi[37:40] = np.log(1e-4), np.log(0.05)
lo[40:], hi[40:] = -1e-9, 1e-9

def model(t, x):
    p = unpack(t)
    return P.softclip(P.colour_bands(P.film(x, p), p))

TONE = np.array([6, 7, 8, 9, 10, 11, 12, 13, 37, 38, 39])
COL = np.array(list(range(0, 6)) + list(range(14, 37)))

def stage(idx, tb, rows, reg):
    def f(sub):
        t = tb.copy(); t[idx] = sub
        lab = P.lin_to_oklab(np.clip(model(t, X[rows]), 0, None))
        r = ((lab - Ylab[rows]) * np.sqrt(W[rows])[:, None]).ravel()
        return np.concatenate([r, 0.02 * t[14:35]]) if reg else r
    x0 = np.clip(tb[idx] + 1e-3, lo[idx], hi[idx])          # step off the start/bounds
    s = least_squares(f, x0, bounds=(lo[idx], hi[idx]), x_scale="jac", ftol=1e-12,
                      xtol=1e-12, gtol=1e-12, diff_step=1e-3, max_nfev=600)
    t = tb.copy(); t[idx] = s.x
    return t

t1 = stage(TONE, t0, np.arange(len(grey)), False)
t2 = stage(COL, t1, np.arange(len(X)), True)
p = unpack(t2)

def de2000(a, b):
    return colour.delta_E(colour.XYZ_to_Lab(colour.sRGB_to_XYZ(a)),
                          colour.XYZ_to_Lab(colour.sRGB_to_XYZ(b)), method="CIE 2000")
pred = P.srgb_encode(model(t2, X)); d = de2000(pred, Y)
n1, n2 = len(grey), len(grey) + len(cc)
print(f"{MOD} {LOOK}: dE2000 grey mean {d[:n1].mean():.2f} max {d[:n1].max():.2f} | "
      f"chart mean {d[n1:n2].mean():.2f} p95 {np.percentile(d[n1:n2], 95):.2f} | "
      f"random mean {d[n2:].mean():.2f} p95 {np.percentile(d[n2:], 95):.2f}")
r4 = lambda v: v if isinstance(v, str) or v is None else (round(float(v), 4) if np.isscalar(v) else np.round(np.asarray(v, float), 4).tolist())
out = {k: r4(v) for k, v in p.items()}
json.dump(out, open(f"fit_{MOD}_{LOOK}.json", "w"), indent=1)
for k, v in out.items(): print(" ", k, v)
for s in (-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5):
    i = int((s + 6) / 0.25)
    print(f"  {s:+d} stops ref {np.round(Y[i], 3)} fit {np.round(pred[i], 3)}")
