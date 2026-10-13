"""Render before/after previews through the actual .cube (full app input path)."""
import sys, json, numpy as np, colour, skimage.data as sd
from PIL import Image, ImageDraw, ImageFont
import portra400_lut as P

M709_TO_2020 = np.linalg.inv(P.M2020_TO_709)


def inverse_knee(y):                      # phone display-referred -> scene (same as 250D spec)
    d = np.clip(y - 0.6, 0, 0.45)
    return np.where(y <= 0.6, y, 0.6 + d / (1 - d / 0.5))


def load_cube(path):
    return colour.read_LUT(path)


def apply(img_u8, lut):
    v = img_u8.astype(np.float64) / 255.0
    scene709 = inverse_knee(P.srgb_decode(v))
    alog = P.applelog_encode(scene709 @ M709_TO_2020.T)
    out = lut.apply(alog, interpolator=colour.algebra.table_interpolation_tetrahedral)
    return (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)


def square(im, size=360):
    h, w = im.shape[:2]; s = min(h, w)
    y0, x0 = (h - s) // 2, (w - s) // 2
    return np.asarray(Image.fromarray(im[y0:y0 + s, x0:x0 + s]).resize((size, size), Image.LANCZOS))


def chart(size=360):
    ill = colour.SDS_ILLUMINANTS["D65"]
    xyz = np.array([colour.sd_to_XYZ(s, illuminant=ill) / 100 for s in
                    colour.SDS_COLOURCHECKERS["ColorChecker N Ohta"].values()])
    rgb = colour.XYZ_to_RGB(xyz, "ITU-R BT.709", apply_cctf_encoding=False)
    rgb = rgb * (0.18 / rgb[21].mean())
    enc = P.srgb_encode(rgb)
    im = np.zeros((size, size, 3)); cw, ch = size // 6, (size - 60) // 4
    for i, c in enumerate(enc):
        r, k = divmod(i, 6)
        im[r * ch + 4:(r + 1) * ch - 4, k * cw + 4:(k + 1) * cw - 4] = c
    ramp = P.srgb_encode(np.clip(0.18 * 2.0 ** np.linspace(-6, 3.85, size), 0, 1))
    ramp = np.minimum(ramp, 1.0)
    im[size - 52:size - 4, :] = ramp[None, :, None]
    return (im * 255 + 0.5).astype(np.uint8)


def sheet(cubes, labels, out_path):
    imgs = [chart(), square(sd.coffee()), square(sd.chelsea()), square(sd.rocket())]
    luts = [load_cube(c) for c in cubes]
    cols = ["Original (phone sRGB)"] + labels
    tile, pad, top = 360, 12, 34
    W = len(cols) * (tile + pad) + pad
    H = len(imgs) * (tile + pad) + pad + top
    canvas = Image.new("RGB", (W, H), (24, 24, 24))
    dr = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
    except Exception:
        font = ImageFont.load_default()
    for j, lab in enumerate(cols):
        dr.text((pad + j * (tile + pad), 8), lab, fill=(230, 230, 230), font=font)
    for i, im in enumerate(imgs):
        row = [im] + [apply(im, l) for l in luts]
        for j, t in enumerate(row):
            canvas.paste(Image.fromarray(t), (pad + j * (tile + pad), top + pad + i * (tile + pad)))
    canvas.save(out_path)
    return out_path


if __name__ == "__main__":
    cubes = [P.build(f"/tmp/claude-0/prev_{l}.cube", l, 33) for l in ("scan", "print")]
    print(sheet(cubes, ["Scan look (default)", "Endura print (QA reference)"], sys.argv[1] if len(sys.argv) > 1 else "preview.png"))
