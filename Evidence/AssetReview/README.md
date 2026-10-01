# Camera and Soundtrack Review Draft 01

Open [the local review](review.html) with its sibling files in place. It uses the
native Film Journal's serif/system-text/green-accent visual language, not the
prototype's code or a shipping browser UI. No server or network is required.
This is preparation for the **existing** DEC-04/05/11 review, not another decision
request or production approval. No draft enters `App/Immerse` resources.

## Candidate and Provenance

Renderer baseline: `df5f3b1`; the containing commit identifies the draft generator,
source and review. `SHA256SUMS` binds the generated source, provenance, all outputs,
manifest, generator code and the unchanged native renderer. The exact built-in
image-generation prompt and audio score provenance are in
[sources/PROVENANCE.md](sources/PROVENANCE.md). The generated image is retained as
`sources/window-still-life-generated.png`. No API/CLI image-generation fallback,
outside media download, purchase or sampled recording was used.

Fourteen main assets were generated and fully decoded by ImageIO/AVFoundation:
three developed photos, one 22-second original instrumental, two four-second
silent digital-pan source clips, four Developed Clips and four assembled Movies.
Two decoded poster frames are also retained. The Camera outputs are actual
`NativePhotoRenderer`/`NativeMovieRenderer` results with fixed seeds, not edited
mock images or a claim that these are physical camera captures.

`draft-01/manifest.json` records observed hashes, dimensions, codec, cadence,
duration, audio-track counts and decoded frames. Disposable is 1448 x 1086; Instant
2048 square; 6x6 3072 square. Both eight-second Movies are H.264 1920 x 1440,
landscape locked, with the portrait second clip bordered. Assemblies report
18 fps (Super 8) and 24 fps (16mm). The individual Super 8 clips report nominal
17.992502 fps despite 18-fps sample scheduling; this observed value is retained,
not rounded into a fidelity claim. Silent variants have zero audio tracks;
instrumental variants have one. Source Movies always have zero.

## Execution

Observed 2026-10-01, approximately 08:27-08:32 PDT, macOS 26.6.2, Xcode 26.5,
Swift 6.3.2, x86_64. Exact generator command:

```sh
swift run --package-path Probes/AssetReviewGenerator AssetReviewGenerator Evidence/AssetReview/sources/window-still-life-generated.png Evidence/AssetReview/draft-01
shasum -a 256 -c Evidence/AssetReview/SHA256SUMS
```

Both succeeded (`AssetReview-2.log`, inventory check). The destination must not
already exist; use a new private directory for repeat generation. The first build
failed because an `@main` type was in `main.swift` alongside another source file;
renaming it and using an encode-only manifest corrected compilation without
changing renderer behavior. The first failed log remains `AssetReview-1.log`.
The separate compile gate also passed (`build-gate.log`); `validate-local.sh` now
builds this non-shipping tool without regenerating large media or calling image
generation in CI. Production code is unchanged from `df5f3b1`, whose 115-module/
17-study-test and unsigned-build results remain the relevant software baseline.

Browser inspection used `chrome-devtools-axi` on the local HTML:

```sh
chrome-devtools-axi newpage file://<worktree>/Evidence/AssetReview/review.html
chrome-devtools-axi resize 1440 1000
chrome-devtools-axi screenshot <worktree>/Evidence/AssetReview/desktop-photos.png
chrome-devtools-axi emulate --viewport '390x844x3,mobile,touch'
chrome-devtools-axi screenshot <worktree>/Evidence/AssetReview/mobile-390.png
```

Actual source/result images loaded. Super 8 playback advanced and decoded frames;
seeking to five seconds displayed the portrait clip within the locked landscape
frame (`desktop-super8-portrait-clip.png`). 16mm silent and instrumental variants
advanced to 0.522381/0.461222 seconds with 15/14 decoded frames and no media error.
The muted audio playback check advanced to 0.203955 seconds of its 22-second
duration. `browser-playback.txt` retains that result; it is not a listening review.

At 390 x 844, document width equals viewport width and checked layout elements do
not overflow (`browser-mobile-390.txt`). Desktop and mobile screenshots were
visually inspected. Plain browser resize initially stopped at 500 pixels; only
the later explicit mobile emulation establishes 390-pixel coverage. The screenshot
wrapper returned a saved-path reporting error for that emulated capture, but the
1170-pixel-wide PNG exists, decodes and was inspected. No failure is counted as a
native accessibility pass. `browser-image-checks.txt` records loaded photos and
no external media URLs. Browser console had no messages.

## Requirement Disposition

| Affected requirements | Preparation now available | Still required |
| --- | --- | --- |
| CAM-10 / DEC-05 / FR-01 | Inspectable before/after samples for all five Cameras, native decoded metadata and source provenance. | Curated representative final scenes, rights approval, in-app approved bundling and actual native sample browsing. A generated still/digital pan is not a complete production sample set. |
| DEC-04 / CAM-12 / DEV-04,06 / MOV-03,05,10 / QA-03,11 | Actual current treatment/crop/grain/flicker/cadence examples and portrait-border comparison. | Human quality/format-distinctness selection, approved output matrix, HDR/HEVC/native sensor fidelity, iPhone 11 timing. No provisional value is silently finalized. |
| MOV-09,11 / DEC-05,11 / QA-14 | Original drafted score/audio and actual native silent versus instrumental assemblies. | Human listening, ownership/terms/attribution and explicit bundling/user-export rights, selection/reselection choice. No license text or production clearance is invented. |

The recommendation is to use this set to identify changes to the proposed look and
audio direction, then validate approved settings on representative phone captures.
No people/skin tones, real subject motion, low light or genuine analog film are
represented here. The production manifest remains empty, and all decision and
hardware gates remain open. Containment is local-only review on the isolated
branch; no publication, analytics, release or personal-media mutation occurred.
