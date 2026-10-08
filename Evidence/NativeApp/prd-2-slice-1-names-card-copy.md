# PRD 2.1 slice 1: names, capacity, the Instant card, no crop, copy

Tracker tasks CAM-13, CAM-14, DRK-09, DRK-10 and CAM-15, implemented on 2026-10-07 for the captain's "please implement prd 2.1".
This is simulator and software evidence only; physical-iPhone behavior stays deferred to the manual candidate.

## What changed

- **Names and capacity.**
  `CameraCatalog` names the 6×6 Medium Format and the 16mm Cinema without a decade, and the 16mm Cinema holds 167 seconds (2:47) at 24 frames per second.
  A Film persists its whole `CameraPackage`, so a Film loaded earlier keeps "1960s 16mm Cinema" and 165 seconds.
  `PRD2Slice1Tests` in `Packages/FilmPersistence` reopens the store and checks both.
  Each Camera's short name was already decade-free; the 6×6's now uses the multiplication sign.
  The product spells it "6×6" (PRD 2.1) and VoiceOver reads it as "6 by 6" wherever it is shown; code identifiers keep `6x6`.
- **The Instant card.**
  `InstantPrintCard` (`Packages/RenderCore/Sources/RenderCore/NativePhotoRenderer.swift`) puts the 2048 x 2048 picture on a clean white card, 2282 x 2774 pixels in all.
  The proportions come from the Instant's Format Reference, the original 1970s integral print: a 79 mm picture on an 88 x 107 mm card, with 4.5 mm top and side borders (117 px) and a 23.5 mm bottom border (609 px).
  The card is added after the Film Look, which is not retuned.
  It is part of the developed master, so the Journal, the Film screen, the Photo screen, the Darkroom and Save Developed to Photos show it without a special case.
- **Darkroom and the card (decision).**
  Print exposure, contrast grade, color filtration and Dodge/Burn reach the picture only and leave the card white, because the card is unexposed paper, not part of the exposure.
  Dodge/Burn points are fractions of the picture, and the Darkroom's brush surface covers the picture only.
  A master that is not card-sized is not a supported state (no release has shipped one): `print` fails with `NativeRenderError.instantMasterWithoutCard`, for an edit, a reset and an export alike, rather than render without a card or map a Dodge/Burn point onto a card that is not there.
- **No crop for an Instant print.**
  `NativePhotoRenderer.validate` rejects any Instant recipe that carries a crop, so `saveDarkroomRecipe` and `print` reject it too, and the Darkroom hides its Crop tool for an Instant print.
  Every other tool stays.
- **Contrast and toning (DRK-10).**
  Grades 0 to 5 were already offered on every Photo Film and stay; tests now cover color, Instant and 6×6.
  Toning is rejected under the color print process for every Photo Camera and Chemical toning is not shown, so no Film offers it until the black-and-white Film Stock (slice 3).
- **Catalog and Load Film copy (CAM-15).**
  Each Load Film screen shows the Camera's controls line, its developed-look line and, for the 6×6, that its viewfinder shows the scene reversed left to right while the photos are not.
  The wording follows PRD 2.1 sections 6.1 and 6.2 and names no maker or film.
  Slice 2's capture behavior (the Disposable's borderless 3:2 frame, fixed exposure and live low-light cue, the Super 8's fixed focus and the 6×6's reversed viewfinder) is merged, so the copy states it for every Camera as PRD 2.1 sections 6.1 and 6.2 do.
  Only the Film Stock choice, which arrives in slice 3, is left out.
  No Camera sample media is configured, so there is no separate sample copy.

## Test changes worth knowing

- The accepted contrast finding in `AuditExceptions.swift` moved from the 16mm controls line to the new look line below it: at the largest text size the held drags now stop with the look line's first lines under the navigation bar's scroll-edge blur.
  The look line was measured on its own at rest, as 052 measured the line it replaced: 21.00:1 light and 13.94:1 dark (iPhone 17 Pro, iOS 26.5, AX XXXL).
  It was scrolled fully between the navigation bar and 80 pt above the screen bottom by the diagnostic `prd-2-slice-1-names-card-copy/AtRestLookLineTests.swift.txt` (run temporarily, not part of the suite) and measured with `qa13-measurement-049/contrast.swift.txt`; the values, with the controls line above it for comparison, are in `prd-2-slice-1-names-card-copy/contrast-measurements.log`, and the screenshots are `rest-16mm-look-largest-light.png` and `-dark.png`.
- `JournalFlowTests` scrolls to Load Film before asserting it exists, since the longer Camera description pushes the lazy Form's last row off the first screen.
- `ContentSizeTests` measures the new Look lines on the Super 8 and 16mm Load screens.
- `PopulatedJournalHarness` gained `testInstantPrintShowsItsCardAndTheDarkroomOffersNoCrop` and a check that a color Film keeps Crop and Contrast with no toning.

## Screenshots

Taken in the iOS 26.5 simulator from the UI tests and the populated Journal harness.
The harness shots are on an iPhone SE (3rd generation), the smallest supported iPhone.

| File (under `prd-2-slice-1-names-card-copy/`) | Shows |
| --- | --- |
| `instant-film-screen-se-light.png`, `-dark.png` | Instant prints in the Film screen, in cells that match the card, with a hairline edge |
| `instant-photo-screen-se-light.png`, `-dark.png` | A print on its card in the Photo screen, with margin and shadow |
| `instant-darkroom-se-light.png`, `-dark.png` | The Darkroom for an Instant print: four tools, no Crop |
| `darkroom-fit-se-{instant,disposable,6x6}-{default,largest}-{light,dark}.png` | The Darkroom at rest at the default and the largest text size: print fully below the bar, margins kept, nothing overlapping |
| `instant-darkroom-dodge-burn-se-light.png`, `-dark.png` | Dodge/Burn at rest: its controls stop above the Reset button's bar, and the rest scroll into view |
| `super8-load-iphone17.png`, `16mm-load-largest-iphone17.png` | Load Film copy |
| `6x6-load-extra-small-iphone17.png` | 6×6 Load Film with the reversed-viewfinder note |
| `catalog-largest-iphone17.png` | The catalog at the largest text size |
| `rest-16mm-look-largest-light.png`, `-dark.png` | The 16mm look line at rest at the largest text size, where its contrast was measured |

## Follow-up fixes (captain's review of the first screenshots)

- **Film and Journal thumbnails.**
  An Instant print's cell now has the card's aspect (`CameraPackage.printAspectRatio`), so there are no gray bars beside the card, and the card has a hairline edge in light and dark.
  Every other Camera keeps a square cell, so a Disposable's 3:2 picture is letterboxed in it as before.
- **Darkroom layout.**
  The print preview is scaled to the height the controls leave at their full size (at least 160 pt), so the whole print, an Instant card included, sits below the navigation bar at every text size, and the Exposure tool never needs scrolling on the iPhone SE.
  Tools with more controls (Filtration, Dodge/Burn) scroll once the print is at its smallest.
  The scroll area stops 4 pt above the floating Reset to Original bar, so no control rests under the bar, and the last row scrolls fully clear of it, ending 16 pt above it.
  Controls that run past the scroll area at rest fade out over its 12 pt bottom margin rather than end in a sliver of a slider.
  The bar is the sheet's bottom safe area (86 pt on the iPhone SE), and hit-testing the window showed that it takes every tap across the full screen width from its top edge, 15 pt above the Reset button.
  Before, the scroll view reached under the bar: at rest on the iPhone SE, Dodge point, Undo last stroke and part of a slider showed there and looked usable, but taps on them reached the bar.
  The 48 pt formerly kept clear under the controls counted the bar a second time, since the safe area already leaves it out, so the print is now up to 48 pt taller.
  The tool icons stop growing at the largest ordinary Dynamic Type size, so five tools always fit between the 16 pt side margins; before, at the largest accessibility size they overflowed and widened the whole column.
  The Darkroom fit tests (populated Journal harness, one per Camera and text size, from `testDarkroomFitsAnInstantPrintAtTheDefaultSize` to `testDarkroomFitsA6x6PrintAtTheLargestSize`) check, for an Instant, a Disposable and a 6×6 print at the default and the largest text size, that the print lies entirely below the navigation bar (with clear space) and inside the screen, above the controls and not squeezed away, that the tools and slider keep their side margins, that the controls clear the Reset button, and that a swipe cannot move the print under the bar.
  With Dodge/Burn selected, they also check that no hittable control shows under the Reset button's bar at rest, and that once held drags scroll the last row clear, Dodge point and Undo last stroke take their taps.
  With the scroll view reaching under the bar, they failed 12 times: Dodge point, Undo last stroke and a slider at the default size, and a slider at the largest size, for each Camera.
  Only the tool row, the tool's title and its controls are measured (`DarkroomLayout` in `PhotoView.swift`): rendering shows over the print and an error between the print and the controls, so neither resizes the print or rescales a Dodge/Burn stroke.
  `testADarkroomErrorNeitherResizesNorMovesThePrint` (`JournalIntegrationTests`) hosts the layout, shows and clears an error, and checks that the print keeps its frame while only the controls move; with the error back among the measured controls it fails, the print shrinking from 610.7 to 550.3 pt.
- **6×6 spelling.**
  The display name and short name use the multiplication sign, and VoiceOver reads "6×6" as "6 by 6" (`SpokenText` in `FilmPresentation.swift`) in both names and in a shown Film title, such as the suggested "6×6 - Roll #01", in the Journal row and the Film screen's title (`Film.titleText`).
  The saved title stays as typed.
  The two title fields (Load Film and Rename) are excepted: VoiceOver reads and moves through an editable field's own characters, so a spoken form there would not match the text being edited.

## Results

- Package tests: FilmDomain, FilmPersistence, RenderCore, FilmRuntime, MediaCatalog, NativeAdapters, EntitlementCore and RenderFixtures pass; so do the TrialCommitStudy and DevelopmentProcessExit probes, the AssetReviewGenerator build, and the requirement-map and document-package checks.
- iOS 26.5 simulator (iPhone 17): `ImmerseTests` pass except the four local StoreKit tests, which cannot activate their fixture on 26.5 (the known gate, run on 26.2 in CI); `JournalFlowTests`, `MovieCapacityUITests` and `AuditExceptionTests` pass in light and in dark; all 12 `testLoadScreenTextAt*` and all 12 `testJournalAndCatalogTextAt*` `ContentSizeTests` pass.
- The populated Journal harness (iPhone SE 3rd generation, light and dark) passes the Instant card test, the color-Film Darkroom test and the Darkroom fit test.

## Not covered

No physical iPhone, no real camera capture, and no review of the Instant look against its Format Reference (the later looks slice).
The Catalog's "Choose a Camera" title truncates and "Disposable" hyphenates at the largest accessibility size; both predate this slice.

## Re-verification of the Darkroom bottom margin

After the pipeline's fix commit (`6f0552d`, merged with main as `599502b`) the iPhone SE (3rd generation) harness ran in light and in dark: the Darkroom fit test with its Dodge/Burn checks, the Instant card test, the early photo test and the three retained Darkroom tests all pass, and the Darkroom fit, Dodge/Burn and Instant Darkroom screenshots above were captured again from that run.
On the iPhone 17 the hosted suite passes, including the Darkroom error test, apart from the four local StoreKit fixture tests.
`testLargestDynamicTypeCatalogAndLandscapeSettings` reported "Text clipped" once while the harness was running on the same machine and passed twice when rerun alone.

The Darkroom fit test then ran six full app sessions in one test, so it was split into one test per Camera and text size to keep each well inside CI's 180 s per-test allowance (`Evidence/NativeApp/ci-flakes-057.md`).
On the iPhone SE (3rd generation, iOS 26.5, light) the six tests pass in 38 to 64 s each, about 292 s together.
