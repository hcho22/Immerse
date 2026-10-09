# PRD 2.1 slice 3: Film Stock

Tracker tasks CAM-16, SET-09 and DEV-11, implemented on 2026-10-08 for the captain's "please implement prd 2.1" and "go on prd 2.1" (ADR 0014; PRD 2.1 sections 3, 6.1 to 6.3, FR-01, FR-03 and FR-07).
This is simulator and software evidence only; physical-iPhone behavior stays deferred to the manual candidate.

## What changed

- **The Film records its Film Stock (CAM-16).**
  `FilmStock` (`color`, `blackAndWhite`) and `CameraPackage.filmStocks` live in `Packages/FilmDomain`.
  Only the 6×6 Medium Format and the 16mm Cinema offer one; the list follows the Camera, so a package a Film locked earlier answers the same.
  `Film.filmStock` is a constant set when the Film is loaded: a new 6×6 or 16mm Film must have one (`filmStockRequired`) and every other Camera refuses one (`filmStockNotOffered`), so no Film is loaded with the wrong choice and nothing can change it later.
- **Earlier Films (decision).**
  The Film record is JSON in the store, and a record without `filmStock` decodes with none, so the store needs no table change or data rewrite.
  An earlier 6×6 or 16mm Film keeps no Film Stock, develops in color, and stays without one when saved again.
  `FilmStockStoreTests.testAStoreWrittenBeforeFilmStockOpensWithItsFilmsHavingNone` opens a store written exactly as the previous build wrote it and captures, develops and edits its 6×6 Film.
- **One switch only: the Film (decision).**
  `Film.printProcess` (`RenderCore`) derives the print process from the Film Stock: silver gelatin for black-and-white, color otherwise.
  Development and the Darkroom both read it, so nothing else can switch a Film between color and black-and-white.
  `DevelopmentRun` no longer stores a print process; runs stored earlier carry `"printProcess":"color"`, which decoding now ignores.
- **Treatment version 2.**
  `NativePhotoRenderer.treatmentVersion` is `film-look-2-provisional`.
  It adds a black-and-white treatment for the 6×6 and the 16mm; every color treatment is version 1's, byte for byte (the color masters and Movie frames of all five Cameras hashed the same before and after the change).
  `renderableTreatmentVersions` keeps `film-look-1-provisional`, so a Film whose captures were assigned version 1 before the update still finishes developing; version 1 Films were all loaded before Film Stock and develop in color (`FilmStockDevelopmentTests.testAnEarlierFilmDevelopingWhenTheAppUpdatedFinishesInColor`).
- **Black-and-white development (DEV-11).**
  `FilmLook.monochrome` builds the picture from the capture's light, never from the color look: a panchromatic channel mix in linear light (more blue-sensitive than the eye), a print curve with a deeper toe, a steeper middle and a brighter shoulder, and coarse gray grain blended so it shows most in the middle tones and leaves black and white clean.
  Core Image's tone curve reads and writes display tones itself, so the curve takes the linear mix as it is and pivots on display mid-gray.
  The grain is a soft-light blend over display tones from an untagged tile, whose level 128 stays 0.5, the blend's neutral point, so it adds texture without moving the tone.
  The first build of this slice converted to display tones before the curve and tagged the tile as device RGB: mid-gray developed at about 174 of 255 instead of 128 on the 6×6 (161 on the 16mm), blowing out highlights; review caught it, and `testBlackAndWhiteKeepsDisplayMidGrayWithAndWithoutGrain` now fails on that chain.
  The 16mm Cinema's black-and-white Movie uses the same path per frame with fresh grain each frame, so every Developed Clip, the assembled Developed Movie (a passthrough of the clips), a Movie rebuilt after a Discard and Save Developed to Photos are monochrome.
  Every value, color and black-and-white, is in one table, `FilmLook.treatment` in `Packages/RenderCore/Sources/RenderCore/NativePhotoRenderer.swift`.
  The values are provisional (DEC-04) and tuned against review boards in slice 4 (CAM-17, QA-16); the 16mm's highlight glow (red on color, neutral on black and white) is not built for either Film Stock yet (see "Deferred to CAM-17" below).
- **Darkroom (PRD 2.1 FR-07).**
  Black-and-white 6×6 prints are silver gelatin: the Darkroom shows Chemical toning (sepia or selenium) and no Filtration.
  Color prints keep Filtration and never take toning.
  Contrast grades 0 to 5 stay on every Photo Film, and an Instant print still has no Crop.
- **Load Film (SET-09).**
  The 6×6 and 16mm Load Film screens show "Film Stock" with "Color" (selected first) and "Black and white", in the same segmented control as Movie Orientation (`SegmentedChoice` in `CameraCatalogView.swift`, which follows Dynamic Type; a title that wraps at the larger sizes stays centered).
  The choice sits under the Camera's controls line and before its look lines.
  The note under the entitlement says what loading fixes: "Your Camera and Film Stock cannot change after loading." on the 6×6 and "Your Camera, Film Stock and Movie Orientation cannot change after loading." on the 16mm.
  The Film screen names the stock under the Camera ("Black and white Film Stock").
  No other Camera shows the choice.
- **Copy.**
  Each Camera's look is now a list of lines, one Load Film row each (`lookLines` in `FilmPresentation.swift`).
  The 6×6 gives each Film Stock its own line, as PRD 2.1 section 6.1 describes it: "Borderless square picture", "Color: natural, warm color, very fine grain and gentle contrast" and "Black and white: high contrast and distinct grain".
  The 16mm keeps main's single line, "Visible grain, a red highlight glow, minor jitter and weave, soft dark edges", by firstmate's decision (option A, 2026-10-09): see "Deferred to CAM-17" below.
  No maker or film is named; the hosted copy test checks the Film Stock labels too.

## Tests

| Where | What |
| --- | --- |
| `FilmDomainTests/FilmStockTests` | Only the two Cameras offer a stock; both stocks recorded and stored; required and refused; fixed through captures, rename, Archive, early completion, Development and Discard; earlier records decode with none |
| `FilmPersistenceTests/FilmStockStoreTests` | A pre-change store opens and develops in color; each stock survives operations and reopening; the Darkroom follows the stock; a refused Film writes nothing |
| `RenderCoreTests/FilmStockRenderTests` | Gray 6×6 master; higher contrast than, and different from, the color look; distinct gray grain on an even scene; display mid-gray keeps its tone on both Cameras with and without grain while darker and lighter tones spread; color output unchanged; every 16mm clip and assembled frame gray at 24 fps; version 1 still renders |
| `RenderCoreTests/ChemicalToningTests` | Toning on a real black-and-white 6×6 master; the print process follows the stock |
| `FilmRuntimeTests/FilmStockDevelopmentTests` | Production Development, Darkroom toning and Save to Photos for a black-and-white 6×6; a black-and-white 16mm Movie end to end, including Discard reassembly and export; an earlier Film finishing a version 1 Development in color |
| `ImmerseTests` | Load copy for both Cameras; copy names no film; `testLoadFilmRecordsTheChosenFilmStockAndNeverLoadsWithoutOne` |
| `ImmerseUITests/FilmStockUITests` | The choice on both Cameras (Color first, Black and white chosen), an audit of the screen in light and dark (it joins the dark rerun in `Scripts/validate-local.sh`), loading with the suggested title, and the Film screen; no choice on the other three Cameras |
| `ImmerseUITests/ContentSizeTests` | "Film Stock", "Color" and "Black and white" at all twelve sizes |
| `PopulatedJournalHarness` | A toned black-and-white 6×6 print in the Darkroom, Photo, Film and Journal screens; the Darkroom fit at the default and largest sizes with toning; a black-and-white 16mm Developed Movie |

## Test changes worth knowing

- `audit(_:name:for:exceptions:)`, `enterFilmTitle` and `deleteFilm(titled:)` moved to `UITestSupport.swift` so the Film Stock tests share them; `deleteFilm` waits for the Film screen's actions rather than its navigation bar, which labels a 6×6 title "6 by 6".
- `FilmStockUITests` loads with the title Load Film suggests: on an iPhone SE (3rd generation) the keyboard a typed title raises covers the Load Film button, and typing there sometimes did not land in the field in time.
- `testBlackAndWhiteGrainIsDistinctOnAnEvenScene` checks that black-and-white grain is over twice the color stock's and clearly visible (above 4 levels), not a tuned number; measured with the fixed renderer after the black-and-white tone and grain fix (ffb54db), the provisional values give about 8 against the color stock's about 2 (the first build gave about 6).
- SwiftPM can keep a stale build of `Probes/TrialCommitStudy` after `Film` gains a field: its process-exit test then crashed with signal 11 until `swift package --package-path Probes/TrialCommitStudy clean`, after which all 17 tests pass (AGENTS.md already warns of stale build plans).

## Screenshots

Under `prd-2-slice-3-film-stock/`, from `FilmStockUITests` and the populated Journal harness (black-and-white tests run with the natural still and movie of `Evidence/AssetReview`), each on an iPhone 17 Pro (`iphone17pro`) and an iPhone SE (3rd generation) (`iphonese`), iOS 26.5, in light and dark: 44 files.
The 20 `bw-*` files were captured with the first build, before the black-and-white tone and grain fix (ffb54db): they show its too-bright black-and-white tones, not the fixed look, and are pending a refresh with the fixed renderer.
The other 24 files show no developed picture, so the fix does not change them.

| File stem | Shows |
| --- | --- |
| `6x6-load-color`, `6x6-load-black-and-white`, `16mm-load-color`, `16mm-load-black-and-white` | Load Film with each Film Stock selected |
| `6x6-film-screen-black-and-white`, `16mm-film-screen-black-and-white` | The loaded Film's screen naming "Black and white Film Stock" |
| `bw-6x6-film-screen` | Developed black-and-white 6×6 prints on the Film screen (before the fix; pending refresh) |
| `bw-6x6-darkroom-sepia` | The Darkroom with Chemical toning (sepia) on a black-and-white print; no Filtration tool (before the fix; pending refresh) |
| `bw-6x6-journal` | The Journal card with the toned print beside an untoned one (before the fix; pending refresh) |
| `bw-6x6-darkroom-fit-largest` | The black-and-white Darkroom at the largest text size, fitting with five tools (before the fix; pending refresh) |
| `bw-16mm-developed-movie` | A frame of a black-and-white 16mm Developed Movie on the Film screen (before the fix; pending refresh) |

## Deferred to CAM-17: the 16mm's stock-specific glow wording

PRD 2.1 section 6.2 gives the 16mm Cinema "highlight halation (a red glow on color, a neutral glow on black-and-white)", but no Film Stock renders a glow yet, and the 16mm Load Film line still reads "a red highlight glow" for both stocks.
Wording that names both glows was built and then withdrawn because of the audit finding below; firstmate chose to keep main's line (option A) and leave the stock-specific wording to the slice that renders the glow (CAM-17, slice 4), which should make the copy and the rendering agree and re-run this investigation's checks.

### The audit finding that blocked it

`JournalFlowTests.testLargestDynamicTypeCatalogAndLandscapeSettings` (16mm Load Film at the largest text size, iPhone 17 Pro, iOS 26.5) reported "Text clipped" with "No element supplied by auditor" at its 16mm title or Load Film command audit, in light and dark, for every 16mm wording that names both glows; main passed 3 of 3 on the same simulator.
An elementless finding cannot be an audit exception (`AuditExceptions.swift`), so it had to be avoided, not accepted.

What was tried, each in runs of 3 or 4 iterations on the same simulator:

| Configuration | Result |
| --- | --- |
| One 16mm line, "Visible grain, a highlight glow, red on color and neutral on black and white, minor jitter and weave, soft dark edges" (589 pt tall at the largest size) | Failed 5 of 7 |
| The same with the Load note back to main's wording | Failed 1 of 3 |
| The same without centered segment titles | Failed 2 of 4 |
| The same with the Film Stock choice hidden | Failed 4 of 4 |
| Main's 16mm line with the Film Stock choice before it, the Film Stock in the Load note and main's audit poses | Passed 4 of 4 |
| Two 16mm lines, "Visible grain, minor jitter and weave, soft dark edges" and "Highlight glow: red on color, neutral on black and white" | Failed 6 of 6 |
| Two lines with the Film Stock in a footnote under the choice and poses that keep the title field and the Load Film button whole on screen | Failed 6 of 6 |
| The same without the footnote, without the redundant `.combine` on "Silent capture", with "Glow:" for "Highlight glow:", or with the glow line set to main's wording | Failed 3 of 3 each |
| One neutral line, "Visible grain, a highlight glow, minor jitter and weave, soft dark edges", with those poses | Failed 1 of 3 |

`prd-2-slice-3-film-stock/clipped-pose-map.log` steps through the 16mm Load screen in 80 pt drags and runs the audit at each pose (`ClippedPoseDiagnostic.swift.txt`, run temporarily): the elementless finding came at only 2 of 26 poses, both with a row cut by the screen's bottom edge, but the passing configuration's own poses also had rows cut by both edges, so edge cutting is not the cause on its own.
The element was never identified; the auditor supplies none, and the accessibility trees at the failing poses show only fully drawn, unclipped text.
The at-rest contrast measurements taken along the way (`prd-2-slice-3-film-stock/contrast-measurements.log`, with `AtRestFilmStockTests.swift.txt`) all exceed 9:1, so none of the contrast findings met there was a real defect either.
The configuration shipped here is the passing one, with the 6×6's per-stock lines added, which the 16mm audits do not reach; its result in light and dark is recorded under Verification below.

## Verification

On 2026-10-08 and 2026-10-09 (Xcode 26.5, iOS 26.5 simulators, iPhone 17 Pro unless noted), with the first build, before the black-and-white tone and grain fix (ffb54db), unless noted:

- Packages: FilmDomain 23, MediaCatalog 4, RenderFixtures 2, RenderCore 30 (rerun after the fix and after the renderer's own Film Stock check was removed, leaving that rule to `FilmStockTests.testNoOtherCameraTakesAFilmStock` and `FilmStockStoreTests`), FilmPersistence 37, NativeAdapters 39, EntitlementCore 6 and FilmRuntime 52 tests pass; `Probes/TrialCommitStudy` 17 and `Probes/DevelopmentProcessExit` 3 pass; `Probes/AssetReviewGenerator`, `ExportPrivacyHarness` and `ReceiptScenarioHarness` build.
- Hosted `ImmerseTests` (without the StoreKit tests, which need the iOS 26.2 fixture runtime): 40 pass.
- `ImmerseUITests`, the whole suite in light: 65 pass; `JournalFlowTests`, `MovieCapacityUITests` and `FilmStockUITests` again in dark, as `Scripts/validate-local.sh` reruns them: 14 pass. The two 16mm largest-text audit tests passed 3 of 3 in light and 3 of 3 in dark on the shipped configuration.
- `FilmStockUITests` also passes on an iPhone SE (3rd generation) in light and dark.
- Populated Journal harness: all 23 tests pass; its black-and-white tests and Darkroom fit tests also pass in dark and on the iPhone SE in light and dark. Not rerun since the fix; its black-and-white screenshots are pending refresh.
- The color masters and Movie frames of all five Cameras hash the same before and after the change.
