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
  A color negative whose look the captain supplied as files is a third kind of emulsion, `NegativeFilm`, which develops the scene's light and not display tones; see "The captain's look files" below.
- **Fresh, not aged (ADR 0013), with the captain's exceptions (ADR 0016).**
  No version 3 look lifts its blacks, yellows its whites, weakens color or turns its hues, except where `FilmLook.isCaptainsException(camera:filmStock:)` says the captain chose otherwise: the Instant, the Super 8 and the color Film Stocks of the 16mm and the 6×6.
  `FilmLookTests.testEveryLookIsFreshlyProcessedNotAged` checks every other treatment on black, white and five color patches, and that black-and-white stays gray, while `testTheInstantDevelopsWithTheFadedLookTheCaptainChose` and `testTheSuperEightDevelopsMutedWithAGlowAsTheCaptainChose` hold those two to their chosen looks, and `NegativeFilmTests`, `ScenePassesTests` and `MediumFormatPassesTests` hold the two color Film Stocks to the captain's files.
- **Each Camera's imperfections (PRD 2.1 section 6).**
  - Disposable: warm, saturated color; heavy grain (amplitude 8) with extra grain in the shadows, so a dim scene without flash develops dark and grainy; a plastic lens's soft, 0.6-stop darker corners; and, on an exposure whose Exif says the flash fired, a hot center that falls 0.9 stops to the corners and harsher print contrast. No light leaks, red-eye, dust or scratches.
  - Instant: the faded look the captain chose on its board (see "Review boards" below); each print gets its own density (up to 0.12 stops) and color (warmth and tint) from its seed, so it is assigned once and never rerolled. The size of the variation stays provisional pending the study of preserved 1970s prints.
  - 6×6 color: since 2026-10-12 the look in the captain's own files (below): gentle contrast with lifted blacks, cream-warm grays, very fine grain, a mild lens vignette and no softening. Black-and-white: a new panchromatic silver layer with high contrast and distinct grain.
  - Super 8: the muted look with a glow the captain chose on its board (see "Review boards" below) and fine grain; per-frame jitter and a slow weave drawn from just outside the frame so no edge shows; a brightness flicker of up to 0.06 stops; up to three dust specks on a frame; and, on about half of clips, a hair caught at the gate's edge for the whole clip.
  - 16mm: visible grain; a glow around highlights, red on color and neutral on black-and-white; minor jitter and weave; soft, darker edges; no flicker, dust or hair.
    The color Film Stock's color and passes are the ones in the captain's own files since 2026-10-12 (next section): a long soft highlight shoulder, muted greens, aquas and purples, and daylight gray developed neutral, with black at 4 percent and the shadows opened, as he chose once he saw them applied.
    The black-and-white Film Stock keeps the values tuned on its board.
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

## The captain's look files: the 16mm Cinema's color Film Stock (2026-10-12)

- **What he sent and said.**
  After replying on the 16mm board with a written spec, the captain sent the files that define that Film Stock's look: `vision3_250d_lut.py`, a look generator with written constants, and `effects_16mm_reference.py`, a reference for the per-frame passes, with the calibration tools that derived them.
  His words: "please apply the attached for immerse - 16mm camera kodak vision3 250d".
  Firstmate's message 009 made the two files the source of truth for the 16mm Cinema's color Film Stock.
  They are kept byte for byte in `Probes/FilmLookCalibration/16mm/`, with their hashes in that probe's README.
- **How the color is applied.**
  `FilmLook.NegativeFilm` (`NegativeFilm.swift`) is his film model, step for step: white-balance gain and exposure, log exposure with a soft toe, crosstalk between the layers, each layer's contrast, the print curve between clear film and maximum density, his black level, seven hue bands in OKLCh with his centers, widths and chroma gate (the fitted bands and his finishing bands added), the highlight and shadow desaturation, and the soft clip.
  `FilmLook.cinemaColor` holds his "print" constants, and a test reads each one back from his file; his "scan" variant is not in the app.
  One constant is his later word and not his file's: the print's density range, shortened so that black develops to 4 percent and the shadows open (see "The black he asked for" below).
  A phone picture is display-referred, so his inverse knee opens its highlights first (`NegativeFilm.sceneLight(displayLight:)`).
- **How the passes are applied.**
  `DevelopedTreatment.developInSceneLight` (`SceneDevelopment.swift`) runs his order on the scene's light: halation, soft edges with the vignette, overall softness, Apple Log tones on Rec.2020 primaries, grain in Apple Log units, the film, then weave with jitter, rotation and the over-scale.
  `FilmLook.ScenePasses` holds his constants unchanged, and a test reads each one back from his file.
  There is no brightness flicker, dust or hair, and the picture stays 4:3 (FR-05).
- **Computed on the phone, not shipped as a table (decision).**
  Firstmate left this to engineering.
  The app computes his function into a table when a clip develops, so there is one set of constants and the tests tie it to his Python.
  The table has 64 tones a side and is asked in tones of the scene's light on Rec.709 primaries, stretched over the same range as Apple Log; grain is still added in Apple Log on Rec.2020, as his order has it.
  On those primaries a phone picture's most saturated colors lie on the table's faces, where it reads them exactly; his 33-point table over Rec.2020 is 0.073 off his own function at the phone's purest green, and this one is 0.024 off there.
- **Read tetrahedrally (decision).**
  Core Image's own color cube reads between a table's tones along each axis.
  A film's color changes begin sharply beside gray, and that reading lets the colors beside a gray into it: grays came out up to 0.0045 from his function on the 16mm and up to 0.009 from his table on the 6×6, with a faint tint.
  `TableReading.swift` reads the table tetrahedrally instead, as his 6×6 spec says to, with a small Core Image kernel written in Metal: a gray's reading then uses only the table's grays.
  Grays now come out within 0.001 of the film's own table on both stocks, with no tint.
  The kernel is made at run time, the first time Development needs it, and is checked against the same reading in Swift before it is used.
  Where Core Image cannot make or run it, a renderer without Metal, Development falls back to Core Image's own cube, handed over as whole 8-bit steps plus remainders so that its 8 bits do not show; `testWhereTheTableCannotBeReadTetrahedrallyCoreImagesCubeReadsIt` holds that reading too.
  The kernel has run on this Mac and inside the iOS simulator, where the same tests hold it; its first run on an iPhone is the manual candidate's.

### How the app is held to his files

The fixtures are his own functions' output, written by `Probes/FilmLookCalibration/16mm/make_fixtures.py`, which imports his two files unchanged.
Values are display tones from 0 to 1.

| Test | What is compared | Tolerance stated | Measured |
| --- | --- | --- | --- |
| `NegativeFilmTests.testEveryConstantIsTheGenerators`, `ScenePassesTests.testEveryConstantIsTheReferences` | Every constant of the film and of the passes against the value in his file | Equal | Passes |
| `NegativeFilmTests.testTheFilmGivesEveryNeutralValueTheGeneratorStates` | His `SANITY` table for "print", six neutral values from 6 stops under middle gray to 5 over | 0.02, his own | Passes for middle gray and the three values over it; the two under it, 6 and 2 stops under, are opened by the density range he chose and are held to his function with it (0.049 and 0.196 where his table has 0.014 and 0.141) |
| `testANeutralRampNeverReverses` | 200 neutral steps from 8 stops under to 7 over, each channel | Never falls | Passes |
| `testTheFilmMatchesTheGeneratorOnAWideSetOfColors` | 704 scene colors (a neutral ramp, a 7 x 7 x 7 grid of phone colors, 300 random colors up to 5 stops over gray) and 425 Apple Log tones against his Python | 0.00002 in every channel (the fixture is rounded to six places) | Passes |
| `testThePipelineDevelopsPhoneColorsAsTheGeneratorDoes` | 216 phone colors through Development's own steps (inverse knee, Apple Log, cube) against his exact function | 0.03 at worst, 0.003 on average | 0.025 at worst, on the purest green; every other color within 0.01 |
| `testGraysAreReadFromTheTablesGraysAlone` | The phone's 256 neutral tones through the pipeline against the film's own table read tetrahedrally | 0.002, with no more than 0.001 between the channels, and never a step down | 0.0009 and 0.0005 |
| `testWhereTheTableCannotBeReadTetrahedrallyCoreImagesCubeReadsIt` | The same colors and grays with Core Image's own cube, the fallback | Grays within 0.01, a tint of up to 0.004 | 0.0045 and 0.001 |
| `testThePipelineGivesTheNeutralValuesTheGeneratorStates` | His `SANITY` values a phone picture can reach (its white is 3.85 stops over gray) through the same steps, and a 256-step neutral ramp | 0.02, and 0.01 against his exact function; the ramp never falls | Passes |
| `ScenePassesTests.testTheFrameWithNoPassesIsTheFilmAlone`, `testHalationMatchesTheReference`, `testSoftDarkenedEdgesMatchTheReference`, `testEveryPassBeforeTheGrainMatchesTheReference` | A 320 x 240 test frame (sky, dark ground, color patches, lamps bright enough to glow, fine detail, an even gray) against his reference's frame for each pass alone and for all of them in his order | Mean 0.003, 99 percent of values within 0.01, worst 0.08 | Mean about 0.001, 99 percent within about 0.005, worst about 0.06 at the rim of a lamp |
| `testAPortraitFrameDevelopsAsTheSameFilmTurnedOnItsSide` | The test frame turned a quarter turn, developed and turned back, against the same reference frame; and grain on an even gray frame held either way up | The frame tolerances above; grain strength within 5 percent | Passes; with lengths taken from the frame's width it fails (99 percent within 0.018, grain a quarter weaker) |
| `testHalationAndVignetteBehaveAsTheReferenceChecksThem` | His self-test's checks: nothing below the threshold is touched, the glow is red over green over blue, the vignette takes its whole amount at the corner | His own | Passes |
| `testTheSwayIsTheReferences` | The weave's slow sway at six times, with his phases | 0.000000001 px | Passes |
| `testAWovenFrameMatchesTheReference` | One frame moved and turned by the numbers his reference drew, against his woven frame | Mean 0.002, 99 percent within 0.02 | Passes |
| `testAClipWeavesSlightlyAndNeverFlickers` | A clip's frames move, by no more than his weave allows, and their brightness does not change | Mean brightness within 0.001 | Passes |
| `testTheGrainFieldMeasuresAsTheReferencesDoes` | The grain's make-up against his field at 1920 px: how much the three layers share, and how alike neighboring pixels are at six distances across and down | Layer correlations within 0.01, neighbor correlations within 0.02 | Passes |
| `testTheGrainHasTheReferencesStrengthAndIsNewOnEveryFrame` | Per-layer strength in Apple Log units at his strength of 1.5, scaled with width; no tone added; a new pattern each frame | 5 percent, his self-test's own allowance | Passes |
| `testTheWholeDevelopedFrameComparesWithTheReferences` | The whole developed frame beside his, by 20-pixel blocks with no edge in them, and grain over the even gray | Block means within 0.012; grain strength within a fifth | Passes |

Both files' own self-tests pass ("sanity checks passed", "effects self-test passed").
His `derive_stock.py` and `preview_16mm.py` ran unchanged apart from their output folder; what they printed, the two preview pictures, and every package's version and license are in `prd-2-slice-4-looks/calibration/`.
His fit tool was not run for the look: his constants were fitted and then timed by hand, and a raw fit never replaces them.

### Where the app reads his reference its own way

These are engineering choices inside "apply it exactly", each measured above.
They were listed for firstmate.

- **Lengths follow the frame's long edge.**
  His reference scales every length with the frame's width and develops a landscape frame.
  The app uses the long edge, so a portrait clip gets the same blur, glow and grain sizes as a landscape one; his code read literally would give a portrait clip three quarters of them.
  For a landscape clip the two are the same.
  Firstmate confirmed the long edge on 2026-10-12: a portrait clip is the same film turned on its side.
- **Grain comes from eight stored fields.**
  His reference draws a new random field for every frame.
  The app makes eight 512-pixel fields once, the number both of his written specs give, with his octaves, shared share and unit strength, and gives each frame one of them at an offset of its own.
  The statistics above are the same; the pattern repeats only as any tile does.
- **Random draws come from the capture's seed.**
  The weave's phases, jitter and turn use the app's own seeded draws with his distributions, so a clip develops the same way every time, as a Developed Treatment must.
- **Core Image, not hand-written Metal shaders.**
  His file speaks of Metal shaders; the app's renderer is Core Image, with one kernel of its own for reading the table, which the same tests hold to his numbers.
- **The fixed daylight balance is restored, not locked.**
  His files assume the white balance is locked at daylight while recording.
  The app records with the phone's automatic white balance, so the viewfinder never previews the developed color (FR-04), writes the light's reading into each clip, and Development puts that light back before his pipeline (the slice's earlier decision, above).
  The result is the same in principle, and the phone's reading is unproven until the manual candidate.
- **The black-and-white Film Stock is untouched.**
  It keeps its own halation, weave, soft edges and grain from before, so the two Film Stocks' passes are built differently.

### Where his files differ from PRD 2.1 and the ADRs

- **PRD 2.1 section 6.2 and FR-05: no difference found.**
  His reference states the same rules the PRD does: visible grain, a red highlight glow on color as a deliberate departure, minor jitter and weave, soft darkened edges, no flicker, no dust or hair, no aging, a fixed daylight balance, 4:3.
  The Load Film line for the color Film Stock is still accurate.
- **ADR 0016: the black he asked for.**
  He chose a black point of about 4 percent on the 16mm board on 2026-10-10 and 2026-10-11.
  His files print black at 0.013 to 0.014, about 1.3 percent, and the app first applied them so.
  Shown that on the board on 2026-10-12 he wrote "the blacks are too strong for color. please tone it down", and then "please bring the black up to 4 percent".
  The board put two ways of doing that beside his files as applied: his black level alone raised to 4 percent (B), or the print's density range shortened so that black sits at 4 percent and the shadows open with it (C).
  His words named the black, so the app first took B; with both in front of him on the next round he wrote "lets go with C".
  The app now has C: `maximumDensity` is 2.74 where his file has 4.39, and his own black level stands.
  A phone tone of 32 (of 255) develops to 23 where his files alone give 8, and 64 to 55 where they give 42; middle gray stays where it is, and highlights come down a touch (the phone's white to 237 where his files give 239).
  Nothing else differs from his files: his file is unchanged in the probe, `make_fixtures.py` states the one difference, and the tests hold the app to his function with that density range.
  ADR 0016 records it as his choice.
- **ADR 0013: just outside two of the app's limits.**
  Measured as `FilmLookTests` measures the fresh rule, his files keep blacks deep (0.015 at most for a 3 percent black, limit 0.06), white unyellowed and hues within 12 degrees, but a 97 percent white develops to 0.903, 0.902 and 0.898 where the limit is 0.9, and a mid green keeps 79 percent of its strength where the limit is 80.
  On a color chart his look mutes greens to 0.65, aquas to 0.64 and purples to 0.55 of the scene's strength (his `derive_stock.py`).
  This is his model of the film freshly printed and not aging, and it is recorded in ADR 0016 as his choice since he asked for this look in so many words.
  With the density range he then chose (above), a 3 percent black develops to 0.050 at most, the 97 percent white to 0.893, 0.892 and 0.888, and the mid green keeps 69 percent of its strength.
- **ADR 0015: no difference.**
  His files name the reference films and say the names never appear in the product; they are in a non-shipping probe and in comments only.

### Provenance

His generator labels every constant as published, as the film maker's characteristic curves digitized in `spectral_film_lut` (MIT License), as fitted to that package's simulation, or as tuned by hand on top of the fit.
None of that package's code or data is in the repository or the app.
The app carries only his finished constants, so the MIT License's notice, which goes with copies or substantial portions of the software, is not required; the project has no notices file today.
Whether to credit the package anyway was put to firstmate (`prd-2-slice-4-looks/calibration/README.md`).

## The captain's look files: the 6×6 Medium Format's color Film Stock (2026-10-12)

- **What he sent and said.**
  The captain sent nine files for this Film Stock: the written spec he had already given on the 6×6 board, its generator `portra400_lut.py`, the two tables the generator writes for the "scan" look, and the calibration tools.
  His words: "please apply attached files to immerse 6x6 portra 400 film".
  Firstmate's message 010 made the generator and the spec the source of truth for the 6×6 Medium Format's color Film Stock.
  They are kept byte for byte in `Probes/FilmLookCalibration/6x6/`, with their hashes in that probe's README.
- **How the color is applied.**
  The generator uses the same film model as the 16mm's, so `FilmLook.NegativeFilm` serves both: here with an exposure of a quarter stop over, white-balance gains for warmth, a scan response in place of a print's, a lifted black and its own bands.
  `FilmLook.mediumFormatColor` holds his "scan" constants unchanged, and a test reads each one back from his file; his "print" look is not in the app.
- **The way in for a photograph.**
  Section 2 of his spec: Display P3 with the sRGB curve to linear light, his inverse knee, then Rec.2020.
  `FilmLook.ScenePasses.capture` says which primaries a Camera's pictures are opened on, Display P3 for this one and Rec.709 for a 16mm clip; a picture with another profile is carried to Display P3 first.
- **The passes.**
  Section 5 of his spec: a lens vignette that leaves the corners 0.82 of the center's light, and very fine grain in Apple Log units, with his per-layer strengths, size, second octave and default strength of 1.5.
  Nothing else: no softening, halation, weave, flicker, dust or hair, and the square stays borderless.
  The grain is 0.4 times the 16mm's, under his ceiling of 0.6.
- **His table, not his function (decision).**
  Between its 33 tones his table, read tetrahedrally as his spec reads it, is not his function: on 216 phone colors the two are 0.0025 apart on average and up to 0.08 apart on the most saturated ones, and on photographs 0.002 to 0.006 on average and 0.03 to 0.05 at worst.
  Message 010 asks for parity with both, which cannot both be tight.
  The app follows the table: it is the file he sent for the app, his spec says to ship it, his own previews and measurements went through it, and message 010's last test names it.
  The function itself still matches his Python to 0.00002.
  Firstmate confirmed on 2026-10-12 that this is engineering and stands as built; the board states it.
- **No table ships; the app makes it.**
  The app computes his table from his constants when a photograph develops.
  It equals his file at all 35,937 tones to six places, and his generator rewrites both of his tables byte for byte in the scratch environment.
  The table is read tetrahedrally, as above.

### How the app is held to his files

The fixtures are his own functions' output and his table's readings, written by `Probes/FilmLookCalibration/6x6/make_fixtures.py`, which imports his generator unchanged and checks that it still writes his table byte for byte.
The 6×6 has no reference file for its passes, so that script writes them out from section 5 of his spec, with his 16mm reference's own functions where the spec says the shader is the same.
Values are display tones from 0 to 1.

| Test | What is compared | Tolerance stated | Measured |
| --- | --- | --- | --- |
| `NegativeFilmTests.testEveryConstantIsTheGenerators` | Every constant of the film against the value in his file | Equal | Passes |
| `testTheFilmGivesEveryNeutralValueTheGeneratorStates`, `testANeutralRampNeverReverses` | His `SANITY` table for "scan", and 200 neutral steps | 0.02, his own; never falls | Passes |
| `testTheFilmMatchesTheGeneratorOnAWideSetOfColors` | 704 scene colors and 425 Apple Log tones against his Python | 0.00002 | Passes |
| `testTheTableTheAppMakesIsTheCaptainsTable` | The table the app makes from his constants against his file, at all 35,937 tones | 0.000001, the file's six places | Passes |
| `testTheTableIsReadTetrahedrally`, `testTheReaderReadsTheCaptainsTableAsSwiftDoes` | 3,000 tones between the table's own: the app's reading in Swift against the reader his `preview.py` uses, and the kernel against both | 0.000002 in Swift; 0.001 through Core Image | Passes |
| `testThePipelineDevelopsPhoneColorsAsTheCaptainsTableDoes` | 216 Display P3 phone colors through Development against his table read tetrahedrally | Mean 0.0005, 99 percent within 0.004, worst 0.01 | 0.00025, 0.0018 and 0.0057 |
| `testGraysAreReadFromTheTablesGraysAlone` | The phone's 256 neutral tones against his table | 0.002, no more than 0.001 between the channels, never a step down | 0.0009 and 0.00002 |
| `testThePipelineGivesTheNeutralValuesTheGeneratorStates` | His `SANITY` values a phone picture can reach, through Development | 0.02 | Passes |
| `testWhereTheTableCannotBeReadTetrahedrallyCoreImagesCubeReadsIt` | The same colors and grays with Core Image's own cube, the fallback | Mean 0.001, 99 percent within 0.01, worst 0.04; grays within 0.01 | 0.0006, 0.006 and 0.030; 0.009 |
| `testAPhotographsWayInUsesTheStandardsMatrices` | The matrices of section 2's way in against colour-science's | 0.00000001 | Passes |
| `MediumFormatPassesTests.testEveryConstantIsTheSpecs`, `testThePassesTheSpecLeavesOutAreOff` | Section 5's numbers; the grain under 0.6 times the 16mm's; no halation, softening, weave, flash look or print variation | Equal | Passes |
| `testThePhotographWithNoPassesIsTheTableAlone`, `testTheLensVignetteMatchesTheSpec` | A 240-pixel square test frame against the same frame through his table, without and with the vignette; the corner's light on an even gray | Mean 0.003, 99 percent within 0.01, worst 0.04; the corner within 0.002 | Passes |
| `testNothingSoftensThePicture` | The contrast of checks two pixels wide against the reference's | 2 percent | Passes |
| `testTheGrainFieldMeasuresAsTheSpecsDoes`, `testTheGrainHasTheSpecsStrengthAndEachPhotographItsOwn` | The grain's make-up and per-layer strength at the master's width; a pattern of its own for each photograph, kept by the photograph | Correlations within 0.01 and 0.02; strength within 5 percent | Passes |
| `testTheGrainIsVeryFineOnMiddleGray` | The grain's spread on an even middle gray through Development against the spec's through his table | A tenth | Passes; about 1.3 of an 8-bit step in green |
| `testTheWholeDevelopedPhotographComparesWithTheSpecs` | The whole photograph beside the spec's, by 20-pixel blocks with no edge in them | Block means within 0.006 | Passes |

His generator's self-test passes ("sanity checks passed").
His `derive.py` and `preview.py` ran unchanged apart from their output folder and printed his spec's own numbers: 6.57 from the simulation on the color chart on average, 10.21 at worst on the blue flower patch, and the same tone curve and color table.
What they printed and the preview picture are in `prd-2-slice-4-looks/calibration/`.
On three board scenes the app's renders agree with his table read in Python, by blocks, to 0.002 to 0.005 on average.

### Where the app reads his spec its own way

- **The square crop comes first.**
  His diagram crops last.
  The vignette and the grain are defined on the output frame, so the picture is the same; the app crops to the square, then develops.
- **The master is 3072 pixels square**, where his spec assumes 3024.
  Grain per pixel scales by 3072/3024, as his own rule for width has it.
- **The grain's shared part is 70 percent.**
  Section 5 does not state it and says "same shader as the 16mm spec", whose shader shares 70 percent.
- **The optional softening is off**, as his default has it.

### Where his files differ from PRD 2.1 and the ADRs

- **PRD 2.1 section 6.1: one addition, the lens vignette.**
  The PRD's row for the 6×6 lists no darkened corners; his spec gives it corners about 0.3 of a stop darker.
  It was built as message 010 said and listed for firstmate.
  The rest of the row holds, and the Load Film line for the color Film Stock is still accurate.
- **ADR 0013: outside two of the app's limits, recorded in ADR 0016.**
  Measured as `FilmLookTests` measures the fresh rule, a 3 percent black develops to 0.079, 0.077 and 0.085 where the limit is 0.06, and a 97 percent white to 0.895, 0.894 and 0.885 where the limit is 0.9.
  White is not yellowed, every test color keeps at least 86 percent of its strength, and no hue turns more than 20 degrees (blue, toward cyan).
- **ADR 0015: no difference.**
  The names in his files stay in the non-shipping probe and in comments.
- **Kept as the look only.**
  His spec also describes capture in ProRAW or DNG with the phone's own sharpening and noise reduction switched off, a 10-bit output format, and items it leaves open (real scans, a reference scanner, how warm and bright the finish is).
  None of it is built: asked, the captain answered on 2026-10-12 "Immerse 6x6 spec beyond the look: keep it as the look only".
  Capture is unchanged, and the developed master is still an 8-bit sRGB JPEG.

### The greens

On the board before his files came, he wrote of a candidate whose bands were fitted to his spec's table: "the green looks desaturated compared to the reference picture. please increase the green saturation".
Round 11 shows his exact look beside the same with the greens strengthened as that round's candidate did it, so that he can keep the note or drop it.
The mean color strength of the green pixels, in OKLab chroma:

| Scene | Phone capture | Fitted bands | Fitted, greens lifted | His exact bands | Exact, greens lifted |
| --- | --- | --- | --- | --- | --- |
| Pasture gate | 0.057 | 0.049 | 0.069 | 0.048 | 0.066 |
| Pavilion windows | 0.048 | 0.040 | 0.061 | 0.041 | 0.056 |
| Street trees | 0.043 | 0.040 | 0.053 | 0.041 | 0.052 |

His exact greens are as muted as the fitted ones his note was about, 2 to 3 degrees bluer and a little lighter; the grass in his reference picture measures 0.080.
The lift is not in his files and is not in the app; it enters only if he chooses it.

## What only the iOS simulator showed (2026-10-12)

Every render test ran on a Mac, and the review boards were rendered on one.
On 2026-10-12 the populated harness's 6×6 look test timed out on both simulators: its Film never appeared.
Running the render tests inside the simulator then failed 283 assertions that pass on the Mac.
Three things differ between Core Image on a Mac and on iOS, and each was a defect in this slice's own code.

- **A curve table of 16,384 samples renders nothing on iOS.**
  The simulator logs "Failed to render part of the image because memory requirement of -2147483648 too big" and returns an empty picture; 8,192 samples and fewer render, and a Mac renders all of them.
  Two of the negative films' curves were that size, so both negative Film Stocks developed to an empty picture in the simulator from the day the 16mm look was applied.
  The harness's 16mm test still passed, because it checks that the screens appear and not what the picture holds.
  Every curve is now 4,096 samples (`SceneLight.curveSamples`), which leaves each curve within 0.0005 of itself.
- **The tiling filter's default is not the same.**
  Left to its default, `CIAffineTile` lays a tile out one to one on iOS and shrunk to two fifths on a Mac.
  The grain tiles relied on the default, so on the Mac the negative films' grain was shrunk: neighboring pixels were alike by about 0.2 where the captain's reference gives 0.7.
  Its strength was right, so the boards' grain for those two stocks was as strong as his files say and finer.
  `GrainField.tiled` now sets the layout explicitly.
- **The other looks' grain was 1.6 times as strong on iOS.**
  Their grain was scaled by a constant measured on the Mac, through that same default.
  The same code gave an even gray 16.0 levels of grain in the simulator where the Mac gave 10.0 on the Disposable, 6.8 against 4.3 on the Instant, 12.4 against 7.8 on the 6×6's black-and-white stock, 5.5 against 3.5 on the Super 8 and 8.7 against 5.4 on the 16mm's black-and-white stock; the clumps' shape was the same on both.
  So the app in the simulator, and by the same code on an iPhone, would have developed those five looks with grain 1.6 times what the captain approved on the boards, and the simulator screenshots of 2026-10-11 show that stronger grain.
  That grain now comes from the same stored, exactly normalized noise fields as the negative films' (`GrainField`), with the clump shape the boards showed (a blur of 0.67 of the clump size), so its strength is the look's own on every renderer.

After the fix a test frame develops alike on both for every Camera and Film Stock: blocks of 40 pixels differ by 0.13 of a level at most on the two negative stocks and by 2 levels at most, which is grain, on the others, and each look's grain measures the same strength on both to a hundredth of a level.
On the Mac the fix changes two things from what the boards showed before it: the two negative stocks' grain has the clumps his files give it, and the other looks' grain is about 5 percent weaker at the smallest clump size, since the old constant ran slightly strong there.
The final boards in the repository are rendered after the fix.

What holds it now:

- `GrainFieldTests` tests each of the three: a tile laid out one to one, a negative film's grain keeping its clumps through Core Image, the other looks' clumps, and every curve's size.
- `sh Scripts/validate-local.sh` runs the render tests a second time inside the simulator, 95 tests, with every simulator run it does.
- `LegacyLookTests` stays a Mac-only check.
  Its version 2 pictures were recorded on a Mac, and version 2 is frozen with the tiling default in it, so on iOS its grain differs from those pictures as it always has; nothing about version 2 changed.

The simulator is not an iPhone: a device's own renderer is first exercised at the manual candidate.

## Review boards (QA-16)

- **How a board is made.**
  `Probes/LookReviewBoards` (commands in its README) develops each test scene through `NativePhotoRenderer.develop` and `NativeMovieRenderer.developClip`, the same calls Development makes, and `build_boards.py` lays each Camera's results beside its Format Reference imagery, the phone capture each started from and the values in `FilmLook.swift`.
  Each board was served to the captain as a Lavish review (`lavish-axi`), and his replies came back through it.
  The copies kept in `Evidence/AssetReview/looks/<camera>/index.html` are final ones, built after the last approval with `--slim --approved`: each Camera's approved look alone, rendered through the final code, with the captain's words under its title, smaller pictures and clips, and no version 2 comparison.
  The rounds themselves, with their candidates side by side, were served from the same paths and are not kept; the table below records each.
- **Reference imagery and licenses.**
  The boards use 60 reference files (photographs, film frames and short film excerpts made with each Format Reference or the closest openly licensed equivalent) and 22 test scene files, 19 of them in use as 18 photo scenes and 3 clips.
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
- **A spec the captain wrote for the 6×6.**
  On 2026-10-12 he replied on the 6×6 board with a written spec for its color Film Stock: the same negative model as the 16mm spec below, fitted to a simulation of the reference film and finished as a gentle lab-scan look.
  Its tone and color model was built from the constants in its text and holds its six stated neutral values within 0.006.
  Its hue-band values are in a generator file that was not supplied, so the candidate's bands were fitted to the spec's own table of net color changes, and the board says so.
  What it asks for beyond a look (a shipped LUT file with a log path, ProRAW capture, an output encoding) was not built; the captain later decided to keep it as the look only.
- **A spec the captain wrote for the 16mm.**
  On 2026-10-12 he replied on the 16mm board with a written spec for its color Film Stock: a low-contrast negative with layer crosstalk, printed through a steep print curve, with hue bands and a soft clip, and amounts for softness, diffusion, vignette, halation, grain and weave.
  Its color model was built as written, checked against the spec's own numbers (middle gray 0.43, black 0.015, white 0.955) and against its reference code, and rendered as candidates in the working tree only.
  The spec also asks for things beyond a look (brightness flicker on the 16mm, an aspect crop, user toggles, a second shipped look, log capture, naming); those were not built and went to firstmate as a question for the captain.
  His own files answered it later that day and supersede the spec, so the two candidates built from it left the board; their patches are kept outside the repository.
- **A look outside ADR 0013 is the captain's choice.**
  Where his notes asked for a look the fresh rule excludes, the board showed two candidates, A inside the rule and B as his notes described, and only his answer put B in the app, recorded in ADR 0016.

| Camera | Rounds | The captain's words | Outcome |
| --- | --- | --- | --- |
| 1990s Disposable | 1 (2026-10-09), 2 with A and B (2026-10-10), 3 with A alone | "fresh" | Approved 2026-10-10: A, inside ADR 0013. |
| 1970s Instant | 1 (2026-10-09), then A and B, then 2 with B alone (2026-10-10) | "the image has to be more faded", then "faded", then "approved" | Approved 2026-10-10: the faded look, ADR 0016. Its print-to-print variation stays provisional until the study of preserved 1970s prints. |
| 1960s Super 8 Home Movie | 1 (2026-10-09), 2 with A and B (2026-10-10), 3 with B alone | "muted with a glow" | Approved 2026-10-10: B, ADR 0016. |
| 6×6 Medium Format | 1 (2026-10-09) to 11 (2026-10-12) | Slider notes, then five reference pictures, a point curve, "please replicate lightroom values", then "Round 5 values are better than the lightroom values. please retry with the .xmp values", then "the blacks are too strong. please bring down the contrast to 50", then a full written spec: "regenerate with following", then "the green looks desaturated compared to the reference picture. please increase the green saturation", then his own files: "please apply attached files to immerse 6x6 portra 400 film", then "everything looks good" | Approved 2026-10-12. Round 11 showed the look from his files, applied in the app and rendered through it (A), beside the same with its greens strengthened (B) and the previous look for comparison only, and the black-and-white Film Stock as it has stood since round 4. His reply was taken as approval of the Camera as it is in the app, A for color, and he was told so on the board and that saying "B" would bring the stronger greens in. A is recorded in ADR 0016. |
| 16mm Cinema | 1 (2026-10-09) to 12 (2026-10-12) | A description of the reference film, then slider values, "please replicate the lightroom values", then four reference pictures: "get as close as possible", then a full written spec: "please try the following", then his own files: "please apply the attached for immerse - 16mm camera kodak vision3 250d", then, shown them applied, "the blacks are too strong for color. please tone it down", "please bring the black up to 4 percent" and, of the two ways to that black, "lets go with C", then "black and white looks good" | Approved 2026-10-12: the color Film Stock with the look from his files and the print's density range he chose (C), recorded in ADR 0016, and the black-and-white Film Stock, which has not changed since round 1. Round 12 showed C in the app and rendered through it, beside his black level alone raised and his files unchanged for comparison only. |

What the boards do not show: the test scenes are modern digital photographs and clips, not captures from an iPhone running the app, so the Disposable's fixed exposure, the real flash and the phone's own processing are absent.
The Movie scenes were tone-mapped to SDR first; a phone may record HDR, which the manual candidate has to check.
The warm-light 16mm scene is a daylight-balanced picture marked as recorded under 3200 K light, which exercises the fixed daylight balance but is not a capture under household bulbs.

## In the app

`Probes/PopulatedJournalHarness` develops a private Film per Camera and Film Stock through the production Development from a natural photo and clip (two of the boards' openly licensed test scenes, passed as `TEST_RUNNER_PHOTO_SOURCE` and `TEST_RUNNER_MOVIE_SOURCE`), and `PopulatedWorkflowTests.test…LookScreens` photographs the Film screen and the developed photo or Developed Movie.
All seven tests pass on an iPhone 17 Pro and an iPhone SE (3rd generation) simulator, iOS 26.5; the 22 screenshots are in `prd-2-slice-4-looks/`, named `look-<camera>-<screen>-<device>.png`.
They show the looks inside the real views, not a capture: the harness seeds its Films and never opens the camera.
All of them were captured again on 2026-10-12, after the looks the captain approved that day and after the grain was made the same on iOS as on a Mac; the earlier set showed the five older looks with grain 1.6 times too strong.

## Tests

| Where | What |
| --- | --- |
| `RenderCoreTests/LegacyLookTests` | Version 2 photos and Movie frames match the version 2 build's |
| `RenderCoreTests/NegativeFilmTests`, `ScenePassesTests`, `MediumFormatPassesTests` | The color Film Stocks of the 16mm and the 6×6 against the captain's own files: see "How the app is held to his files" under each |
| `RenderCoreTests/FilmLookTests` | Versions assigned from the Film's package; unknown version refused; every look new and distinct; fresh, not aged, with the Instant and the Super 8 held to the looks the captain chose and the color Film Stocks of the 16mm and the 6×6 left to his files; the print curve and a point curve; Disposable flash from Exif, heavy and shadow grain; grain ranking across Cameras; grain keeps the tone; soft dark edges where the format has them; the diffusion veil; Instant print variation; Super 8 jitter, flicker, dust and gate hair; 16mm red and neutral glow, weave without flicker; the daylight balance and its clip metadata |
| `RenderCoreTests/GrainFieldTests`, and the render tests rerun inside the iOS simulator | What differs between Core Image on a Mac and on iOS: see "What only the iOS simulator showed" |
| `RenderCoreTests/FilmStockRenderTests` | Black-and-white higher in contrast on a neutral ramp; versions 1, 2 and 3 renderable |
| `FilmRuntimeTests/TreatmentVersionDevelopmentTests` | Through the production processor: an unfinished roll, an Instant pack and a black-and-white 16mm reel locked before the update develop with version 2; a new roll with version 3 |
| `FilmDomainTests/SceneWhiteBalanceTests` | The recorded light round-trips through its metadata value |
| `ImmerseTests` | Load copy names the glow of the chosen stock and no film |
| `ImmerseUITests/ContentSizeTests` | The 16mm black-and-white look line at all twelve sizes |
