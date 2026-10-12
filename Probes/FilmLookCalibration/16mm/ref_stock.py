"""Reference renders from spectral_film_lut for any negative/print pair (scene-linear Rec.2020 in, sRGB out)."""
import numpy as np, colour, warnings
warnings.filterwarnings("ignore")
from spectral_film_lut.film_loader import load_filmstocks
from spectral_film_lut.utils import film_conversion
STOCKS = load_filmstocks(lambda *a: None)
M2020_XYZ = colour.RGB_COLOURSPACES["ITU-R BT.2020"].matrix_RGB_to_XYZ

def ref(rgb2020_lin, negative, printer=None, **kw):
    neg = STOCKS[negative]
    xyz = np.asarray(rgb2020_lin, float) @ M2020_XYZ.T
    shp = xyz.shape
    args = dict(mode="full", input_colorspace=None, exp_kelvin=6500, projector_kelvin=6500,
                white_clip=True, white_balance=1, output_gamut="Rec. 709", gamma_func="sRGB",
                color_masking=neg.color_masking, upsampling_method="SFL upsampling",
                reference_negative=STOCKS["Kodak Vision3 250D 5207"])
    args.update(kw)
    out = film_conversion(xyz.reshape(-1, 1, 3), neg, STOCKS[printer] if printer else None, **args)
    return np.asarray(out).reshape(shp)
