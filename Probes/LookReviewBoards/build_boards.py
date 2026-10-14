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
        "approved": "Approved by the captain on 2026-10-10 (\"fresh\"): the look inside ADR 0013.",
        "pairs": {("disposable1990s", None): [("disposable-02", "flash-01"), ("disposable-01", "flash-02"), ("disposable-04", "day-02"), ("disposable-06", "day-01")]},
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
        "approved": "Approved by the captain on 2026-10-10 (\"faded\", then \"approved\"): the faded look, his exception to "
                    "ADR 0013 and to the PRD wording below (ADR 0016). On 2026-10-13, with the study of preserved 1970s prints "
                    "on this board, he chose its contrast: \"B\", which he said means \"contrast only\". The contrast is the "
                    "one the study supports, and the print-to-print variation stays as it was. Shown this board again later that day, he "
                    "wrote \"version 4\", which is what the app has.",
        "pairs": {("instant1970s", None): [("instant-study-23", "flash-01"), ("instant-study-07", "flash-02"), ("instant-01", "day-02"),
                                           ("instant-03", "day-01")]},
        "name": "1970s Instant",
        "notice": "Internal review for DEC-04 and QA-16. The Format Reference's name and every reference image stay internal and "
                  "never ship in the app. Reference images are public-domain or openly licensed photographs credited under each "
                  "one. They are scans of prints about fifty years old, and this Camera's look is the faded one you chose, so "
                  "judge the developed pictures against them as they are; the study below says what in a scan is the film, "
                  "what is age and what is the scanner. The test scenes are modern digital photographs, not captures from an "
                  "iPhone running the app.",
        "cameras": [("instant1970s", None)],
        "references": ["instant", "instant-study"],
        "value_blocks": ["instant", "instantVersion3"],
        "reference_internal": "The original 1970s Polaroid integral print (SX-70 film), as it looked fresh from the camera",
        "prd": "Square picture on a white card that is always part of the print. Brilliant, warm, saturated color and soft "
               "detail, with a slight variation in color and density from print to print. No uneven-chemistry or spread "
               "flaws. The contrast and the size of the variation wait on a study of preserved 1970s prints.",
        "judge": [
            "Color: the faded look approved on 2026-10-10: muted and warm, with blue in the shadows and yellow in the highlights.",
            "Contrast: how deep the blacks go, how bright the whites are, and how far the middle tones spread between them.",
            "Variation: how much one print of a pack differs from the next in brightness and in color; never a flaw.",
            "Detail: soft, with a coarse texture.",
        ],
    },
    {
        "id": "6x6",
        "approved": "Approved by the captain on 2026-10-12 (\"everything looks good\"): the color Film Stock develops with "
                    "the look in his own files, a lab scan with lifted blacks (ADR 0016); the black-and-white Film Stock "
                    "as tuned on this board.",
        "pairs": {("mediumFormat6x6", "color"): [("6x6-color-02", "skin-03"), ("6x6-color-03", "skin-01"), ("6x6-color-04", "day-01")], ("mediumFormat6x6", "blackAndWhite"): [("6x6-bw-06", "day-02"), ("6x6-bw-01", "highlights-03"), ("6x6-bw-05", "night-01")]},
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
        "approved": "Approved by the captain on 2026-10-10 (\"muted with a glow\"): the muted look with a highlight glow, "
                    "his exception to ADR 0013 and to the PRD wording below (ADR 0016).",
        "pairs": {("super8HomeMovie", None): [("super8-ternus1977-still-01", "day-02"), ("super8-phucat-still-01", "day-01"), ("super8-frame-01", "skin-01")]},
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
        "approved": "Approved by the captain on 2026-10-12 (\"lets go with C\", \"black and white looks good\"): the "
                    "color Film Stock develops with the look in his own files and the print density range he chose, "
                    "black at 4 percent with the shadows opened (ADR 0016); the black-and-white Film Stock as it has "
                    "stood since the first round.",
        "pairs": {("cinema16mm", "color"): [("16mm-color-still-02", "day-02"), ("halation-02", "highlights-03"), ("16mm-color-still-01", "tungsten-skin-01")], ("cinema16mm", "blackAndWhite"): [("16mm-bw-still-03", "day-02"), ("16mm-bw-still-02", "highlights-01"), ("16mm-bw-mattebox-still-02", "day-01")]},
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
            "Daylight balance: the warm indoor scene develops orange and the cool-light scenes develop blue.",
        ],
    },
]

STOCK_NAMES = {None: "", "color": "Color", "blackAndWhite": "Black and white"}
REFERENCE_GROUPS = {"disposable": "Single-use camera prints", "instant": "1970s integral prints",
                    "instant-study": "Preserved 1970s prints the study measured", "6x6-color": "6×6 on the color stock",
                    "6x6-bw": "6×6 on the black-and-white stock", "super8": "Super 8 home movies",
                    "16mm-color": "Motion picture color negative", "16mm-bw": "Black-and-white motion picture film",
                    "halation": "Highlight halation", "dust": "Dust and hair in the gate"}
SCENE_LABELS = {"day": "Day", "flash": "Flash", "night": "Night or dim, no flash", "skin": "Skin tones",
                "highlights": "Bright highlights", "video": "Moving scene", "tungsten": "Warm indoor light",
                "shade": "Cool light: open shade or dusk"}


def value_block(name):
    source = open(LOOK_SOURCE).read()
    match = re.search(r"(    ///[^\n]*\n(?:    ///[^\n]*\n)*)?    static let %s = Treatment\((.*?)\n    \)\n" % re.escape(name),
                      source, re.S)
    if not match:
        raise SystemExit("No values for %s in FilmLook.swift" % name)
    return match.group(0).rstrip()


def run(*args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# How large the boards' copies are: for review as served, or (--slim) small enough to keep in the repository.
# The slim copy also leaves out each scene's comparison with treatment version 2.
MEDIA = {"edge": 1400, "quality": 84, "clip_width": 1280, "clip_crf": 20, "previous": True, "toning_edge": 1000}
SLIM_MEDIA = {"edge": 900, "quality": 74, "clip_width": 640, "clip_crf": 28, "previous": False, "toning_edge": 560}


def copy_image(source, destination, edge=None):
    """A JPEG copy at most `edge` pixels on its long side."""
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    run("sips", "-s", "format", "jpeg", "-s", "formatOptions", str(MEDIA["quality"]), "-Z", str(edge or MEDIA["edge"]),
        source, "--out", destination)


def copy_clip(source, destination):
    """An H.264 MP4 a browser plays, silent."""
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    run("ffmpeg", "-y", "-loglevel", "error", "-i", source, "-an", "-c:v", "libx264", "-crf", str(MEDIA["clip_crf"]),
        "-preset", "slow", "-vf", "scale=%d:-2" % MEDIA["clip_width"], "-pix_fmt", "yuv420p", "-movflags", "+faststart",
        destination)


def esc(text):
    return html.escape(str(text or ""), quote=True)


def paragraphs(text):
    """A note as HTML: escaped, with a new paragraph wherever the note has a blank line."""
    return "".join("<p>%s</p>" % esc(part.strip()) for part in text.split("\n\n") if part.strip())


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


def table(header, rows):
    return "<table><thead><tr>%s</tr></thead><tbody>%s</tbody></table>" % (
        "".join("<th>%s</th>" % esc(cell) for cell in header),
        "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % esc(cell) for cell in row) for row in rows))


def decision_form(board_id, board_name, questions):
    """The captain's answer: one choice for each question and a note, queued for the agent through Lavish."""
    parts = ['<section><h2>Your decision</h2><form class="decision" data-lavish-question="look-%s" data-board="%s" data-name="%s" '
             'onsubmit="queueDecision(event)">' % (esc(board_id), esc(board_id), esc(board_name))]
    for question in questions:
        if question.get("title"):
            parts.append("<h3>%s</h3>" % esc(question["title"]))
        if question.get("help"):
            parts.append('<p class="muted">%s</p>' % esc(question["help"]))
        for value, label in question["options"]:
            parts.append('<label><input type="radio" name="%s" value="%s" data-question="%s"> %s</label>'
                         % (esc(question["id"]), esc(value), esc(question.get("title") or board_name), esc(label)))
    parts.append('<p><label for="notes" style="display:block">Anything to change, scene by scene if it helps</label>'
                 '<textarea id="notes" name="notes"></textarea></p>'
                 '<button type="submit">Queue answer</button><span class="queued" id="queued" hidden>Queued. Press Send to Agent.</span>'
                 '</form></section>')
    return "".join(parts)


DECISION_SCRIPT = """
<script>
function queueDecision(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const chosen = Array.from(form.querySelectorAll('input[type=radio]:checked'));
  const notes = (new FormData(form).get('notes') || '').trim();
  if (!chosen.length && !notes) return;
  const answers = chosen.map(input => input.dataset.question + ': ' + input.parentElement.textContent.trim());
  const text = form.dataset.name + '. ' + answers.join(' ') + (notes ? ' Notes: ' + notes : '');
  const data = { board: form.dataset.board, notes: notes };
  chosen.forEach(input => { data[input.name] = input.value; });
  if (window.lavish) {
    window.lavish.queuePrompt(text, { tag: 'decision', text: text, element: form, queueKey: 'look-' + form.dataset.board, data: data });
  }
  document.getElementById('queued').hidden = false;
}
</script>"""


STYLE = """
  :root { color-scheme: light; --ink: #19201e; --muted: #555e59; --line: #cbd2ce; --green: #09634e; --paper: #fff;
          --surround: #8a8f8c; }
  * { box-sizing: border-box; letter-spacing: 0; }
  body { margin: 0; font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f4f6f4; color: var(--ink); }
  header, main, footer { width: min(1320px, 100%); margin: auto; padding: 24px; }
  header { padding-bottom: 0; }
  .eyebrow { color: var(--green); font-weight: 650; margin: 0 0 8px; font-size: 14px; }
  h1 { margin: 0; font: 38px/1.15 Georgia, serif; }
  h2 { margin: 0 0 8px; font: 26px/1.25 Georgia, serif; }
  h3 { font: 21px/1.3 Georgia, serif; margin: 28px 0 8px; }
  h4 { font-size: 17px; margin: 0 0 8px; }
  p { margin: 8px 0 14px; max-width: 90ch; }
  .muted, small { color: var(--muted); }
  .notice { border-left: 3px solid #a34a27; padding: 4px 0 4px 16px; margin: 18px 0 0; color: #633b2b; max-width: 100ch; }
  .facts { display: grid; grid-template-columns: minmax(150px, 1fr) minmax(0, 5fr); gap: 10px 24px; margin: 18px 0; }
  dt { font-weight: 650; } dd { margin: 0; min-width: 0; overflow-wrap: anywhere; }
  dd p { margin: 0 0 10px; } dd p:last-child { margin-bottom: 0; }
  ul.judge { margin: 6px 0 0; padding-left: 20px; max-width: 90ch; }
  section { padding: 28px 0; border-top: 1px solid var(--line); margin-top: 28px; }
  .scene { margin: 0 0 36px; }
  .row { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; align-items: start; }
  .row.two { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .row.four { grid-template-columns: repeat(4, minmax(0, 1fr)); }
  .pack { background: var(--surround); border-radius: 6px; padding: 14px; margin: 0 0 30px; }
  .row.five { grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 14px; }
  .row.five figure img { height: auto; background: none; }
  .pack figcaption { color: #fff; margin-top: 6px; font-size: 13px; }
  .strip { display: grid; grid-template-columns: repeat(var(--count), minmax(0, 1fr)); gap: 8px; align-items: start; margin: 0 0 14px; }
  .strip figure img { height: auto; aspect-ratio: 1; object-fit: cover; }
  .strip figcaption { font-size: 13px; }
  .scroll { overflow-x: auto; }
  .scroll .strip { min-width: 900px; }
  table { border-collapse: collapse; margin: 12px 0 18px; font-size: 15px; }
  th, td { border: 1px solid var(--line); padding: 6px 10px; text-align: left; vertical-align: top; }
  th { background: #e9eeeb; }
  .decision h3 { margin: 18px 0 4px; font: 650 17px/1.3 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
  .decision h3:first-child { margin-top: 0; }
  figure { margin: 0; min-width: 0; }
  figure img, figure video { display: block; width: 100%; height: 400px; object-fit: contain; background: #262927; }
  .pair figure img, .pair figure video { height: 520px; }
  .row.four figure img, .row.four figure video { height: 320px; }
  details { margin-top: 10px; }
  summary { cursor: pointer; color: var(--green); font-weight: 600; min-height: 32px; }
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
    .row.five { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .row.five figure img { height: auto; }
    figure img, figure video, .pair figure img, .pair figure video { height: auto; max-height: 70vh; }
    .facts { grid-template-columns: minmax(0, 1fr); gap: 4px; }
  }
"""


def build(board, renders, sources, output, round_number):
    directory = os.path.join(output, board["id"])
    if os.path.exists(directory):
        shutil.rmtree(directory)
    os.makedirs(directory)
    files = renders["files"]
    credits = {entry["id"]: entry for entry in sources if entry["role"] == "scene"}
    scene_entries = {scene["id"]: credits.get(scene.get("credit"), {})
                     for scene in renders["photoScenes"] + renders.get("movieScenes", [])}
    photo_scenes = [scene for scene in renders["photoScenes"]]
    movie_scenes = renders.get("movieScenes", [])
    body = []
    # The treatment version the renders were made with, as its number: "film-look-4" is version 4.
    version = renders["treatmentVersion"].rsplit("-", 1)[-1]
    # Further candidate looks for this board, rendered from other values, shown beside the first.
    alternates = renders.get("alternates", []) if board["id"] in renders.get("alternateBoards", []) else []
    # Whole Instant packs, ten prints of one Film: (label, note, renders) for each variation shown.
    packs = renders.get("packs", []) if board["id"] == "instant" else []

    body.append('<header><p class="eyebrow">Film Journal / Look review board %s / %s</p>' % (round_number, esc(renders["date"])))
    body.append("<h1>%s</h1>" % esc(board["name"]))
    body.append('<p class="muted">Each scene developed by the app\'s own renderer (treatment version %s) beside the '
                'phone capture it started from%s and photographs made with the Camera\'s Format Reference.</p>'
                % (esc(renders["treatmentVersion"]), ", the provisional look it replaces," if MEDIA["previous"] else ""))
    if renders.get("approved") and board.get("approved"):
        body.append('<p class="notice"><strong>%s</strong></p>' % esc(board["approved"]))
    body.append('<p class="notice">%s</p>' % esc(board.get("notice") or
                'Internal review for DEC-04 and QA-16. The Format Reference names and every reference '
                'image stay internal and never ship in the app. Reference images are public-domain or openly licensed '
                'photographs credited under each one; many are scans of surviving prints or reels, which have aged, so '
                'judge them for the format\'s character as it was new. The test scenes are modern digital photographs, '
                'not captures from an iPhone running the app, so capture behavior (fixed exposure, the real flash) is '
                'not shown.'))
    body.append('<dl class="facts"><dt>Format Reference</dt><dd>%s</dd><dt>PRD 2.1 section 6</dt><dd>%s</dd>'
                '<dt>What to judge</dt><dd><ul class="judge">%s</ul></dd></dl></header>'
                % (esc(board["reference_internal"]), esc(board["prd"]),
                   "".join("<li>%s</li>" % esc(item) for item in board["judge"])))
    body.append("<main>")
    findings = renders.get("findings", {}).get(board["id"])
    if findings:
        body.append('<section><h2>%s</h2>%s' % (esc(findings["title"]), paragraphs(findings["text"])))
        for item in findings.get("tables", []):
            body.append("<h3>%s</h3>%s" % (esc(item["title"]), table(item["header"], item["rows"])))
            if item.get("note"):
                body.append('<p class="muted">%s</p>' % esc(item["note"]))
        body.append("</section>")
    if alternates:
        body.append('<section><h2>%s</h2><dl class="facts"><dt>%s</dt><dd>%s</dd>%s</dl></section>'
                    % (esc(renders["looksHeading"]), esc(renders["primaryLabel"]), paragraphs(renders["primaryNote"]),
                       "".join("<dt>%s</dt><dd>%s</dd>" % (esc(alternate["label"]), paragraphs(alternate["note"])) for alternate in alternates)))

    def rendered(camera, stock, scene, kind):
        for entry in files:
            if (entry["camera"] == camera and entry.get("filmStock") == stock and entry["scene"] == scene
                    and entry["kind"] == kind):
                return entry
        return None

    def place(entry_path, name, edge=None, root=None):
        destination = os.path.join(directory, name)
        if entry_path.endswith(".mov"):
            copy_clip(os.path.join(root or renders["root"], entry_path), destination)
        else:
            copy_image(os.path.join(root or renders["root"], entry_path), destination, edge)
        return name

    def alternate_rendered(alternate, camera, stock, scene, kind):
        for entry in alternate["files"]:
            if (entry["camera"] == camera and entry.get("filmStock") == stock and entry["scene"] == scene
                    and entry["kind"] == kind):
                return entry
        return None

    def columns(count):
        """The row class for that many figures side by side."""
        return {2: "two", 3: "", 4: "four"}[count]

    # Scenes, one section per Film Stock.
    for camera, stock in board["cameras"]:
        stock_name = STOCK_NAMES[stock]
        # The further candidates may cover only some of the board's Film Stocks.
        stocks = renders.get("alternateFilmStocks")
        candidates = alternates if not stocks or stock in stocks else []

        def looks(scene_id, kind, slug, extension, edge=None, camera=camera, stock=stock, candidates=candidates):
            """The look in the app and each further candidate's, as (label, placed file) pairs."""
            first = rendered(camera, stock, scene_id, kind)
            placed = [(renders["primaryLabel"], place(first["path"], "%s.%s" % (slug, extension), edge))]
            for alternate in candidates:
                other = alternate_rendered(alternate, camera, stock, scene_id, kind)
                placed.append((alternate["label"], place(other["path"], "%s-%s.%s" % (slug, alternate["suffix"], extension), edge,
                                                         root=alternate["root"])))
            return placed
        heading = "%s Film Stock" % stock_name if stock else "Scenes"
        body.append('<section><h2>%s</h2>' % esc(heading))
        # Pictures the captain supplied as the target for a stock. They are not openly licensed, so the board links to
        # them where they are published and no copy is kept with the board.
        remote = [entry for entry in renders.get("remoteReferences", [])
                  if entry["board"] == board["id"] and entry["camera"] == camera and entry.get("filmStock") == stock]
        if remote:
            body.append('<h3>Side by side with the captain\'s reference pictures</h3><p class="muted">Supplied by the captain on %s '
                        'as the target for this Film Stock. They are from a public forum post and are not openly licensed, so they '
                        'are shown from where they are published and are not copied into the repository.</p>'
                        % esc(remote[0].get("date") or renders["remoteDate"]))
            for entry in remote:
                developed = rendered(camera, stock, entry["scene"], "developed")
                slug = "%s-%s" % (stock or "look", entry["scene"])
                body.append('<div class="row %s pair scene"><figure><img src="%s" alt="%s" referrerpolicy="no-referrer"><figcaption>'
                            '<strong>%s</strong><br><small><a href="%s">where it is published</a> · not openly licensed, linked only</small>'
                            '</figcaption></figure>' % (columns(2 + len(candidates)), esc(entry["url"]), esc(entry["title"]),
                                                        esc(entry["title"]), esc(entry["url"])))
                scene_title = esc(scene_entries.get(entry["scene"], {}).get("title", entry["scene"]))
                if candidates:
                    for label, name in looks(entry["scene"], "developed", slug, "jpg"):
                        body.append('<figure><img src="%s" alt="%s"><figcaption><strong>%s:</strong> %s</figcaption></figure>'
                                    % (name, esc(label), esc(label), scene_title))
                    body.append("</div>")
                else:
                    body.append('<figure><img src="%s" alt="Developed with treatment version %s"><figcaption><strong>Developed by the app, '
                                'version %s:</strong> %s</figcaption></figure></div>'
                                % (place(developed["path"], "%s.jpg" % slug), version, version, scene_title))
        pairs = board.get("pairs", {}).get((camera, stock), [])
        if pairs:
            references_by_id = {entry["id"]: entry for entry in sources if entry["role"] == "reference"}
            body.append('<h3>Side by side with the Format Reference</h3><p class="muted">A photograph made with the reference '
                        'format beside a scene of the same kind developed by the app. The subjects differ; judge color, '
                        'contrast, grain and the format\'s imperfections.</p>')
            for reference_id, scene_id in pairs:
                reference = references_by_id[reference_id]
                developed = rendered(camera, stock, scene_id, "developed")
                slug = "%s-%s" % (stock or "look", scene_id)
                reference_name = "ref-%s.jpg" % reference_id
                copy_image(reference["local_path"], os.path.join(directory, reference_name))
                # A study print's date, unless its title already gives it.
                dated = (" (%s)" % esc(reference["era_or_date"])
                         if reference.get("study") and reference["era_or_date"] not in (reference.get("title") or "") else "")
                body.append('<div class="row %s pair scene"><figure><img src="%s" alt="%s"><figcaption><strong>Reference:</strong> %s%s<br>'
                            '<small>%s</small></figcaption></figure>' % (columns(2 + len(candidates)), reference_name,
                                                                       esc(reference.get("title")), esc(reference.get("title")), dated,
                                                                       credit(reference)))
                scene_title = esc(scene_entries.get(scene_id, {}).get("title", scene_id))
                if candidates:
                    for label, name in looks(scene_id, "developed", slug, "jpg"):
                        body.append('<figure><img src="%s" alt="%s"><figcaption><strong>%s:</strong> %s</figcaption></figure>'
                                    % (name, esc(label), esc(label), scene_title))
                    body.append("</div>")
                else:
                    body.append('<figure><img src="%s" alt="Developed with treatment version %s"><figcaption><strong>Developed by the app, '
                                'version %s:</strong> %s</figcaption></figure></div>'
                                % (place(developed["path"], "%s.jpg" % slug), version, version, scene_title))
        body.append('<h3>Every scene</h3>')
        for scene in photo_scenes:
            # A scene may be kept to the boards it was added for.
            if scene.get("boards") and board["id"] not in scene["boards"]:
                continue
            # A recorded light matters only to the 16mm's color stock, which keeps a fixed daylight balance.
            if scene.get("light") and (camera, stock) != ("cinema16mm", "color"):
                continue
            source_entry = scene_entries.get(scene["id"], {})
            label = SCENE_LABELS.get(scene.get("category"), scene.get("category", ""))
            source = rendered("source", None, scene["id"], "source")
            developed = rendered(camera, stock, scene["id"], "developed")
            previous = rendered(camera, stock, scene["id"], "previous")
            crop = rendered(camera, stock, scene["id"], "crop")
            slug = "%s-%s" % (stock or "look", scene["id"])
            title = source_entry.get("title", scene["id"])
            if scene.get("light"):
                kelvin = scene["light"].split(",")[0]
                title += (" (marked as recorded under %s K light, as %s gives)"
                          % (kelvin, "warm household bulbs" if float(kelvin) < 5500 else "open shade or dusk"))
            body.append('<div class="scene"><h4><span class="tag">%s</span>%s</h4>' % (esc(label), esc(title)))
            body.append('<div class="row %s">' % columns(2 + len(candidates) if candidates else 3))
            body.append('<figure><img src="%s" alt="The scene as the phone captured it"><figcaption><strong>Phone capture</strong> '
                        '<small>%s</small></figcaption></figure>' % (place(source["path"], "scene-%s.jpg" % scene["id"]), credit(source_entry)))
            if candidates:
                for label, name in looks(scene["id"], "developed", slug, "jpg"):
                    body.append('<figure><img src="%s" alt="%s"><figcaption><strong>%s</strong></figcaption></figure>'
                                % (name, esc(label), esc(label)))
                body.append("</div>")
                body.append('<details><summary>Full size, center: grain and softness as developed</summary><div class="row %s">'
                            % columns(1 + len(candidates)))
                for label, name in looks(scene["id"], "crop", slug + "-crop", "jpg", 640):
                    body.append('<figure><img src="%s" alt="%s at full size" loading="lazy"><figcaption>%s</figcaption></figure>'
                                % (name, esc(label), esc(label)))
                body.append("</div></details>")
            else:
                body.append('<figure><img src="%s" alt="Developed with treatment version %s"><figcaption><strong>Developed, version %s</strong> '
                            '<small>seed %s</small></figcaption></figure>' % (place(developed["path"], "%s.jpg" % slug), version, version, developed["seed"]))
                body.append('<figure><img src="%s" alt="A full-size crop of the developed picture"><figcaption><strong>Full size, center</strong> '
                            '<small>grain and softness as developed</small></figcaption></figure>' % place(crop["path"], "%s-crop.jpg" % slug, 640))
                body.append("</div>")
            if MEDIA["previous"]:
                body.append('<details><summary>Compare with version 2, the provisional shared look it replaces</summary><div class="row">'
                            '<figure><img src="%s" alt="Developed with treatment version 2" loading="lazy"><figcaption>Version 2</figcaption></figure>'
                            '</div></details>' % place(previous["path"], "%s-v2.jpg" % slug))
            prints = [entry for entry in files if entry["camera"] == camera and entry["scene"] == scene["id"] and entry["kind"] == "print"]
            if prints and not packs:
                body.append('<p class="muted">Three more prints of the same scene%s, each with its own slight variation:</p><div class="row">'
                            % (" (%s)" % renders["primaryLabel"] if candidates else ""))
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
            body.append('<div class="scene"><h4><span class="tag">%s</span>%s</h4><div class="row %s">'
                        % (esc(label), esc(source_entry.get("title", scene["id"])), columns(2 + len(candidates))))
            source_clip = os.path.join(renders["sourcesRoot"], scene["file"])
            source_name = "scene-%s.mp4" % scene["id"]
            if not os.path.exists(os.path.join(directory, source_name)):
                copy_clip(source_clip, os.path.join(directory, source_name))
            rate = 18 if camera == "super8HomeMovie" else 24
            body.append('<figure><video src="%s" controls loop muted playsinline preload="metadata"></video><figcaption><strong>Digital source clip</strong> '
                        '<small>%s</small></figcaption></figure>' % (source_name, credit(source_entry)))
            if candidates:
                for label, name in looks(scene["id"], "clip", slug, "mp4"):
                    body.append('<figure><video src="%s" controls loop muted playsinline preload="metadata"></video><figcaption><strong>%s</strong> '
                                '<small>Developed Clip, %s frames per second</small></figcaption></figure>' % (name, esc(label), rate))
            else:
                body.append('<figure><video src="%s" controls loop muted playsinline preload="metadata"></video><figcaption><strong>Developed Clip, version %s</strong> '
                            '<small>seed %s, %s frames per second</small></figcaption></figure>' % (place(clip["path"], "%s.mp4" % slug), version, clip["seed"], rate))
            body.append("</div></div>")
        body.append("</section>")

    if packs:
        body.append('<section><h2>A pack of ten prints</h2><p class="muted">Each row is one Film: its ten exposures, each developed '
                    'with the seed Development gives that exposure, so each print\'s variation is the one it would get in the app and '
                    'never changes afterwards. The rows of a pair use the same ten seeds, so a print differs between them only '
                    'in how far it moves, not in which way.</p>')
        for pack in renders["packDefinitions"]:
            same = len(set(pack["scenes"])) == 1
            body.append("<h3>%s</h3>" % esc("Ten prints of one scene, where nothing differs but the print" if same
                                           else "Ten different pictures, as a pack is used"))
            for item in packs:
                chosen = [entry for entry in item["files"] if entry["kind"] == "pack" and entry["pack"] == pack["id"]]
                chosen.sort(key=lambda entry: entry["exposure"])
                body.append('<h4>%s</h4><p class="muted">%s</p><div class="pack"><div class="row five">' % (esc(item["label"]), esc(item["note"])))
                for entry in chosen:
                    name = "pack-%s-%s-%d.jpg" % (pack["id"], item["suffix"], entry["exposure"])
                    copy_image(os.path.join(item["root"], entry["path"]), os.path.join(directory, name), 700)
                    body.append('<figure><img src="%s" alt="Print %d of the pack" loading="lazy"><figcaption>Print %d</figcaption></figure>'
                                % (name, entry["exposure"], entry["exposure"]))
                body.append("</div></div>")
        body.append("</section>")

    # Reference imagery.
    body.append('<section><h2>All Format Reference imagery</h2><p class="muted">Photographs and film frames made with the Format '
                'Reference or the closest openly licensed equivalent, as credited. Judge the character, not the subject.</p>')
    for category in board["references"]:
        references = [entry for entry in sources if entry["role"] == "reference" and entry["category"] == category]
        if not references:
            continue
        body.append('<h3>%s</h3><div class="refs">' % esc(REFERENCE_GROUPS.get(category, category)))
        for entry in references:
            notes = " ".join(text for text in [entry.get("description"), entry.get("notes")] if text)
            if entry["local_path"].endswith(".mov"):
                name = "ref-%s.mp4" % entry["id"]
                copy_clip(entry["local_path"], os.path.join(directory, name))
                media = '<video src="%s" controls loop muted playsinline preload="metadata"></video>' % name
            else:
                name = "ref-%s.jpg" % entry["id"]
                copy_image(entry["local_path"], os.path.join(directory, name))
                media = '<img src="%s" alt="%s" loading="lazy">' % (name, esc(entry.get("title")))
            dated = "%s · " % esc(entry["era_or_date"]) if entry.get("study") else ""
            body.append('<figure>%s<figcaption><strong>%s</strong><br><small>%s%s</small><br>'
                        '<small>%s</small></figcaption></figure>' % (media, esc(entry.get("title")), dated, credit(entry), esc(notes)))
        body.append("</div>")
    body.append("</section>")

    # Values and the decision.
    body.append('<section><h2>Values in the app</h2><p class="muted">From <code>FilmLook.swift</code>: the one place each '
                'Camera\'s and Film Stock\'s look is set. Spatial values are fractions of the picture\'s long edge.</p>')
    if alternates:
        body.append("<h3>%s</h3>" % esc(renders["primaryLabel"]))
    for block in board["value_blocks"]:
        body.append("<pre><code>%s</code></pre>" % esc(value_block(block)))
    for alternate in alternates:
        body.append("<h3>%s</h3><pre><code>%s</code></pre>" % (esc(alternate["label"]), esc(alternate["values"])))
    for label, values in renders.get("furtherValues", {}).get(board["id"], []):
        body.append("<h3>%s</h3><pre><code>%s</code></pre>" % (esc(label), esc(values)))
    body.append("</section>")
    # A look shown for comparison only is not one of the choices.
    choosable = [alternate for alternate in alternates if not alternate["comparisonOnly"]]
    questions = renders.get("questions", {}).get(board["id"])
    if questions:
        body.append(decision_form(board["id"], board["name"], questions))
    else:
        if choosable:
            options = [("approve-a", "Approve %s" % renders["primaryLabel"])]
            options += [("approve-%s" % alternate["suffix"], "Approve %s" % alternate["label"]) for alternate in choosable]
        else:
            options = [("approve", "Approve these values for the %s" % board["name"])]
        body.append(decision_form(board["id"], board["name"], [{"id": "decision", "title": "", "options": options + [("change", "Request changes")]}]))
    body.append("</main>")
    body.append('<footer><p>Rendered by <code>Probes/LookReviewBoards</code> with the production renderers. Every scene and '
                'reference, with its source page, author and license: <a href="../SOURCES.md">SOURCES.md</a>.</p></footer>')

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
""" % (esc(board["name"]), STYLE, "\n".join(body), DECISION_SCRIPT)
    with open(os.path.join(directory, "index.html"), "w") as handle:
        handle.write(page)
    return os.path.join(directory, "index.html")


TONING_SOURCE = os.path.join(ROOT, "Packages/RenderCore/Sources/RenderCore/ToningLook.swift")
TONERS = [("sepia", "Sepia"), ("selenium", "Selenium")]


def build_toning(renders, sources, output, round_number):
    """The comparison board for the Darkroom's chemical toners: each toner at each strength on black-and-white 6×6
    prints, made by the production print renderer.
    """
    directory = os.path.join(output, "toning")
    if os.path.exists(directory):
        shutil.rmtree(directory)
    os.makedirs(directory)
    camera, stock = "mediumFormat6x6", "blackAndWhite"
    credits = {entry["id"]: entry for entry in sources if entry["role"] == "scene"}
    scenes = {scene["id"]: scene for scene in renders["photoScenes"]}
    chosen = renders["toning"]
    stronger = renders.get("strongerToning", {})
    notes = renders.get("findings", {}).get("toning", {})

    def find(files, scene, kind, chemistry=None, amount=None):
        for entry in files:
            if (entry["camera"] == camera and entry.get("filmStock") == stock and entry["scene"] == scene and entry["kind"] == kind
                    and entry.get("chemistry") == chemistry and (amount is None or abs(entry["amount"] - amount) < 1e-6)):
                return entry
        raise SystemExit("No %s %s %s %s in the renders" % (scene, kind, chemistry, amount))

    def figure(root, entry, name, caption):
        copy_image(os.path.join(root, entry["path"]), os.path.join(directory, name), MEDIA["toning_edge"])
        return ('<figure><a href="%s"><img src="%s" alt="%s" loading="lazy"></a><figcaption>%s</figcaption></figure>'
                % (name, name, esc(caption), esc(caption)))

    body = []
    body.append('<header><p class="eyebrow">Film Journal / Toning comparison board %s / %s</p>' % (round_number, esc(renders["date"])))
    body.append("<h1>Chemical toning</h1>")
    body.append('<p class="muted">Black-and-white 6×6 Medium Format prints, toned in the Darkroom by the app\'s own print renderer, '
                'each toner at each strength.</p>')
    if renders.get("approved") and renders.get("toningApproved"):
        body.append('<p class="notice"><strong>%s</strong></p>' % esc(renders["toningApproved"]))
    body.append('<p class="notice">Internal review for DEC-11. Chemical toning is offered only on the prints of a black-and-white '
                '6×6 Medium Format Film. The test scenes are modern digital photographs developed as that Film, not captures '
                'from an iPhone running the app, and no toned darkroom print is shown beside them: none was found under an '
                'open license with its toner on record.</p>')
    # The copy kept after his answer records the question in the past tense.
    decided = renders.get("approved") and renders.get("toningApproved")
    body.append('<dl class="facts"><dt>%s</dt><dd>%s</dd><dt>%s</dt><dd><ul class="judge">%s</ul></dd>'
                '<dt>%s</dt><dd><ul class="judge">%s</ul></dd></dl></header>'
                % ("The control" if decided else "The control today", esc(notes.get("control", "")),
                   "What was asked" if decided else "What you are choosing",
                   "".join("<li>%s</li>" % esc(item) for item in notes.get("choosing", [])),
                   "What was judged" if decided else "What to judge",
                   "".join("<li>%s</li>" % esc(item) for item in notes.get("judge", []))))
    body.append("<main>")
    if notes.get("text"):
        body.append('<section><h2>%s</h2>%s' % (esc(notes["title"]), paragraphs(notes["text"])))
        for item in notes.get("tables", []):
            body.append("<h3>%s</h3>%s" % (esc(item["title"]), table(item["header"], item["rows"])))
            if item.get("note"):
                body.append('<p class="muted">%s</p>' % esc(item["note"]))
        body.append("</section>")

    body.append('<section><h2>Every scene</h2><p class="muted">Open any print at its full board size by selecting it. '
                'A strength is a share of today\'s top, so 1.00 is the strongest the slider gives today.</p>')
    for scene_id in chosen["scenes"]:
        scene = scenes[scene_id]
        credit_entry = credits.get(scene.get("credit"), {})
        label = SCENE_LABELS.get(scene.get("category"), scene.get("category", ""))
        body.append('<div class="scene"><h3><span class="tag">%s</span>%s <small class="muted">%s</small></h3>'
                    % (esc(label), esc(credit_entry.get("title", scene_id)), credit(credit_entry)))
        untoned = find(renders["files"], scene_id, "developed")
        for chemistry, name in TONERS:
            body.append('<h4>%s</h4><div class="scroll"><div class="strip" style="--count: %d">' % (esc(name), len(chosen["amounts"]) + 1))
            body.append(figure(renders["root"], untoned, "%s-untoned.jpg" % scene_id, "Untoned"))
            for amount in chosen["amounts"]:
                entry = find(renders["files"], scene_id, "toned", chemistry, amount)
                caption = "%.2f%s" % (amount, ", today's top" if amount == max(chosen["amounts"]) else "")
                body.append(figure(renders["root"], entry, "%s-%s-%03d.jpg" % (scene_id, chemistry, round(amount * 100)), caption))
            body.append("</div></div>")
            further = stronger.get(chemistry)
            if further:
                # A toner whose whole range is faint is also shown past today's top, from renders made with a higher top.
                steps = [amount for amount in chosen["amounts"] if amount * further["top"] > 1 + 1e-6]
                body.append('<h4>%s, stronger than today\'s top</h4><div class="scroll"><div class="strip" style="--count: %d">'
                            % (esc(name), len(chosen["amounts"]) + 1))
                top = find(renders["files"], scene_id, "toned", chemistry, max(chosen["amounts"]))
                body.append(figure(renders["root"], top, "%s-%s-100.jpg" % (scene_id, chemistry), "1.00, today's top"))
                for amount in steps:
                    entry = find(further["files"], scene_id, "toned", chemistry, amount)
                    strength = amount * further["top"]
                    body.append(figure(further["root"], entry, "%s-%s-%03d.jpg" % (scene_id, chemistry, round(strength * 100)),
                                       "%.2f, %g times today's top" % (strength, strength)))
                body.append("</div></div>")
        body.append("</div>")
    body.append("</section>")

    body.append('<section><h2>Values in the app</h2><p class="muted">From <code>ToningLook.swift</code>: the one place the toners are '
                'set. Your choices become each slider\'s range.</p><pre><code>%s</code></pre></section>'
                % esc(open(TONING_SOURCE).read().split("import Foundation\n", 1)[1].split("    /// The print toned as the recipe asks.", 1)[0].strip()))
    body.append(decision_form("toning", "Chemical toning", renders.get("questions", {}).get("toning", [
        {"id": "decision", "title": "", "options": [("approve", "Approve these values"), ("change", "Request changes")]}])))
    body.append("</main>")
    body.append('<footer><p>Rendered by <code>Probes/LookReviewBoards</code> with the production print renderer. Every scene, with its '
                'source page, author and license: <a href="../SOURCES.md">SOURCES.md</a>.</p></footer>')
    page = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Chemical Toning Board</title>
<style>%s</style>
</head>
<body>
%s
%s
</body>
</html>
""" % (STYLE, "\n".join(body), DECISION_SCRIPT)
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
    parser.add_argument("--alternate", nargs="*", default=[],
                        help="renders of up to two further candidate looks, shown beside the first on the --alternate-boards")
    parser.add_argument("--alternate-boards", nargs="*", default=[])
    parser.add_argument("--alternate-film-stocks", nargs="*", default=[],
                        help="the Film Stocks the further candidates cover (color, blackAndWhite); all of the board's when omitted")
    parser.add_argument("--comparison-only", nargs="*", type=int, default=[],
                        help="which --alternate looks (1 or 2) are shown for comparison only and cannot be chosen")
    parser.add_argument("--looks-heading", default="The candidates", help="the heading over the looks' notes")
    parser.add_argument("--primary-label", default="A")
    parser.add_argument("--primary-note", default="")
    parser.add_argument("--alternate-label", nargs="*", default=[], help="one label for each --alternate")
    parser.add_argument("--alternate-note", nargs="*", default=[], help="one note for each --alternate")
    parser.add_argument("--alternate-values", nargs="*", default=[],
                        help="for each --alternate, a file holding its values as they would read in FilmLook.swift")
    parser.add_argument("--remote-references", help="JSON list of pictures to link, not copy: board, camera, filmStock, scene, title, url")
    parser.add_argument("--remote-date", default="", help="the day the remote references were supplied")
    parser.add_argument("--packs", nargs="*", default=[],
                        help="LABEL=DIR for each set of renders whose Instant packs the Instant's board shows, in order; the "
                             "primary renders' own packs when omitted")
    parser.add_argument("--pack-notes", nargs="*", default=[], help="one note for each --packs")
    parser.add_argument("--findings", help="JSON by board: what a study found (title, text, tables), shown before the scenes; "
                                           "for the toning board also control, choosing and judge")
    parser.add_argument("--questions", help="JSON by board: the questions of the decision form, each with id, title and options")
    parser.add_argument("--further-values", help="JSON by board: [label, values] pairs printed after the values in the app")
    parser.add_argument("--stronger-toning", nargs="*", default=[],
                        help="CHEMISTRY=TOP=DIR: renders made with that toner's top raised to TOP, shown past today's top")
    parser.add_argument("--toning-approved", default="", help="what the captain approved on the toning board, with --approved")
    parser.add_argument("--slim", action="store_true", help="smaller pictures and clips, for the copy kept in the repository")
    parser.add_argument("--no-previous", action="store_true", help="leave out each scene's comparison with treatment version 2")
    parser.add_argument("--approved", action="store_true", help="say on each board what the captain approved, for the copies kept after approval")
    args = parser.parse_args()
    if args.slim:
        MEDIA.update(SLIM_MEDIA)
    if args.no_previous:
        MEDIA["previous"] = False
    renders = json.load(open(os.path.join(args.renders, "manifest.json")))
    scenes = json.load(open(args.scenes))
    renders["root"] = os.path.abspath(args.renders)
    renders["sourcesRoot"] = os.path.dirname(os.path.abspath(args.scenes))
    renders["photoScenes"] = scenes["photos"]
    renders["movieScenes"] = scenes["movies"]
    renders["date"] = args.date
    renders["approved"] = args.approved
    alternates = []
    for index, path in enumerate(args.alternate):
        alternate = json.load(open(os.path.join(path, "manifest.json")))
        values = args.alternate_values[index] if index < len(args.alternate_values) else None
        alternate.update(root=os.path.abspath(path), suffix="bc"[index], comparisonOnly=index + 1 in args.comparison_only,
                         label=args.alternate_label[index] if index < len(args.alternate_label) else "BC"[index],
                         note=args.alternate_note[index] if index < len(args.alternate_note) else "",
                         values=open(values).read().rstrip() if values else "")
        alternates.append(alternate)
    if alternates:
        renders.update(alternates=alternates, alternateBoards=args.alternate_boards,
                       alternateFilmStocks=args.alternate_film_stocks, primaryLabel=args.primary_label,
                       primaryNote=args.primary_note, looksHeading=args.looks_heading)
    if args.remote_references:
        renders.update(remoteReferences=json.load(open(args.remote_references)), remoteDate=args.remote_date)
    # Instant packs: the renders named, or the primary renders' own.
    pack_renders = []
    for index, item in enumerate(args.packs):
        label, path = item.split("=", 1)
        pack_renders.append({"label": label, "note": args.pack_notes[index] if index < len(args.pack_notes) else "",
                             "root": os.path.abspath(path), "suffix": "abcd"[index],
                             "files": json.load(open(os.path.join(path, "manifest.json")))["files"]})
    if not pack_renders and any(entry["kind"] == "pack" for entry in renders["files"]):
        pack_renders.append({"label": "As the app develops it", "note": "", "root": renders["root"], "suffix": "a", "files": renders["files"]})
    renders.update(packs=pack_renders, packDefinitions=scenes.get("instantPacks", []), toning=scenes.get("toning"),
                   toningApproved=args.toning_approved)
    for name in ("findings", "questions", "further_values"):
        if getattr(args, name):
            renders[{"further_values": "furtherValues"}.get(name, name)] = json.load(open(getattr(args, name)))
    stronger = {}
    for item in args.stronger_toning:
        chemistry, top, path = item.split("=", 2)
        stronger[chemistry] = {"top": float(top), "root": os.path.abspath(path),
                               "files": json.load(open(os.path.join(path, "manifest.json")))["files"]}
    renders["strongerToning"] = stronger
    sources = json.load(open(os.path.join(args.sources, "manifest.json")))
    for entry in sources:
        if entry.get("local_path") and not os.path.isabs(entry["local_path"]):
            entry["local_path"] = os.path.join(os.path.abspath(args.sources), entry["local_path"])
    os.makedirs(args.output, exist_ok=True)
    # The record needed to fetch the same files again: each one's download URL, and the scenes the renders used.
    shutil.copy(os.path.join(args.sources, "SOURCES.md"), os.path.join(args.output, "SOURCES.md"))
    shutil.copy(os.path.join(args.sources, "manifest.json"), os.path.join(args.output, "sources.json"))
    shutil.copy(args.scenes, os.path.join(args.output, "scenes.json"))
    for board in BOARDS:
        if args.only and board["id"] not in args.only:
            continue
        print(build(board, renders, sources, args.output, args.round))
    # The toning board is the Darkroom's, not a Camera's: built when the scenes name toned prints and it is asked for.
    if renders["toning"] and (not args.only or "toning" in args.only):
        print(build_toning(renders, sources, args.output, args.round))


if __name__ == "__main__":
    main()
