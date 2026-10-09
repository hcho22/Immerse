#!/usr/bin/env python3
"""Builds one look review board per Camera from rendered scenes and licensed reference imagery.

Usage:
  build_boards.py --renders DIR --sources DIR --output DIR [--round N]

--renders is the output of the LookReviewBoards tool (its manifest.json and images).
--sources holds manifest.json describing the test scenes and the reference imagery, with each file's source page,
author and license. Every board directory is self-contained: index.html with its images and clips beside it.
Nothing here ships in the app; the reference imagery is for internal comparison only.
"""

import argparse
import html
import json
import os
import re
import shutil
import subprocess

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LOOK_SOURCE = os.path.join(ROOT, "Packages/RenderCore/Sources/RenderCore/FilmLook.swift")

BOARDS = [
    {
        "id": "disposable",
        "name": "1990s Disposable",
        "cameras": [("disposable1990s", None)],
        "references": ["disposable"],
        "value_blocks": ["disposable"],
        "reference_internal": "Kodak Fun Saver 35mm single-use camera with flash, loaded with 800-speed color film",
        "prd": "Borderless 3:2 picture with no date stamp. Warm, saturated color, heavy film grain, harsh direct flash "
               "with flat shadows, and soft edges. No light leaks, red-eye, or dust and scratches. Fixed exposure: a dim "
               "scene without flash develops dark and grainy, and flash lights only nearby subjects.",
        "judge": [
            "Color: warm and saturated like a 1990s minilab print, never yellowed or faded.",
            "Grain: heavy, as 800-speed film shows it; heavier in the dim, unflashed scene.",
            "Flash: harsh, direct, flat on the subject, with the background falling away.",
            "Lens: soft, slightly darker corners from the plastic lens.",
            "Nothing the format did not make: no light leaks, red-eye, dust or scratches.",
        ],
    },
    {
        "id": "instant",
        "name": "1970s Instant",
        "cameras": [("instant1970s", None)],
        "references": ["instant"],
        "value_blocks": ["instant"],
        "reference_internal": "The original 1970s Polaroid integral print (SX-70 film), as it looked fresh from the camera",
        "prd": "Square picture on a white card that is always part of the print. Brilliant, warm, saturated color and soft "
               "detail, with a slight variation in color and density from print to print. No uneven-chemistry or spread "
               "flaws. The contrast and the size of the variation wait on a study of preserved 1970s prints.",
        "judge": [
            "Color: brilliant, warm and saturated, the print as it was fresh, not as surviving prints have faded.",
            "Detail: soft, without grain.",
            "Variation: each print slightly different in color and density; never a flaw.",
            "Contrast and variation stay provisional until the study of preserved 1970s prints (DEC-04).",
        ],
    },
    {
        "id": "6x6",
        "name": "6×6 Medium Format",
        "cameras": [("mediumFormat6x6", "color"), ("mediumFormat6x6", "blackAndWhite")],
        "references": ["6x6-color", "6x6-bw"],
        "value_blocks": ["mediumFormatColor", "mediumFormatBlackAndWhite"],
        "reference_internal": "Hasselblad 500C with its 80mm lens, loaded with Kodak Portra 400 (color Film Stock) or "
                              "Kodak Tri-X 400 (black-and-white Film Stock)",
        "prd": "Borderless square picture. Color: natural, warm color, flattering skin tones, very fine grain, and gentle "
               "contrast. Black-and-white: high contrast with distinct grain. Focus is optical only, with no synthesized "
               "background blur.",
        "judge": [
            "Color stock: natural, warm color with flattering skin tones; very fine grain; gentle contrast.",
            "Black-and-white stock: high contrast, distinct grain, rich blacks and clean whites.",
            "Sharp to the corners: no added softness, no synthesized background blur.",
        ],
    },
    {
        "id": "super8",
        "name": "1960s Super 8 Home Movie",
        "cameras": [("super8HomeMovie", None)],
        "references": ["super8", "dust"],
        "value_blocks": ["super8"],
        "reference_internal": "Kodak Instamatic M4, the automatic-exposure model, loaded with Kodachrome II and running at "
                              "18 frames per second",
        "prd": "18 frames per second. Strong, rich color and fine grain, with an unsteady frame, brightness flicker, and "
               "dust and hair in the gate, each present from capture or first showing rather than from age.",
        "judge": [
            "Color: strong and rich like fresh Kodachrome, deep blues and reds, never faded or shifted.",
            "Grain: fine.",
            "Motion: an unsteady frame and a slight brightness flicker; dust specks come and go; a hair may sit in the "
            "gate for a whole clip. None of it should spoil the picture.",
        ],
    },
    {
        "id": "16mm",
        "name": "16mm Cinema",
        "cameras": [("cinema16mm", "color"), ("cinema16mm", "blackAndWhite")],
        "references": ["16mm-color", "16mm-bw", "halation"],
        "value_blocks": ["cinemaColor", "cinemaBlackAndWhite"],
        "reference_internal": "Bolex H16 Reflex, loaded with Kodak Vision3 250D (color Film Stock) or Eastman Double-X "
                              "(black-and-white Film Stock)",
        "prd": "24 frames per second. Visible grain, highlight halation (a red glow on color, a neutral glow on "
               "black-and-white), minor jitter and weave, and soft, darkened edges; no brightness flicker and no dust or "
               "hair in the gate. The color Film Stock keeps a fixed daylight balance, so warm indoor light develops "
               "orange. The red glow on color is a deliberate departure from the reference film, whose backing "
               "prevents it.",
        "judge": [
            "Color stock: natural daylight color with visible grain and a red glow around bright highlights.",
            "Black-and-white stock: visible grain and a neutral glow around bright highlights.",
            "Motion: minor jitter and weave only; no flicker, no dust or hair.",
            "Edges: soft and darker toward the corners.",
            "Daylight balance: the tungsten scene develops orange.",
        ],
    },
]

STOCK_NAMES = {None: "", "color": "Color", "blackAndWhite": "Black and white"}
SCENE_LABELS = {"day": "Day", "flash": "Flash", "night": "Night or dim, no flash", "skin": "Skin tones",
                "highlights": "Bright highlights", "video": "Moving scene", "tungsten": "Warm indoor light"}


def value_block(name):
    source = open(LOOK_SOURCE).read()
    match = re.search(r"(    ///[^\n]*\n(?:    ///[^\n]*\n)*)?    static let %s = Treatment\((.*?)\n    \)\n" % re.escape(name),
                      source, re.S)
    if not match:
        raise SystemExit("No values for %s in FilmLook.swift" % name)
    return match.group(0).rstrip()


def run(*args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def copy_image(source, destination, edge=1600):
    """A JPEG copy at most `edge` pixels on its long side."""
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    run("sips", "-s", "format", "jpeg", "-s", "formatOptions", "90", "-Z", str(edge), source, "--out", destination)


def copy_clip(source, destination):
    """An H.264 MP4 a browser plays, 1280 pixels wide, silent."""
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    run("ffmpeg", "-y", "-loglevel", "error", "-i", source, "-an", "-c:v", "libx264", "-crf", "20", "-preset", "slow",
        "-vf", "scale=1280:-2", "-pix_fmt", "yuv420p", "-movflags", "+faststart", destination)


def esc(text):
    return html.escape(str(text or ""), quote=True)


def credit(entry):
    parts = []
    if entry.get("author"):
        parts.append(esc(entry["author"]))
    license_text = esc(entry.get("license", "license unknown"))
    if entry.get("license_url"):
        license_text = '<a href="%s">%s</a>' % (esc(entry["license_url"]), license_text)
    parts.append(license_text)
    if entry.get("file_page_url"):
        parts.append('<a href="%s">source</a>' % esc(entry["file_page_url"]))
    return " · ".join(parts)


STYLE = """
  :root { color-scheme: light; --ink: #19201e; --muted: #555e59; --line: #cbd2ce; --green: #09634e; --paper: #fff;
          --surround: #8a8f8c; }
  * { box-sizing: border-box; letter-spacing: 0; }
  body { margin: 0; font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f4f6f4; color: var(--ink); }
  header, main, footer { width: min(1320px, 100%); margin: auto; padding: 24px; }
  header { border-bottom: 1px solid var(--line); }
  .eyebrow { color: var(--green); font-weight: 650; margin: 0 0 8px; font-size: 14px; }
  h1 { margin: 0; font: 38px/1.15 Georgia, serif; }
  h2 { margin: 0 0 8px; font: 26px/1.25 Georgia, serif; }
  h3 { font-size: 18px; margin: 0 0 8px; }
  p { margin: 8px 0 14px; max-width: 90ch; }
  .muted, small { color: var(--muted); }
  .notice { border-left: 3px solid #a34a27; padding: 4px 0 4px 16px; margin: 18px 0 0; color: #633b2b; max-width: 100ch; }
  .facts { display: grid; grid-template-columns: minmax(150px, 1fr) minmax(0, 5fr); gap: 10px 24px; margin: 18px 0; }
  dt { font-weight: 650; } dd { margin: 0; min-width: 0; overflow-wrap: anywhere; }
  ul.judge { margin: 6px 0 0; padding-left: 20px; max-width: 90ch; }
  section { padding: 28px 0; border-top: 1px solid var(--line); margin-top: 28px; }
  .scene { margin: 0 0 36px; }
  .row { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; align-items: start; }
  .row.two { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .row.four { grid-template-columns: repeat(4, minmax(0, 1fr)); }
  figure { margin: 0; min-width: 0; }
  figure img, figure video { display: block; width: 100%; height: auto; background: var(--surround); }
  figcaption { margin-top: 8px; font-size: 14px; overflow-wrap: anywhere; }
  .tag { display: inline-block; font-size: 12px; font-weight: 650; color: var(--green); border: 1px solid var(--green);
         border-radius: 999px; padding: 1px 8px; margin-right: 6px; }
  .refs { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 18px; }
  pre { background: #fff; border: 1px solid var(--line); padding: 14px; overflow-x: auto; font: 13px/1.5 ui-monospace, monospace; }
  a { color: var(--green); text-underline-offset: 3px; overflow-wrap: anywhere; }
  .decision { background: #fff; border: 1px solid var(--line); border-radius: 8px; padding: 20px; max-width: 760px; }
  .decision label { display: flex; gap: 10px; align-items: center; min-height: 44px; font-weight: 600; }
  .decision input[type=radio] { width: 20px; height: 20px; accent-color: var(--green); }
  .decision textarea { width: 100%; min-height: 120px; font: inherit; padding: 10px; border: 1px solid #87958d; border-radius: 6px; }
  .decision button { min-height: 44px; padding: 8px 18px; font: inherit; font-weight: 650; color: #fff; background: var(--green);
                     border: 0; border-radius: 6px; margin-top: 12px; cursor: pointer; }
  .queued { color: var(--green); font-weight: 650; margin-left: 12px; }
  footer { border-top: 1px solid var(--line); font-size: 14px; }
  @media (max-width: 900px) {
    header, main, footer { padding: 20px 16px; }
    h1 { font-size: 30px; }
    .row, .row.two, .row.four { grid-template-columns: minmax(0, 1fr); }
    .facts { grid-template-columns: minmax(0, 1fr); gap: 4px; }
  }
"""


def build(board, renders, sources, output, round_number):
    directory = os.path.join(output, board["id"])
    if os.path.exists(directory):
        shutil.rmtree(directory)
    os.makedirs(directory)
    files = renders["files"]
    scene_entries = {entry["id"]: entry for entry in sources if entry["role"] == "scene"}
    photo_scenes = [scene for scene in renders["photoScenes"]]
    movie_scenes = renders.get("movieScenes", [])
    body = []

    body.append('<header><p class="eyebrow">Film Journal / Look review board %s / %s</p>' % (round_number, esc(renders["date"])))
    body.append("<h1>%s</h1>" % esc(board["name"]))
    body.append('<p class="muted">Each scene developed by the app\'s own renderer (treatment version %s) beside the '
                'phone capture it started from, the provisional look it replaces, and photographs made with the '
                'Camera\'s Format Reference.</p>' % esc(renders["treatmentVersion"]))
    body.append('<p class="notice">Internal review for DEC-04 and QA-16. The Format Reference names and every reference '
                'image stay internal and never ship in the app. Reference images are public-domain or openly licensed '
                'photographs credited under each one; many are scans of surviving prints or reels, which have aged, so '
                'judge them for the format\'s character as it was new. The test scenes are modern digital photographs, '
                'not captures from an iPhone running the app, so capture behavior (fixed exposure, the real flash) is '
                'not shown.</p>')
    body.append('<dl class="facts"><dt>Format Reference</dt><dd>%s</dd><dt>PRD 2.1 section 6</dt><dd>%s</dd>'
                '<dt>What to judge</dt><dd><ul class="judge">%s</ul></dd></dl></header>'
                % (esc(board["reference_internal"]), esc(board["prd"]),
                   "".join("<li>%s</li>" % esc(item) for item in board["judge"])))
    body.append("<main>")

    def rendered(camera, stock, scene, kind):
        for entry in files:
            if (entry["camera"] == camera and entry.get("filmStock") == stock and entry["scene"] == scene
                    and entry["kind"] == kind):
                return entry
        return None

    def place(entry_path, name, edge=1600):
        destination = os.path.join(directory, name)
        if entry_path.endswith(".mov"):
            copy_clip(os.path.join(renders["root"], entry_path), destination)
        else:
            copy_image(os.path.join(renders["root"], entry_path), destination, edge)
        return name

    # Scenes, one section per Film Stock.
    for camera, stock in board["cameras"]:
        stock_name = STOCK_NAMES[stock]
        heading = board["name"] + (" · %s Film Stock" % stock_name if stock else "")
        body.append('<section><h2>%s</h2>' % esc(heading))
        for scene in photo_scenes:
            source_entry = scene_entries.get(scene["id"], {})
            label = SCENE_LABELS.get(scene.get("category"), scene.get("category", ""))
            source = rendered("source", None, scene["id"], "source")
            developed = rendered(camera, stock, scene["id"], "developed")
            previous = rendered(camera, stock, scene["id"], "previous")
            crop = rendered(camera, stock, scene["id"], "crop")
            slug = "%s-%s" % (stock or "look", scene["id"])
            body.append('<div class="scene"><h3><span class="tag">%s</span>%s</h3>' % (esc(label), esc(source_entry.get("title", scene["id"]))))
            body.append('<div class="row four">')
            body.append('<figure><img src="%s" alt="The scene as the phone captured it"><figcaption><strong>Phone capture</strong> '
                        '<small>%s</small></figcaption></figure>' % (place(source["path"], "scene-%s.jpg" % scene["id"]), credit(source_entry)))
            body.append('<figure><img src="%s" alt="Developed with treatment version 3"><figcaption><strong>Developed, version 3</strong> '
                        '<small>seed %s</small></figcaption></figure>' % (place(developed["path"], "%s.jpg" % slug), developed["seed"]))
            body.append('<figure><img src="%s" alt="Developed with treatment version 2"><figcaption><strong>Before: version 2</strong> '
                        '<small>the provisional shared look</small></figcaption></figure>' % place(previous["path"], "%s-v2.jpg" % slug))
            body.append('<figure><img src="%s" alt="A full-size crop of the developed picture"><figcaption><strong>Full size, center</strong> '
                        '<small>grain and softness as developed</small></figcaption></figure>' % place(crop["path"], "%s-crop.jpg" % slug, 640))
            body.append("</div>")
            prints = [entry for entry in files if entry["camera"] == camera and entry["scene"] == scene["id"] and entry["kind"] == "print"]
            if prints:
                body.append('<p class="muted">Three more prints of the same scene, each with its own slight variation:</p><div class="row">')
                for index, entry in enumerate(prints, 1):
                    body.append('<figure><img src="%s" alt="Another print of the scene"><figcaption>Print %d <small>seed %s</small>'
                                '</figcaption></figure>' % (place(entry["path"], "%s-print-%d.jpg" % (slug, index)), index, entry["seed"]))
                body.append("</div>")
            body.append("</div>")
        for scene in movie_scenes:
            source_entry = scene_entries.get(scene["id"], {})
            clip = rendered(camera, stock, scene["id"], "clip")
            if not clip:
                continue
            label = SCENE_LABELS.get(scene.get("category"), scene.get("category", ""))
            slug = "%s-%s" % (stock or "look", scene["id"])
            body.append('<div class="scene"><h3><span class="tag">%s</span>%s</h3><div class="row two">' % (esc(label), esc(source_entry.get("title", scene["id"]))))
            source_clip = os.path.join(renders["sourcesRoot"], scene["file"])
            source_name = "scene-%s.mp4" % scene["id"]
            if not os.path.exists(os.path.join(directory, source_name)):
                copy_clip(source_clip, os.path.join(directory, source_name))
            body.append('<figure><video src="%s" controls loop muted playsinline preload="metadata"></video><figcaption><strong>Digital source clip</strong> '
                        '<small>%s</small></figcaption></figure>' % (source_name, credit(source_entry)))
            body.append('<figure><video src="%s" controls loop muted playsinline preload="metadata"></video><figcaption><strong>Developed Clip, version 3</strong> '
                        '<small>seed %s, %s frames per second</small></figcaption></figure>' % (place(clip["path"], "%s.mp4" % slug), clip["seed"],
                                                                                         18 if camera == "super8HomeMovie" else 24))
            body.append("</div></div>")
        body.append("</section>")

    # Reference imagery.
    body.append('<section><h2>Format Reference imagery</h2><p class="muted">Photographs and film frames made with the Format '
                'Reference or the closest openly licensed equivalent, as credited. Judge the character, not the subject.</p>')
    for category in board["references"]:
        references = [entry for entry in sources if entry["role"] == "reference" and entry["category"] == category]
        if not references:
            continue
        body.append('<h3>%s</h3><div class="refs">' % esc(category))
        for entry in references:
            name = "ref-%s.jpg" % entry["id"]
            copy_image(entry["local_path"], os.path.join(directory, name))
            notes = " ".join(text for text in [entry.get("description"), entry.get("notes")] if text)
            body.append('<figure><img src="%s" alt="%s" loading="lazy"><figcaption><strong>%s</strong><br><small>%s</small><br>'
                        '<small>%s</small></figcaption></figure>' % (name, esc(entry.get("title")), esc(entry.get("title")),
                                                                   credit(entry), esc(notes)))
        body.append("</div>")
    body.append("</section>")

    # Values and the decision.
    body.append('<section><h2>Values in the app</h2><p class="muted">From <code>FilmLook.swift</code>: the one place each '
                'Camera\'s and Film Stock\'s look is set. Spatial values are fractions of the picture\'s long edge.</p>')
    for block in board["value_blocks"]:
        body.append("<pre><code>%s</code></pre>" % esc(value_block(block)))
    body.append("</section>")
    body.append('<section><h2>Your decision</h2><form class="decision" data-lavish-question="look-%s" onsubmit="queueDecision(event)">'
                '<label><input type="radio" name="decision" value="approve"> Approve these values for the %s</label>'
                '<label><input type="radio" name="decision" value="change"> Request changes</label>'
                '<p><label for="notes" style="display:block">What should change, scene by scene if it helps</label>'
                '<textarea id="notes" name="notes"></textarea></p>'
                '<button type="submit">Queue answer</button><span class="queued" id="queued" hidden>Queued. Press Send to Agent.</span>'
                '</form></section>' % (board["id"], esc(board["name"])))
    body.append("</main>")
    body.append('<footer><p>Rendered by <code>Probes/LookReviewBoards</code> with the production renderers. Sources and licenses: '
                '<code>SOURCES.md</code> beside the boards.</p></footer>')

    script = """
<script>
function queueDecision(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const decision = form.get('decision');
  if (!decision) return;
  const notes = (form.get('notes') || '').trim();
  const text = (decision === 'approve' ? 'Approve the %(name)s look values.' : 'Change the %(name)s look.') + (notes ? ' ' + notes : '');
  if (window.lavish) {
    window.lavish.queuePrompt(text, { tag: 'decision', text: text, element: event.currentTarget, queueKey: 'look-%(id)s',
                                      data: { board: '%(id)s', decision: decision, notes: notes } });
  }
  document.getElementById('queued').hidden = false;
}
</script>""" % {"name": board["name"].replace("'", ""), "id": board["id"]}

    page = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s Look Board</title>
<style>%s</style>
</head>
<body>
%s
%s
</body>
</html>
""" % (esc(board["name"]), STYLE, "\n".join(body), script)
    with open(os.path.join(directory, "index.html"), "w") as handle:
        handle.write(page)
    return os.path.join(directory, "index.html")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--renders", required=True)
    parser.add_argument("--sources", required=True)
    parser.add_argument("--scenes", required=True, help="the scenes.json the renders were made from")
    parser.add_argument("--output", required=True)
    parser.add_argument("--round", default="01")
    parser.add_argument("--date", required=True)
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()
    renders = json.load(open(os.path.join(args.renders, "manifest.json")))
    scenes = json.load(open(args.scenes))
    renders["root"] = os.path.abspath(args.renders)
    renders["sourcesRoot"] = os.path.dirname(os.path.abspath(args.scenes))
    renders["photoScenes"] = scenes["photos"]
    renders["movieScenes"] = scenes["movies"]
    renders["date"] = args.date
    sources = json.load(open(os.path.join(args.sources, "manifest.json")))
    for entry in sources:
        if entry.get("local_path") and not os.path.isabs(entry["local_path"]):
            entry["local_path"] = os.path.join(os.path.abspath(args.sources), entry["local_path"])
    for board in BOARDS:
        if args.only and board["id"] not in args.only:
            continue
        print(build(board, renders, sources, args.output, args.round))


if __name__ == "__main__":
    main()
