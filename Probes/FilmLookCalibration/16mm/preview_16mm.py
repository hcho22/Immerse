"""16mm Cinema previews: LUT-only contact sheet and a fully developed frame."""
import sys, numpy as np, colour, skimage.data as sd
from PIL import Image, ImageDraw, ImageFont
import vision3_250d_lut as V
import effects_16mm_reference as E

M709_TO_2020 = np.linalg.inv(V.M2020_TO_709)
TET = colour.algebra.table_interpolation_tetrahedral
try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
except Exception:
    FONT = ImageFont.load_default()


def to_scene(img_u8):
    return V.inverse_knee(V.srgb_decode(img_u8.astype(np.float64) / 255.0))


def lut_apply(lut):
    return lambda alog: np.clip(lut.apply(alog, interpolator=TET), 0, 1)


def lut_only(img_u8, lut):
    alog = V.applelog_encode(to_scene(img_u8) @ M709_TO_2020.T)
    return (lut_apply(lut)(alog) * 255 + 0.5).astype(np.uint8)


def fit43(im, w=480):
    pil = Image.fromarray(E.crop_aspect(im))
    return np.asarray(pil.resize((w, int(round(w * 3 / 4))), Image.LANCZOS))


def chart_scene(illuminant="D65", w=480):
    ill = colour.SDS_ILLUMINANTS[illuminant]
    xyz = np.array([colour.sd_to_XYZ(s, illuminant=ill) / 100 for s in
                    colour.SDS_COLOURCHECKERS["ColorChecker N Ohta"].values()])
    rgb = colour.XYZ_to_RGB(xyz, "ITU-R BT.709", apply_cctf_encoding=False)   # no adaptation: WB locked
    rgb = rgb * (0.18 / (rgb[21] @ np.array([0.2126, 0.7152, 0.0722])))
    h = int(round(w * 3 / 4)); im = np.zeros((h, w, 3))
    cw, ch = w // 6, (h - 50) // 4
    for i, c in enumerate(rgb):
        r, k = divmod(i, 6)
        im[r * ch + 3:(r + 1) * ch - 3, k * cw + 3:(k + 1) * cw - 3] = c
    im[h - 44:h - 4, :] = (0.18 * 2.0 ** np.linspace(-6, 4, w))[None, :, None]
    return im


def sheet(cols, rows, out_path, tile_w=480):
    tile_h = int(round(tile_w * 3 / 4)); pad, top = 10, 30
    canvas = Image.new("RGB", (len(cols) * (tile_w + pad) + pad, len(rows) * (tile_h + pad) + pad + top), (24, 24, 24))
    dr = ImageDraw.Draw(canvas)
    for j, c in enumerate(cols):
        dr.text((pad + j * (tile_w + pad), 6), c, fill=(230, 230, 230), font=FONT)
    for i, row in enumerate(rows):
        for j, t in enumerate(row):
            canvas.paste(Image.fromarray(t), (pad + j * (tile_w + pad), top + pad + i * (tile_h + pad)))
    canvas.save(out_path)


def main(prefix="immerse_16mm_color"):
    print_lut = colour.read_LUT(V.build("/tmp/claude-0/16_print.cube", "print", 33))
    scan_lut = colour.read_LUT(V.build("/tmp/claude-0/16_scan.cube", "scan", 33))
    rows = []
    # charts: daylight, and tungsten with WB locked at daylight (PRD: develops orange)
    for ill in ("D65", "A"):
        sc = chart_scene(ill)
        enc = (V.srgb_encode(np.clip(sc, 0, 1)) * 255 + 0.5).astype(np.uint8)
        alog = V.applelog_encode(sc @ M709_TO_2020.T)
        rows.append([enc] + [(lut_apply(l)(alog) * 255 + 0.5).astype(np.uint8) for l in (print_lut, scan_lut)])
    for name in ("coffee", "chelsea", "rocket"):
        im = fit43(getattr(sd, name)())
        rows.append([im, lut_only(im, print_lut), lut_only(im, scan_lut)])
    sheet(["Original (phone sRGB)", "Print look (default)", "Scan variant"], rows, f"{prefix}_preview.png")

    # one fully developed frame at 1440x1080 (all passes), plus 100% crops
    src = np.asarray(Image.fromarray(E.crop_aspect(sd.rocket())).resize((1440, 1080), Image.LANCZOS))
    dev = E.develop_frame(to_scene(src), None, t=0.4, seed=3, apply_lut=lut_apply(print_lut), M709_TO_2020=M709_TO_2020)
    dev = (dev * 255 + 0.5).astype(np.uint8)
    lut_only_frame = lut_only(src, print_lut)
    from scipy.ndimage import uniform_filter
    lum = uniform_filter(src.astype(float).mean(-1), 60)
    cy, cx = np.unravel_index(np.argmax(lum[150:-150, 150:-150]), lum[150:-150, 150:-150].shape)
    s = 300; y0, x0 = cy + 150 - s // 2, cx + 150 - s // 2           # crop around the brightest lights
    crops = [Image.fromarray(a[y0:y0 + s, x0:x0 + s]).resize((540, 540), Image.NEAREST) for a in (lut_only_frame, dev)]
    W2 = 1440 * 2 + 30
    canvas = Image.new("RGB", (W2, 1080 + 540 + 70), (24, 24, 24))
    dr = ImageDraw.Draw(canvas)
    canvas.paste(Image.fromarray(src), (10, 30)); canvas.paste(Image.fromarray(dev), (1440 + 20, 30))
    dr.text((10, 6), "Original (phone sRGB, upscaled test image)", fill=(230, 230, 230), font=FONT)
    dr.text((1440 + 20, 6), "Developed frame: LUT + halation + soft edges + softness + grain + weave", fill=(230, 230, 230), font=FONT)
    dr.text((10, 1080 + 38), "100% crop x1.8: LUT only", fill=(230, 230, 230), font=FONT)
    dr.text((560, 1080 + 38), "100% crop x1.8: developed (red halation, grain)", fill=(230, 230, 230), font=FONT)
    canvas.paste(crops[0], (10, 1080 + 62 - 0)); canvas.paste(crops[1], (560, 1080 + 62))
    canvas = canvas.crop((0, 0, W2, 1080 + 62 + 540 + 8))
    canvas.save(f"{prefix}_developed_frame.png")
    print("ok")


if __name__ == "__main__":
    main()
