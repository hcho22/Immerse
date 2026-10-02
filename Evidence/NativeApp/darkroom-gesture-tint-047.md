# Darkroom Gesture Drawing and Primary Action Color 047

Continuation from `897455e8`.
This checkpoint covers the Dodge/Burn gesture path that 044 left open, plus two color defects seen while reviewing its screenshots.
It uses the actual app views on the owned iOS 26.5 simulator with synthetic Films in the populated harness, and the production app for the empty Journal.
It is not VoiceOver, Switch Control, an all-category accessibility audit, approved Darkroom ranges, render quality or device acceptance.

## Drawn Dodge Stroke

`RetainedWorkflowTests.testDrawnDodgeStrokeChangesPrintAndPersistsAcrossRelaunch` opens a developed synthetic photo in the Darkroom, chooses Dodge / Burn and drags a finger across the print preview from 20%/30% to 80%/60% of its frame.

| Check | Observed |
| --- | --- |
| Before the drag | Undo last stroke is disabled. |
| The drag paints instead of scrolling | The print's frame is unchanged after the drag, so the `DragGesture` on the print wins over the Darkroom `ScrollView`. |
| The stroke is recorded | Undo last stroke becomes enabled. |
| The stroke renders | A screenshot of the print element differs from the one taken before the drag; the lighter diagonal band is visible in `darkroom-gesture-047/after-darkroom-drawn-stroke.png`. |
| The stroke is saved | Save returns to the photo, and the inspection bar records the saved state. |
| The stroke persists | After an ordinary relaunch of the same history, Undo last stroke is enabled in the Darkroom, so the saved recipe still holds the mask. |

The test passed on its first run (`DerivedData/DarkroomGesture-047-1.xcresult`) and again after the color change (`DarkroomGesture-047-2.xcresult`).
In the retained run below, the saved recipe holds one dodge mask of 30 points from (0.20, 0.30) to (0.80, 0.60) of the print at the provisional 0.4-stop strength, the saved print hash differs from the original, the reopened state equals the saved state, and photo 2 and the treatment assignments are unchanged.
XCUITest synthesizes the touch; this does not show how a finger, Apple Pencil or assistive technology feels on a device, and the mask's exposure strength is the provisional DEC-11 default.

## Bottom-Bar Actions Ignored the App Accent

The app's tint is green, but every bottom-bar toolbar item rendered in system blue: the Journal's prominent Start a Film button, the photo view's Darkroom button and the Darkroom's Reset to Original button.
The top-bar items were green.
Before: `darkroom-gesture-047/before-journal-bottom-bar.png` and `before-darkroom-drawn-stroke.png`; the blue Reset button also appears in 045's `darkroom-undo-edge-band-large.png`.

The root view applied `.tint(.accentColor)`.
Applying `.tint(.accentColor)` to the button itself left it blue, while `.tint(.red)` turned it red, so per-item tint works and `Color.accentColor` itself resolves to system blue inside an iOS 26 bottom toolbar.
The built app does declare `NSAccentColorName = AccentColor`.
The root now applies the concrete asset color `Color("AccentColor")`, and the populated harness root matches it.
After: `after-journal-bottom-bar.png` and `after-darkroom-drawn-stroke.png`.

## Filled Actions Were Unreadable in Dark Mode

With the accent applied, the dark-mode Start a Film button showed a pale glyph on the light mint dark-mode accent.
Looking further, the in-content filled actions already had the same problem before this change: in dark mode, Open Camera and Develop Film drew white labels on that mint fill.

| Surface | Before | After |
| --- | --- | --- |
| Open Camera and Develop Film, dark | White label on fill `#7ED8BA`: 1.69:1 (`before-film-detail-dark.png`) | White label on fill `#137861`: 5.4:1 (`after-film-detail-dark.png`, `after-develop-film-dark.png`) |
| Start a Film glyph, dark | `#B6FFF3` on `#7CD7B9`: 1.51:1, sampled after the root tint change (`intermediate-root-tint-dark.png`) | `#AAFFF7` on `#137760`: 4.79:1; the fill is 3.84:1 against the black background (`after-journal-primary-dark.png`) |
| Start a Film, light | System blue | Light glyph on deep green (`after-journal-primary-light.png`) |

Ratios are WCAG relative-luminance contrast of pixels sampled from the retained screenshots, except the white labels, which use the sampled fill and pure white.
No single accent works for both uses: green text on black needs a light green, and a white label needs a dark one.
A new `PrimaryAction` color (light `#09634E`, dark `#137861`) and a `primaryAction()` modifier now style the three filled actions, while the accent keeps its existing light and dark values for text and icons.
`.foregroundStyle` on the toolbar button had no effect, because the bottom bar picks its own glyph color from the tint.

These are reversible engineering choices for DEC-01 visual review, not approved brand colors.
No automated contrast check was added for these screens, because further accessibility analyzer variants are paused; the screenshots and measurements are the evidence.

## Source Change

- `App/Immerse/Sources/ImmerseApp.swift`: root tint `Color("AccentColor")`.
- `App/Immerse/Sources/FilmPresentation.swift`: `View.primaryAction()`.
- `App/Immerse/Sources/Assets.xcassets/PrimaryAction.colorset`.
- `JournalView` Start a Film and `FilmDetailView` Open Camera and Develop Film use `primaryAction()`.
- `Probes/PopulatedJournalHarness/Sources/WorkflowHarnessApp.swift`: the same concrete root tint.
- `Probes/PopulatedJournalHarness/Tests/RetainedWorkflowTests.swift`: the drawn-stroke test.
- `Probes/PopulatedJournalHarness/inspect-retained.rb` and `README.md`: six retained scenarios, with content checks for the 044 controls and 047 stroke histories.

No behavior, persistence or accessibility identifier changed.

## Executed Gates

Environment: macOS 26.6.2 (25G83), Xcode 26.5, Swift 6.3.2, owned iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, iOS 26.5 (23F77).
UI runs were pinned to light appearance and large text, except the explicit dark captures, and the simulator's own settings were restored after each run.
Production Journal screenshots come from installing the unsigned simulator build and launching it with `xcrun simctl`.

| Run | Outcome |
| --- | --- |
| `DarkroomGesture-047-1.xcresult` | Drawn-stroke test passed before the color change. |
| `DarkProminent-047-1.xcresult` (dark) | Functional pass; screenshots show white on mint for Open Camera. |
| `DarkroomGesture-047-2.xcresult` | Drawn-stroke test passed with the concrete root tint. |
| `DarkProminent-047-2.xcresult` (dark) | Functional pass with `primaryAction()`; readable filled actions. |
| Unsigned generic-device app build | Exit 0 (`darkroom-gesture-047/affected-stages.log`). |
| `Populated-047.xcresult` | Full populated harness, 11 passed, including the new drawn-stroke test. |
| `Validation-047.xcresult` (`-only-testing:ImmerseUITests`) | The denied-Camera test passed. The two original tests failed on audits: Super 8 "Movie Orientation" Dynamic Type, two contrast findings in the handled 16mm audits, and four "Hit area is too small" findings from the unhandled 16mm load-screen audit, which reports no elements. |
| `HitArea-047-current-1` and `-2` | `testLargestDynamicTypeCatalogAndLandscapeSettings` alone on the final source: no hit-area findings; two and one contrast findings. |
| `HitArea-047-oldtint-1` | The same test with the root tint temporarily set back to `.tint(.accentColor)`: four hit-area findings and two contrast findings. |

| `SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/PopulatedJournalHarness/run-retained.sh 047-retained-1` | Exit 0: all six retained tests passed from a shut-down simulator (`Evidence/PopulatedJournal/037/047-retained-1/`, 17 MB of summaries, attachments and copied histories). |
| `ruby Probes/PopulatedJournalHarness/inspect-retained.rb Evidence/PopulatedJournal/037/047-retained-1` | All six histories pass (`inspection.txt`). The first attempt failed because I assumed each inspection carried the test's attachment name; the harness records them all as `explicit`, so the inspector now tells the three developed-photo histories apart by their reason sequence. It had required exactly four histories, which 044's added Darkroom-controls test already broke. |

The retained run's `source.sha256` hashes the working tree before the harness README and inspector edits; neither file is compiled.

The hit-area findings therefore vary from run to run and also occur with the previous tint; they are not caused by this change.
They join the retained, unwaived QA-13 audit failures; no audit was filtered, re-posed or excepted.

Result bundle hashes, computed as the SHA-256 of sorted per-file SHA-256 lines inside each bundle:

| Artifact | Hash |
| --- | --- |
| `DarkroomGesture-047-1.xcresult` | `c831443d024da8a72a3974e7eaef4a984f7faa989c9658b23e11d4329a8a13cf` |
| `DarkroomGesture-047-2.xcresult` | `a1305ffa8237721cbd4598ff33f785c3e0e2ffba9ef943a6dde2912bd2422eed` |
| `DarkProminent-047-1.xcresult` | `8327f2fda317b8c6c7773b5e05a6450597cf6a48d8ddc42e94bbaa022c13c8d1` |
| `DarkProminent-047-2.xcresult` | `95b708261977edb2a17c1e57f24c6ddec56930cc7cf708021df0f30d98b70e42` |
| `Populated-047.xcresult` | `e4194b695ded17617d7243b835e184fd4c5a20056d683430a3b651a593d52b0e` |
| `Validation-047.xcresult` | `495eb635940fe8780f9a80dc05aee2de42a89bf85cc97467897cb14311404cd2` |
| `HitArea-047-current-1.xcresult` | `209e0bc8176c821e059ec61a206cce467f8d728587dd33795c51572e890f7422` |
| `HitArea-047-current-2.xcresult` | `a7844aaf33ac9552cb7a463397958c691464b7e57df4eaf91356d94107ae7d84` |
| `HitArea-047-oldtint-1.xcresult` | `9a14b2b5db57cbe494151db3466579c2c9ea5da88667836b55f5170221470157` |
| `Populated037-047-retained-1.xcresult` | `e699d94cd80f71b175b6e01e6da485487e43e0b56f007b8e6bdf0c4aeeeca9f7` |

Changed sources are hashed in `darkroom-gesture-047/source.sha256` against base `897455e8`.
No package or hosted-test source changed, so those 046 gates were not rerun; the UI-suite build compiled the hosted test target against this source.
The evidence map's DRK-05 and QA-04 rows changed; the requirement-map check and the regenerated 25-entry documents ZIP comparison passed.

## Limits

These are simulator screenshots and synthetic touches.
Dark-mode screens other than the Journal and Film detail were not reviewed, and Increase Contrast, Smart Invert and device displays were not checked.
The original QA-13 audit findings and assistive-technology acceptance remain open.
