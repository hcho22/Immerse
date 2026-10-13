import numpy as np, colour, pickle, warnings
warnings.filterwarnings("ignore")
from spectral_film_lut.film_loader import load_filmstocks
from spectral_film_lut.utils import film_conversion
stocks = load_filmstocks(lambda *a: None)
neg = stocks["Kodak Portra 400"]
M2020_XYZ = colour.RGB_COLOURSPACES["ITU-R BT.2020"].matrix_RGB_to_XYZ
def ref(rgb2020_lin, printer="Kodak Endura Premier Paper", **kw):
    xyz = np.asarray(rgb2020_lin, float) @ M2020_XYZ.T
    shp = xyz.shape
    img = xyz.reshape(-1,1,3)
    args = dict(mode="full", input_colorspace=None, exp_kelvin=6500, projector_kelvin=6500,
                white_clip=True, white_balance=1, output_gamut="Rec. 709", gamma_func="sRGB",
                color_masking=neg.color_masking, upsampling_method="SFL upsampling", reference_negative=stocks["Kodak Vision3 250D 5207"])
    args.update(kw)
    out = film_conversion(img, neg, stocks[printer] if printer else None, **args)
    return np.asarray(out).reshape(shp)
if __name__ == "__main__":
    stops = np.arange(-7, 6.5, 1.0)
    g = 0.18 * 2.0**stops
    for p in ["Kodak Endura Premier Paper", "Kodak Portra Endura Paper", "Kodak Supra Endura Paper", None]:
        o = ref(np.stack([g,g,g],-1), p)
        print(p)
        for s, v in zip(stops, o): print(f"  {s:+.0f} stop  sRGB {v[0]:.3f} {v[1]:.3f} {v[2]:.3f}")
