"""Fit portra400_lut.py constants to the spectral_film_lut Portra 400 simulation."""
import sys, json, warnings
import numpy as np, colour
from scipy.optimize import least_squares
warnings.filterwarnings("ignore")
import portra400_lut as P
from ref_eval import ref, M2020_XYZ

LOOK = sys.argv[1] if len(sys.argv) > 1 else "scan"
rng = np.random.default_rng(7)
M709_TO_2020 = np.linalg.inv(P.M2020_TO_709)

# ---------- scene samples (scene-linear Rec.709) ----------
stops = np.arange(-6, 6.01, 0.25)
grey = np.repeat((0.18 * 2.0 ** stops)[:, None], 3, 1)

# ColorChecker reflectances under D65 -> Rec.709 linear
cc_xyz = []
ill = colour.SDS_ILLUMINANTS["D65"]
for name, sd in colour.SDS_COLOURCHECKERS["ColorChecker N Ohta"].items():
    cc_xyz.append(colour.sd_to_XYZ(sd, illuminant=ill) / 100.0)
cc_xyz = np.array(cc_xyz)
cc709 = colour.XYZ_to_RGB(cc_xyz, "ITU-R BT.709", apply_cctf_encoding=False)
cc709 = cc709 * (0.18 / cc709[21].mean())          # neutral 5 patch -> 0.18 (approx. grey card)
cc = np.concatenate([cc709 * 2.0 ** e for e in (-3, -2, -1, 0, 1, 2, 3)])
cc_w = np.tile(np.where(np.isin(np.arange(24), [0, 1]), 4.0, 2.0), 7)   # skin patches x2

# random surface-like colours: random Rec.709 chromaticities, varied exposure
rnd = rng.uniform(0, 1, (2500, 3)) ** 1.5
rnd /= (rnd @ np.array([0.2126, 0.7152, 0.0722]))[:, None] + 1e-6
rnd *= (0.18 * 2.0 ** rng.uniform(-5, 4, 2500))[:, None]
rnd = np.clip(rnd, 0, None)

X = np.concatenate([grey, cc, rnd])
W = np.concatenate([np.full(len(grey), 4.0), cc_w, np.ones(len(rnd))])

def reference(x709):
    rgb2020 = x709 @ M709_TO_2020.T
    if LOOK == "scan":
        return ref(rgb2020, None, inversion=True, inversion_gamma=2.5)
    return ref(rgb2020, "Kodak Endura Premier Paper")

Y = np.clip(reference(X), 0, 1)
Ylab = P.lin_to_oklab(P.srgb_decode(Y))

# ---------- parameter vector ----------
NP = 44
def unpack(t):
    p = {}
    p["CURVE"] = "scan" if LOOK == "scan" else "print"
    p["WB_GAIN"] = [1.0, 1.0, 1.0]
    off = t[2:8]
    xt = np.array([[0, off[0], off[1]], [off[2], 0, off[3]], [off[4], off[5], 0]])
    xt[np.diag_indices(3)] = 1 - xt.sum(1)
    p["XTALK"] = xt.tolist()
    p["TOE_STOPS"] = t[8]
    p["K"] = list(np.exp(t[9:12]))
    p["DMAX"] = 2.0 + np.exp(t[12])
    p["D_GREY"] = t[13]
    p["BIAS"] = [t[14], 0.0, t[15]]
    p["BANDS"] = t[16:37].reshape(7, 3).tolist()
    p["HI_DESAT"], p["SH_DESAT"] = t[37], t[38]
    p["BLACK"] = list(np.exp(t[39:42]))
    return p

t0 = np.zeros(NP)
t0[8] = -4.0; t0[9:12] = np.log(3.0); t0[12] = np.log(0.4); t0[13] = 0.7; t0[39:42] = np.log(0.005)

def model(t, x):
    p = unpack(t)
    P.LOOKS["_fit"] = p
    out = P.film(x, p)
    out = P.colour_bands(out, p)
    return P.softclip(out)

def resid(t):
    lab = P.lin_to_oklab(np.clip(model(t, X), 0, None))
    r = (lab - Ylab) * np.sqrt(W)[:, None]
    reg = 0.02 * t[16:37]                     # keep colour bands small
    return np.concatenate([r.ravel(), reg])

lo = np.full(NP, -np.inf); hi = np.full(NP, np.inf)
lo[0:2], hi[0:2] = -1e-9, 1e-9
lo[42:], hi[42:] = -1e-9, 1e-9
lo[2:8], hi[2:8] = -0.25, 0.25
lo[39:42], hi[39:42] = np.log(1e-4), np.log(0.05)
lo[8], hi[8] = -7, -1
lo[13], hi[13] = 0.3, 1.5
lo[37:39], hi[37:39] = 0, 0.8
lo[16:37], hi[16:37] = np.tile([-25, -0.6, -0.4], 7), np.tile([25, 0.6, 0.4], 7)

TONE = np.array([8, 9, 10, 11, 12, 13, 14, 15, 39, 40, 41])
COL = np.array(list(range(2, 8)) + list(range(16, 39)))
ng = len(grey)

def stage(idx, t_base, rows):
    def f(sub):
        t = t_base.copy(); t[idx] = sub
        lab = P.lin_to_oklab(np.clip(model(t, X[rows]), 0, None))
        r = (lab - Ylab[rows]) * np.sqrt(W[rows])[:, None]
        reg = 0.02 * t[16:37] if idx is COL else np.zeros(0)
        return np.concatenate([r.ravel(), reg])
    s = least_squares(f, t_base[idx], bounds=(lo[idx], hi[idx]), x_scale="jac", max_nfev=600)
    t = t_base.copy(); t[idx] = s.x
    return t, s.cost

t1, c1 = stage(TONE, t0, np.arange(ng))                 # stage 1: neutral axis only
t2, c2 = stage(COL, t1, np.arange(len(X)))              # stage 2: colour, tone locked
class _S: pass
sol = _S(); sol.x = t2; sol.cost = c2
p = unpack(sol.x)

# ---------- report ----------
def de2000(a_srgb, b_srgb):
    la = colour.XYZ_to_Lab(colour.sRGB_to_XYZ(a_srgb))
    lb = colour.XYZ_to_Lab(colour.sRGB_to_XYZ(b_srgb))
    return colour.delta_E(la, lb, method="CIE 2000")

pred = P.srgb_encode(model(sol.x, X))
d = de2000(pred, Y)
n1, n2 = len(grey), len(grey) + len(cc)
print(f"LOOK={LOOK}  cost={sol.cost:.4f}")
print(f"dE2000 grey  mean {d[:n1].mean():.2f}  max {d[:n1].max():.2f}")
print(f"dE2000 chart mean {d[n1:n2].mean():.2f}  p95 {np.percentile(d[n1:n2],95):.2f}")
print(f"dE2000 rand  mean {d[n2:].mean():.2f}  p95 {np.percentile(d[n2:],95):.2f}")
def r(v): return np.round(np.asarray(v, float), 4).tolist()
out = {k: (v if isinstance(v, str) else round(float(v), 4) if np.isscalar(v) else r(v)) for k, v in p.items()}
json.dump(out, open(f"fit_{LOOK}.json", "w"), indent=1)
print(json.dumps(out))
for s in (-4, -2, -1, 0, 1, 2, 3, 4, 5):
    i = int((s + 6) / 0.25)
    print(f"{s:+d} stops  ref {np.round(Y[i],3)}  fit {np.round(pred[i],3)}")
