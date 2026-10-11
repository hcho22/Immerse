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
- **Each Camera's imperfections (PRD 2.1 section 6).**
  - Disposable: warm, saturated color; heavy grain (amplitude 7) with extra grain in the shadows, so a dim scene without flash develops dark and grainy; a plastic lens's soft, 0.6-stop darker corners; and, on an exposure whose Exif says the flash fired, a hot center that falls 0.9 stops to the corners and harsher print contrast. No light leaks, red-eye, dust or scratches.
  - Instant: the faded look the captain chose on its board (see "Review boards" below); each print gets its own density (up to 0.12 stops) and color (warmth and tint) from its seed, so it is assigned once and never rerolled. The size of the variation stays provisional pending the study of preserved 1970s prints.
  - 6×6 color: natural, warm color, very fine grain, gentle contrast, sharp to the corners. Black-and-white: a new panchromatic silver layer with high contrast and distinct grain.
  - Super 8: the muted look with a glow the captain chose on its board (see "Review boards" below) and fine grain; per-frame jitter and a slow weave drawn from just outside the frame so no edge shows; a brightness flicker of up to 0.06 stops; up to three dust specks on a frame; and, on about half of clips, a hair caught at the gate's edge for the whole clip.
  - 16mm: visible grain; a glow around highlights, red on color and neutral on black-and-white; minor jitter and weave; soft, darker edges; no flicker, dust or hair.
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

To be completed with the boards, their sources and licenses, and the captain's approvals.

## Tests

| Where | What |
| --- | --- |
| `RenderCoreTests/LegacyLookTests` | Version 2 photos and Movie frames match the version 2 build's |
| `RenderCoreTests/FilmLookTests` | Versions assigned from the Film's package; unknown version refused; every look new and distinct; fresh, not aged; Disposable flash from Exif, heavy and shadow grain; grain ranking across Cameras; grain keeps the tone; soft dark edges where the format has them; Instant print variation; Super 8 jitter, flicker, dust and gate hair; 16mm red and neutral glow, weave without flicker; the daylight balance and its clip metadata |
| `RenderCoreTests/FilmStockRenderTests` | Black-and-white higher in contrast on a neutral ramp; versions 1, 2 and 3 renderable |
| `FilmRuntimeTests/TreatmentVersionDevelopmentTests` | Through the production processor: an unfinished roll, an Instant pack and a black-and-white 16mm reel locked before the update develop with version 2; a new roll with version 3 |
| `FilmDomainTests/SceneWhiteBalanceTests` | The recorded light round-trips through its metadata value |
| `ImmerseTests` | Load copy names the glow of the chosen stock and no film |
| `ImmerseUITests/ContentSizeTests` | The 16mm black-and-white look line at all twelve sizes |
