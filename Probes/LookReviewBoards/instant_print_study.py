#!/usr/bin/env python3
"""Measures scans of preserved 1970s integral instant prints, and the app's Instant prints the same way.

Usage:
  instant_print_study.py --sources DIR --output DIR [--scenes scenes.json] [--renders LABEL=DIR ...]

--sources is the boards' source directory: manifest.json and the files it lists. Every entry with a "study" record
is measured, after its file is checked against the SHA-256 the manifest records.
--renders names outputs of the LookReviewBoards tool; their Instant scenes and packs are measured the same way.
--scenes is the scenes.json they were rendered from, which keeps the measure to the scenes the Instant's board shows.
Writes measurements.json and measurements.md into --output. Needs numpy and Pillow.

What is measured, and why it is measured this way, is in Evidence/NativeApp/instant-study-and-toning-061.md.
Nothing here sets a look or ships in the app.
"""

import argparse
import hashlib
import io
import json
import os

import numpy as np
from PIL import Image, ImageCms

SRGB = ImageCms.createProfile("sRGB")
LUMA = np.array([0.2126, 0.7152, 0.0722])


def load(path, edge=480):
    """The scan as sRGB display tones from 0 to 1, reduced by area averaging so dust and JPEG noise set no percentile."""
    image = Image.open(path)
    profile = image.info.get("icc_profile")
    image = image.convert("RGB")
    if profile:
        try:
            image = ImageCms.profileToProfile(image, ImageCms.ImageCmsProfile(io.BytesIO(profile)), SRGB, outputMode="RGB")
        except ImageCms.PyCMSError:
            pass
    scale = edge / max(image.size)
    if scale < 1:
        image = image.resize((round(image.width * scale), round(image.height * scale)), Image.BOX)
    return np.asarray(image, dtype=np.float64) / 255


def linear(tone):
    return np.where(tone <= 0.04045, tone / 12.92, ((tone + 0.055) / 1.055) ** 2.4)


def encoded(light):
    light = np.clip(light, 0, None)
    return np.where(light <= 0.0031308, light * 12.92, 1.055 * light ** (1 / 2.4) - 0.055)


def lab(light):
    """CIELAB (D65) of linear sRGB."""
    matrix = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = light @ matrix.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(np.clip(xyz, 1e-9, None)), (24389 / 27 * xyz + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def picture_box(tones):
    """The picture inside a scan that shows the print's white card, as (left, top, right, bottom).

    The card is the near-white, colorless surround; a row or column belongs to the picture when most of it is not card.
    """
    height, width, _ = tones.shape
    band = max(2, round(min(height, width) * 0.02))
    edge = np.concatenate([tones[:band].reshape(-1, 3), tones[-band:].reshape(-1, 3),
                           tones[:, :band].reshape(-1, 3), tones[:, -band:].reshape(-1, 3)])
    level = edge.sum(axis=1)
    paper = np.median(edge[level >= np.percentile(level, 60)], axis=0)
    inside = np.abs(tones - paper).max(axis=2) > 0.10

    def run(profile):
        best, start = (0, 0), None
        for index, value in enumerate(list(profile > 0.5) + [False]):
            if value and start is None:
                start = index
            if not value and start is not None:
                if index - start > best[1] - best[0]:
                    best = (start, index)
                start = None
        return best

    top, bottom = run(inside.mean(axis=1))
    left, right = run(inside[top:bottom].mean(axis=0))
    top, bottom = run(inside[:, left:right].mean(axis=1))
    return left, top, right, bottom


def card_white(tones, box):
    """The card's color: the median of what lies outside the picture and is not writing, dirt or shadow."""
    left, top, right, bottom = box
    height, width, _ = tones.shape
    mask = np.ones((height, width), dtype=bool)
    grow = max(2, round(min(height, width) * 0.02))
    mask[max(0, top - grow):bottom + grow, max(0, left - grow):right + grow] = False
    pixels = tones[mask]
    if len(pixels) < 50:
        return None
    level = pixels.sum(axis=1)
    return np.median(pixels[level >= np.percentile(level, 50)], axis=0)


def measure(tones, box=None, paper=None):
    """Where the picture's black and white sit, their color, and how its tones spread between them.

    Tones are sRGB display tones from 0 to 1. With `paper`, the card's color, black and white are also given
    relative to the card, which takes the scanner's exposure and color balance out of them.
    """
    height, width, _ = tones.shape
    if box is None:
        inset_x, inset_y = round(width * 0.04), round(height * 0.04)
        box = (inset_x, inset_y, width - inset_x, height - inset_y)
    left, top, right, bottom = box
    shrink_x, shrink_y = max(1, round((right - left) * 0.025)), max(1, round((bottom - top) * 0.025))
    picture = tones[top + shrink_y:bottom - shrink_y, left + shrink_x:right - shrink_x].reshape(-1, 3)
    light = linear(picture)
    y = light @ LUMA
    order = np.argsort(y)
    share = max(1, len(y) // 50)
    dark, bright = order[:share], order[-share:]
    colors = lab(light)
    tone = encoded(y)
    low, high = np.percentile(tone, 1), np.percentile(tone, 99)
    spread = np.clip((tone - low) / max(high - low, 1e-6), 0, 1)
    result = {
        "box": [int(value) for value in box],
        "black": float(encoded(np.percentile(y, 1))), "white": float(encoded(np.percentile(y, 99))),
        "lowest": float(encoded(np.percentile(y, 0.5))), "highest": float(encoded(np.percentile(y, 99.5))),
        "middle": float(encoded(np.percentile(y, 50))),
        "black_rgb": [float(value) for value in picture[dark].mean(axis=0)],
        "white_rgb": [float(value) for value in picture[bright].mean(axis=0)],
        "mean_lab": [float(value) for value in colors.mean(axis=0)],
        "color_strength": float(np.hypot(colors[:, 1], colors[:, 2]).mean()),
        "mean_stops": float(np.log2(np.clip(y, 1e-4, None)).mean()),
        "spread": float(spread.std()),
        "spread_quartiles": [float(value) for value in np.percentile(spread, [10, 25, 50, 75, 90])],
    }
    if paper is not None:
        paper_light = linear(np.asarray(paper))
        relative = light / paper_light
        relative_y = relative @ LUMA
        relative_colors = lab(np.clip(relative, 0, None))
        result.update({
            "card_rgb": [float(value) for value in paper],
            "card_black": float(encoded(np.percentile(relative_y, 1))), "card_white": float(encoded(np.percentile(relative_y, 99))),
            "card_black_density": float(-np.log10(np.percentile(relative_y, 1))),
            "card_white_density": float(-np.log10(np.percentile(relative_y, 99))),
            "card_white_lab": [float(value) for value in relative_colors[bright].mean(axis=0)],
            "card_black_lab": [float(value) for value in relative_colors[dark].mean(axis=0)],
        })
    return result


def flags(result):
    """What in a scan makes its black or white unusable: a scanner or an editor has clipped them."""
    found = []
    if result.get("card_rgb") and max(result["card_rgb"]) >= 0.985:
        found.append("card clipped to white")
    # A channel at nothing in the darkest tones is clipping too, though the luminance is not.
    if result["lowest"] <= 0.02 or min(result["black_rgb"]) <= 0.02:
        found.append("black clipped")
    if result["highest"] >= 0.985 or max(result["white_rgb"]) >= 0.995:
        found.append("white clipped")
    return found


def stops(values):
    """The standard deviation of positive values in stops."""
    return float(np.std(np.log2(np.asarray(values)), ddof=1)) if len(values) > 1 else None


def between_prints(rows):
    """How far prints differ from one another, in measures a scene changes least: the level and color of their whites
    and blacks. Levels and color ratios are in stops of linear light.
    """
    white = linear(np.array([row["white_rgb"] for row in rows]))
    black = linear(np.clip(np.array([row["black_rgb"] for row in rows]), 1e-3, None))
    return {
        "prints": len(rows),
        "white_level": stops(white @ LUMA), "white_blue_red": stops(white[:, 2] / white[:, 0]),
        "white_green_red": stops(white[:, 1] / white[:, 0]),
        "black_level": stops(black @ LUMA), "black_blue_red": stops(black[:, 2] / black[:, 0]),
        "black_green_red": stops(black[:, 1] / black[:, 0]),
        "mean_level": float(np.std([row["mean_stops"] for row in rows], ddof=1)),
    }


def study(sources_directory):
    manifest = json.load(open(os.path.join(sources_directory, "manifest.json")))
    rows = []
    for entry in manifest:
        record = entry.get("study")
        if not record:
            continue
        path = os.path.join(sources_directory, entry["local_path"])
        digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
        if digest != entry["sha256"]:
            raise SystemExit("%s is not the file the manifest records: %s" % (entry["local_path"], digest))
        tones = load(path)
        height, width, _ = tones.shape
        box = None
        if record.get("picture"):
            left, top, right, bottom = record["picture"]
            box = (round(left * width), round(top * height), round(right * width), round(bottom * height))
        paper = None
        if record["card"]:
            box = box or picture_box(tones)
            paper = card_white(tones, box)
        result = measure(tones, box, paper)
        result.update(id=entry["id"], group=record["group"], date=record.get("date") or entry["era_or_date"], scanned=record.get("scanned_or_posted"),
                      kind=record.get("kind"), flags=flags(result))
        rows.append(result)
    return rows


def renders(directory, shown=None):
    """The app's Instant prints of the board's scenes and its packs, measured as the scans are."""
    manifest = json.load(open(os.path.join(directory, "manifest.json")))
    scenes, packs = [], {}
    for entry in manifest["files"]:
        if entry["camera"] != "instant1970s" or entry["kind"] not in ("developed", "pack"):
            continue
        if entry["kind"] == "developed" and shown is not None and entry["scene"] not in shown:
            continue
        tones = load(os.path.join(directory, entry["path"]))
        box = picture_box(tones)
        result = measure(tones, box, card_white(tones, box))
        result.update(scene=entry["scene"], seed=entry.get("seed"))
        if entry["kind"] == "pack":
            packs.setdefault(entry["pack"], []).append(result)
        else:
            scenes.append(result)
    return {"scenes": scenes, "packs": {name: between_prints(rows) for name, rows in packs.items()}}


def median(values):
    return float(np.median(values)) if len(values) else None


def table(header, lines):
    return "\n".join(["| " + " | ".join(header) + " |", "| " + " | ".join("---" for _ in header) + " |"]
                     + ["| " + " | ".join(line) + " |" for line in lines])


def number(value, places=2):
    return "-" if value is None else ("%." + str(places) + "f") % value


def report(rows, sets, rendered):
    out = ["# Instant print study: measurements", "",
           "Written by `Probes/LookReviewBoards/instant_print_study.py`; do not edit by hand.",
           "Tones are sRGB display tones from 0 to 1, and a density is the base-10 logarithm of how much less light a tone returns than the card.",
           "The method and its limits are in `Evidence/NativeApp/instant-study-and-toning-061.md`.", "",
           "## Every print", "",
           "Black and white are the 1st and 99th percentile of the picture's luminance.",
           "Where the scan shows the card, they are also given relative to the card's white.", ""]
    lines = []
    for row in rows:
        lines.append([row["id"], row["date"], row["group"], number(row["black"], 3), number(row["white"], 3),
                      number(row.get("card_black"), 3), number(row.get("card_black_density")),
                      number(row.get("card_white"), 3), number(row.get("card_white_density")),
                      number(row["spread"], 3), number(row["color_strength"], 1), "; ".join(row["flags"]) or "none"])
    out.append(table(["Print", "Date", "Set", "Black", "White", "Black against card", "Its density", "White against card", "Its density",
                      "Spread", "Color strength", "Clipped"], lines))
    out += ["", "## Prints of one occasion, scanned in one session", "",
            "The standard deviation between the prints, in stops of linear light.",
            "Each print is of a different scene, so each number is an upper bound on what the prints themselves differ by.", ""]
    lines = [[name, str(item["prints"]), number(item["white_level"], 3), number(item["white_blue_red"], 3), number(item["white_green_red"], 3),
              number(item["black_level"], 3), number(item["black_blue_red"], 3), number(item["black_green_red"], 3)]
             for name, item in sets.items()]
    out.append(table(["Set", "Prints", "White level", "White, blue against red", "White, green against red", "Black level",
                      "Black, blue against red", "Black, green against red"], lines))
    for label, item in rendered.items():
        out += ["", "## The app: %s" % label, ""]
        lines = [[row["scene"], number(row["card_black"], 3), number(row["card_black_density"]), number(row["card_white"], 3),
                  number(row["card_white_density"]), number(row["spread"], 3), number(row["color_strength"], 1)] for row in item["scenes"]]
        out.append(table(["Scene", "Black against card", "Its density", "White against card", "Its density", "Spread", "Color strength"], lines))
        if item["packs"]:
            out += ["", "Ten prints of one Film:", ""]
            lines = [[name, number(pack["white_level"], 3), number(pack["white_blue_red"], 3), number(pack["white_green_red"], 3),
                      number(pack["black_level"], 3), number(pack["mean_level"], 3)] for name, pack in item["packs"].items()]
            out.append(table(["Pack", "White level", "White, blue against red", "White, green against red", "Black level", "Whole picture's level"], lines))
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--scenes", help="the scenes.json the renders were made from")
    parser.add_argument("--renders", nargs="*", default=[], help="LABEL=DIR for each LookReviewBoards output to measure beside the scans")
    args = parser.parse_args()
    rows = study(args.sources)
    # Prints of one occasion that were scanned or posted together, so one scanner setting covers the set.
    groups = {}
    for row in rows:
        if row["group"] in ("card", "single"):
            continue
        groups.setdefault("%s, scanned %s" % (row["group"], row["scanned"] or "together"), []).append(row)
    sets = {name: between_prints(items) for name, items in sorted(groups.items()) if len(items) > 1}
    # The scenes the Instant's board shows: not the ones kept to another board, nor a scene repeated under another light.
    shown = None
    if args.scenes:
        shown = {scene["id"] for scene in json.load(open(args.scenes))["photos"]
                 if not scene.get("light") and (not scene.get("boards") or "instant" in scene["boards"])}
    rendered = {}
    for item in args.renders:
        label, directory = item.split("=", 1)
        rendered[label] = renders(directory, shown)
    os.makedirs(args.output, exist_ok=True)
    with open(os.path.join(args.output, "measurements.json"), "w") as handle:
        json.dump({"prints": rows, "sets": sets, "app": rendered}, handle, indent=1)
    with open(os.path.join(args.output, "measurements.md"), "w") as handle:
        handle.write(report(rows, sets, rendered))
    usable = [row for row in rows if not row["flags"]]
    carded = [row for row in usable if "card_black" in row]
    print("prints %d, neither end clipped %d, of those with the card %d" % (len(rows), len(usable), len(carded)))
    print("with the card: black %s white %s" % ([round(row["card_black"], 3) for row in carded], [round(row["card_white"], 3) for row in carded]))
    print("spread, median of unclipped scans %.3f; color strength %.1f" % (median([row["spread"] for row in usable]), median([row["color_strength"] for row in usable])))


if __name__ == "__main__":
    main()
