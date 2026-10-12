# PRD 2.1 slice 4: per-Camera looks

Tracker tasks CAM-17 and QA-16, implemented from 2026-10-09 for the captain's "please implement prd 2.1" and "go on prd 2.1" (ADRs 0013 to 0015; PRD 2.1 sections 6.1 to 6.3).
This is software, simulator and review-board evidence only; physical-iPhone capture and rendering stay deferred to the manual candidate.

## What changed

- **Treatment versions follow the Film (decision).**
  A `CameraPackage` now records `treatmentVersion`, and a Film keeps the package it locked at Load Film, as it already keeps its name and capacity.
  `DevelopmentRun(film:)` takes the Film's version and every `TreatmentAssignment` records it, including Instant prints exposed later.
  A package locked before this slice has no version and develops with version 2 (`NativePhotoRenderer.lockedBeforeVersionsTreatmentVersion`), so a Film that was unfinished when the app was updated keeps the look it started with, not just one that was already developing.
  `DevelopedTreatment` renders whichever version a capture was assigned and refuses an unknown one (`NativeRenderError.unrenderableTreatment`); the processor's existing `rendersAssignedTreatment` check still stops Development first.
- **Versions 1 and 2 are frozen.**
  The provisional shared look moved unchanged from `NativePhotoRenderer.swift` into `LegacyLook.swift`.
  `LegacyLookTests` compares version 2 photos of every Camera and Film Stock, and Movie frames of both Movie Cameras, with 8 x 8 block means recorded from the version 2 build (0e69ed2) before any change; they agree within a level or two.
- **Version 3, `film-look-3`: one look per Camera and Film Stock.**
  Every value is in one place, `FilmLook` in `Packages/RenderCore/Sources/RenderCore/FilmLook.swift`, one `Treatment` per Camera and Film Stock with its Format Reference named in an internal comment.
  A treatment is the Film Stock's emulsion (color balance, color strength, an S-shaped print curve with print black and white, shadow and highlight color, grain) plus the Camera's lens, flash, print variation and gate.
  The emulsion is applied as a 32-point color cube over display tones, built once per capture or clip; spatial values are fractions of the picture's long edge, so a look is the same at any size.
- **Fresh, not aged (ADR 0013), with the captain's exceptions (ADR 0016).**
  No version 3 look lifts its blacks, yellows its whites, weakens color or turns its hues, except the Cameras in `FilmLook.captainsExceptions`, the Instant and the Super 8: `FilmLookTests.testEveryLookIsFreshlyProcessedNotAged` checks every other color treatment on black, white and five color patches, and that black-and-white stays gray, while `testTheInstantDevelopsWithTheFadedLookTheCaptainChose` and `testTheSuperEightDevelopsMutedWithAGlowAsTheCaptainChose` hold those two to their chosen looks.
  The 16mm's color Film Stock stays under the fresh test with one allowance, the 4 percent black point the captain asked for (ADR 0016), which the test pins.
- **Each Camera's imperfections (PRD 2.1 section 6).**
  - Disposable: warm, saturated color; heavy grain (amplitude 8) with extra grain in the shadows, so a dim scene without flash develops dark and grainy; a plastic lens's soft, 0.6-stop darker corners; and, on an exposure whose Exif says the flash fired, a hot center that falls 0.9 stops to the corners and harsher print contrast. No light leaks, red-eye, dust or scratches.
  - Instant: the faded look the captain chose on its board (see "Review boards" below); each print gets its own density (up to 0.12 stops) and color (warmth and tint) from its seed, so it is assigned once and never rerolled. The size of the variation stays provisional pending the study of preserved 1970s prints.
  - 6×6 color: natural, warm color, very fine grain, gentle contrast, sharp to the corners. Black-and-white: a new panchromatic silver layer with high contrast and distinct grain.
  - Super 8: the muted look with a glow the captain chose on its board (see "Review boards" below) and fine grain; per-frame jitter and a slow weave drawn from just outside the frame so no edge shows; a brightness flicker of up to 0.06 stops; up to three dust specks on a frame; and, on about half of clips, a hair caught at the gate's edge for the whole clip.
  - 16mm: visible grain; a glow around highlights, red on color and neutral on black-and-white; minor jitter and weave; soft, darker edges; no flicker, dust or hair.
    The color Film Stock's color follows the four reference pictures the captain gave on its board: blues turned toward aqua, strong warm reds and yellows, cool shadows and full contrast with a soft highlight roll-off, with the black point at his 4 percent.
- **Tone curves from the captain's notes.**
  `FilmLook.ToneCurve` takes either an S-curve or a point curve (`points`, a monotone cubic through the points as a photo editor draws one), since the captain wrote several notes as curve points and Lightroom slider values.
  `Probes/LookReviewBoards/lightroom_curve.py` turns Basic-panel values into such a curve.
  Adobe does not publish the sliders' math, so the script is a stated approximation of their effect, not Lightroom itself, and each board said so.
  `Lens.diffusion` adds the veil of diffused light that negative Clarity gives.
- **The 16mm color stock's fixed daylight balance (decision).**
  PRD 2.1 section 6.2 says warm indoor light develops orange on the color Film Stock, which the phone's automatic white balance would otherwise remove.
  The capture now writes the lens's white-balance reading at the start of each Movie clip into the clip as QuickTime metadata (`SceneWhiteBalance`, key `app.immerse.scene-white-balance`), and the 16mm color treatment (`fixedBalance: 5500`) develops the clip as daylight film records that light.
  The viewfinder and the recording keep the phone's automatic white balance, so nothing previews the developed color (FR-04), the same choice slice 2 made for the Disposable's fixed exposure.
  A clip without the record, every other Camera and the black-and-white stock are unaffected.
  The device reading is unproven until the manual candidate.
- **Load Film copy.**
  The 16mm look line now follows the chosen Film Stock: "Visible grain, a red highlight glow, minor jitter and weave, soft dark edges" on Color (main's line) and "Visible grain, a neutral highlight glow, minor jitter and weave, soft dark edges" on Black and white.
  Keeping one line of nearly main's length avoids the longer wordings that slice 3 found tripping the elementless clipped-text audit finding at the largest text size.
  `ContentSizeTests.testFilmStockLoadScreenTextAt…` (renamed from `testSixBySixLoadScreenTextAt…`) now also measures the black-and-white line at every size.
  The Instant's look line changed from "Brilliant, warm, saturated color and soft detail" to "Warm, faded color, soft contrast and soft detail", and the Super 8's from "Strong, rich color, fine grain, an unsteady frame, flicker, dust and hair" to "Muted color, a warm glow, fine grain, an unsteady frame, flicker, dust and hair", to say what those Cameras now develop.

## Review boards (QA-16)

- **How a board is made.**
  `Probes/LookReviewBoards` (commands in its README) develops each test scene through `NativePhotoRenderer.develop` and `NativeMovieRenderer.developClip`, the same calls Development makes, and `build_boards.py` lays each Camera's results beside its Format Reference imagery, the phone capture each started from and the values in `FilmLook.swift`.
  Each board was served to the captain as a Lavish review (`lavish-axi`), and his replies came back through it.
  The copies kept in `Evidence/AssetReview/looks/<camera>/index.html` are the last round of each board, built with `--slim` (smaller pictures and clips, no version 2 comparison).
- **Reference imagery and licenses.**
  The boards use 60 reference files (photographs, film frames and short film excerpts made with each Format Reference or the closest openly licensed equivalent) and 22 test scenes.
  Every one is public domain, CC0, CC BY or CC BY-SA, read from Wikimedia Commons or Flickr at download time, and is credited on its board with its source page, author and license; `Evidence/AssetReview/looks/SOURCES.md` lists them all with the gaps and substitutions, and `sources.json` keeps each download URL.
  None is in the app, and the Format Reference names appear only on the boards, in comments and in these records.
- **One departure: the captain's own reference pictures.**
  The captain gave pictures from public forum posts as targets: five for the 6×6 color Film Stock on 2026-10-11 and four for the 16mm color Film Stock on 2026-10-12.
  They are not openly licensed, so each board shows them from where they are published and no copy is in the repository; they were viewed and their tones and colors measured only to tune the looks.
  Four openly licensed scenes close to the 16mm pictures in subject and light were added to that board so like sits beside like.
- **A preset the captain named.**
  On 2026-10-12 he asked for a 6×6 candidate from the values in a published photo-editor preset (OpenFilmStocks, `2.1.5 Kodak Portra 400.xmp`, MIT License).
  Only its numbers were used; the file is not in the repository.
  Its color mixer has no equivalent in `FilmLook`, so the candidate was rendered with a mixer added to the renderer in the working tree only; it enters the app only if he chooses that candidate.
- **A look outside ADR 0013 is the captain's choice.**
  Where his notes asked for a look the fresh rule excludes, the board showed two candidates, A inside the rule and B as his notes described, and only his answer put B in the app, recorded in ADR 0016.

| Camera | Rounds | The captain's words | Outcome |
| --- | --- | --- | --- |
| 1990s Disposable | 1 (2026-10-09), 2 with A and B (2026-10-10), 3 with A alone | "fresh" | Approved 2026-10-10: A, inside ADR 0013. |
| 1970s Instant | 1 (2026-10-09), then A and B, then 2 with B alone (2026-10-10) | "the image has to be more faded", then "faded", then "approved" | Approved 2026-10-10: the faded look, ADR 0016. Its print-to-print variation stays provisional until the study of preserved 1970s prints. |
| 1960s Super 8 Home Movie | 1 (2026-10-09), 2 with A and B (2026-10-10), 3 with B alone | "muted with a glow" | Approved 2026-10-10: B, ADR 0016. |
| 6×6 Medium Format | 1 (2026-10-09) to 7 (2026-10-12) | Slider notes, then five reference pictures, a point curve, "please replicate lightroom values", then "Round 5 values are better than the lightroom values. please retry with the .xmp values" | Awaiting the captain on round 7, which shows the round 5 color look (A, in the app) beside the preset he named (B, whose muted greens are just past ADR 0013's limit). Black-and-white follows his notes from round 4. |
| 16mm Cinema | 1 (2026-10-09) to 7 (2026-10-12) | A description of the reference film, then slider values, "please replicate the lightroom values", then four reference pictures: "get as close as possible" | Awaiting the captain on round 7, tuned to his reference pictures. The 4 percent black point is his choice (ADR 0016). |

What the boards do not show: the test scenes are modern digital photographs and clips, not captures from an iPhone running the app, so the Disposable's fixed exposure, the real flash and the phone's own processing are absent.
The Movie scenes were tone-mapped to SDR first; a phone may record HDR, which the manual candidate has to check.
The warm-light 16mm scene is a daylight-balanced picture marked as recorded under 3200 K light, which exercises the fixed daylight balance but is not a capture under household bulbs.

## In the app

`Probes/PopulatedJournalHarness` develops a private Film per Camera and Film Stock through the production Development from a natural photo and clip (two of the boards' openly licensed test scenes, passed as `TEST_RUNNER_PHOTO_SOURCE` and `TEST_RUNNER_MOVIE_SOURCE`), and `PopulatedWorkflowTests.test…LookScreens` photographs the Film screen and the developed photo or Developed Movie.
All seven tests passed on an iPhone 17 Pro and an iPhone SE (3rd generation) simulator, iOS 26.5, on 2026-10-11; the 22 screenshots are in `prd-2-slice-4-looks/`, named `look-<camera>-<screen>-<device>.png`.
They show the looks inside the real views, not a capture: the harness seeds its Films and never opens the camera.

## Tests

| Where | What |
| --- | --- |
| `RenderCoreTests/LegacyLookTests` | Version 2 photos and Movie frames match the version 2 build's |
| `RenderCoreTests/FilmLookTests` | Versions assigned from the Film's package; unknown version refused; every look new and distinct; fresh, not aged, with the Instant and the Super 8 held to the looks the captain chose and the 16mm's black point pinned; the print curve and a point curve; Disposable flash from Exif, heavy and shadow grain; grain ranking across Cameras; grain keeps the tone; soft dark edges where the format has them; the diffusion veil; Instant print variation; Super 8 jitter, flicker, dust and gate hair; 16mm red and neutral glow, weave without flicker; the daylight balance and its clip metadata |
| `RenderCoreTests/FilmStockRenderTests` | Black-and-white higher in contrast on a neutral ramp; versions 1, 2 and 3 renderable |
| `FilmRuntimeTests/TreatmentVersionDevelopmentTests` | Through the production processor: an unfinished roll, an Instant pack and a black-and-white 16mm reel locked before the update develop with version 2; a new roll with version 3 |
| `FilmDomainTests/SceneWhiteBalanceTests` | The recorded light round-trips through its metadata value |
| `ImmerseTests` | Load copy names the glow of the chosen stock and no film |
| `ImmerseUITests/ContentSizeTests` | The 16mm black-and-white look line at all twelve sizes |
