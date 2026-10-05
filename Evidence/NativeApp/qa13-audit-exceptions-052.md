# QA-13 Audit Fix and Exceptions 052

Captain (2026-10-02), answering Firstmate's proposal: fix the red Native validation check.
The approved approach: fix the orientation control's text sizing properly, and handle contrast findings that measure fine at rest with narrowly documented audit exceptions.
Firstmate decisions `dyn-type-band` (2026-10-02) and `dyn-type-determinism` (2026-10-03) then settled how the Dynamic Type findings that are not element defects are handled, after the real defect was fixed.
This is simulator evidence for the automated audits only.
It is not physical-device, VoiceOver, Switch Control or display acceptance, and QA-13's device and performance parts stay open.

## Reproduction

CI job `local-native` failed on every v1 run and on main (https://github.com/hcho22/Immerse/actions/runs/37012282575), in the production UI stage, on the two original audit tests only (`ci-qa13-051.md`).
It was reproduced locally on base `14328bf` with Xcode 26.5 (17F42) on a new iPhone 17 Pro simulator with iOS 26.5 (23F77), pinned to light appearance and large text like CI.
Both tests failed: three Dynamic Type findings ("Movie Orientation", "Portrait", "Landscape") at the Super 8 default audit, and contrast findings at the 16mm audits at the largest text size.
The auditor's description of the Dynamic Type finding is "User will not be able to change the font size of this SwiftUI.AccessibilityNode".
The test's screen recording shows how the check works: the auditor grows the running app's text size in place, from XS to AX XXXL, without scrolling.

## Dynamic Type: the Real Defect, Fixed

`OrientationChoice` used `ViewThatFits` with two copies of the two buttons, one side by side and one stacked.
When the text grew, SwiftUI swapped in the other copy, so the audited buttons were replaced by new ones, which the auditor reports as text that cannot change size.
The same control kept the side-by-side copy at XXXL while "Landscape" broke mid-word as "Land-scape", visible in the recording.

Fix (`App/Immerse/Sources/CameraCatalogView.swift`): a small custom `SegmentLayout` holds one set of buttons and places them side by side in equal widths while each fits on one unwrapped line, and stacked at full width otherwise.
Measured per size, the options sit side by side through AX M and stack from AX L, with no mid-word break.
The default-size control keeps its 32 pt height and look.
With the orientation block moved to the top of the section (out of the position band below), `ViewThatFits` had Portrait and Landscape flagged in 4 of 4 audits, a plain HStack in 0 of 4, and `SegmentLayout` in 0 of 2 (`qa13-audit-exceptions-052/dynamic-type-probe-runs.log`).

## Dynamic Type: the Remaining Findings Follow the Form, Not the Elements

After the fix, the Super 8 default audit still reported "Movie Orientation", "Portrait" and "Landscape".
This follows the rows' position on the screen, not the elements:

- In the two variants measured at every size (`qa13-audit-exceptions-052/dynamic-type-probe-runs.log`, probe source `DynamicTypeProbeTests.swift.txt`), the flagged elements are exactly those on screen at AX XL and scrolled out of view by AX XXXL.
  Rows already off screen at AX XL, such as Film title and Trial status, and rows still partly on screen at AX XXXL are not flagged.
  In the other eleven `Form` variants the flags likewise move with the rows in that slot.
- A plain `Text("Probe row")` placed in that slot was flagged in 4 of 4 audits, and an extra row added under the orientation block was flagged as well.
- With the orientation block moved to the top of the section, the unchanged "Handheld, pronounced grain and flicker" and "Silent capture" rows were flagged instead.
- An explicit `.font(.body)` on the label, removing the control's duplicate accessibility label, and a scaling icon font changed nothing.
- One audit with the `Form` replaced by a non-lazy `ScrollView` reported nothing at all, consistent with the lazy `Form` not redrawing rows outside the viewport while the auditor grows the text in place.
  A second such audit flagged every element, so that is neither a reliable nor a proportionate change.

Firstmate first approved exact Dynamic Type exceptions for those three elements (`dyn-type-band`).
Firstmate then required the check to flag the same elements in every run, and the Dynamic Type check on these screens cannot do that (`determinism-runs.log`, on erased simulators):

- Even with deterministic scrolling (below), one of six runs flagged Dynamic Type on "Silent capture", "Movie Orientation", "Portrait" and "Landscape" at the 16mm title pose.
- In two of four later runs (both light), the unscrolled Super 8 default audit also flagged "Handheld, pronounced grain and flicker", "Silent capture" and "Film title"; probe runs before any of this work had shown the same extra rows in two of four and one of two runs.
- One run flagged "Portrait" and "Landscape" at the 16mm command pose.

Decision `dyn-type-determinism` (Firstmate, 2026-10-03, option B): the three audits of the Form-based Load screens (`Super8-load-default`, `16mm-title-accessibility-largest`, `16mm-command-accessibility-largest`) run every audit type except Dynamic Type (`formAuditTypes` in `JournalFlowTests`, with this reason in its comment).
Dynamic Type stays in the suite's four other audits: the empty Journal at the default size, the camera catalog and the 16mm load screen at its top at the largest size, and landscape Settings at the largest size.
The three Dynamic Type exception entries and their negative test were removed.

The compensating check is `ContentSizeTests`, which measures directly instead of sweeping in place:

- It opens the Super 8 and 16mm load screens at each of the twelve sizes, one size per test, and scrolls through each screen in held drags.
- It measures 15 text elements: on Super 8 the capacity, reveal and controls rows, "Silent capture", "Movie Orientation", "Portrait", "Landscape", the "Film title" heading, the title field, the entitlement line, the note, Subscription and Load Film; on 16mm its capacity and "Deliberate framing, finer grain" rows.
  The navigation title is system text and is not included.
- Each element is measured once it is fully on screen below the navigation bar, from its frame and the height of its text in the screenshot: the rows that hold pixels far from the element's background, counting only neutral (gray-scale) pixels unless the text itself is tinted, so a tinted icon beside the text, such as the entitlement ticket, which the list keeps near one size, is not mistaken for text.
- It fails if an element is never fully on screen, if its frame leaves the screen sideways, if no text is found in its frame, if its text touches the top or bottom of its frame, if its frame gets shorter at a larger size, or if its text height does not grow by at least 4 percent at every step from L to AX XXXL.
  Every style grows by at least 6.7 percent per step from L up here (`content-size-growth-light.log`), and text clipped by a container gains only a pixel or two, so the margin also catches that clipping.
  Below L the text must only never shrink: Apple's table keeps the footnote style at 12 points at XS, S and M, and the note measures 82 px at all three.
- Each test measures one size and checks growth against whichever neighboring sizes are already measured in the same run, so a full run checks every step from XS to AX XXXL whatever order the tests run in.
- It measures in the simulator's appearance. Setting `XCUIDevice.shared.appearance` from the test did not change the app's rendering on iOS 26.5, so dark coverage of this measurement comes from running the suite on a dark simulator (below).

### Revision: No Audit Runs Dynamic Type (2026-10-04)

Decision `dyn-type-determinism` is revised by Firstmate decision `dyn-type-inplace-flake` (2026-10-04, option A), on the evidence in `scroll-indicator-drag-053.md`.
Dynamic Type also flagged correctly resizing text, from time to time, at two audits that kept it: the 16mm Load screen at its top at the largest size and the empty Journal at the default size.
Text stepped in place through every size on the Load screens measured the same as at a fresh launch, so those findings come from the auditor's timing, which a test cannot control.
Every audit in `JournalFlowTests` now runs every audit type except Dynamic Type (`auditTypes`); contrast, hit regions, element descriptions, clipped text and the other types are unchanged, and the one exception in `AuditExceptions.swift` is unchanged.
`ContentSizeTests` now measures all the text those Dynamic Type checks covered, at all twelve sizes: the Load screens as above, the empty Journal's title, the Camera catalog's headers, names and capacities, and every text element of Settings in landscape, where Settings is audited.
Navigation titles are system text and are not included, as before.
`Scripts/validate-local.sh`, and so CI, runs `ContentSizeTests` in light; its dark rerun was dropped from the gate because dark gave the same results (`scroll-indicator-drag-053.md`).
The details and runs are in `scroll-indicator-drag-053.md`.

## Deterministic Audit Poses

The largest-size test reached its two 16mm audit points with free `swipeUp()` gestures, which coast a different distance each run, so different rows sat under the navigation bar and the bottom edge at each audit.
`scrollUp(_:until:)` (then in `JournalFlowTests`, now in `UITestSupport.swift`) now scrolls in equal, slow 300-point drags that end held, so the list never coasts, with the same stop condition as before (the heading, then Load Film, can be tapped).
Across every later fresh run the command pose was identical (Load Film at y = 726.7) and the title pose put the description at y = 4.0 to 13.3, always under the bar.

Even at an identical starting pose, one run flagged four contrast findings at the command audit ("Movie Orientation", "Portrait", "Trial status unavailable", "Your Camera and Movie Orientation...") with the list about 380 points from where the test left it: a check that grows and shrinks the text in place lets the scroll offset clamp while the content is short, and the offset is not restored.
The same four findings returned once more after Dynamic Type was dropped from those audit points (run `Final-light-2`, retained in `determinism-runs.log`): its screen recording shows the text shrinking to the smallest sizes and growing back during the audit, so the clipped-text check resizes the text too.
The audit helper therefore runs every other audit type first and the two resizing types (clipped text, and Dynamic Type where it is still requested) last, so contrast is always judged at the pose the test set.

## Exceptions

`App/Immerse/UITests/AuditExceptions.swift` lists each accepted finding as an exact audit point (the name passed to the `audit` helper in `JournalFlowTests`), one audit type and one exact element label.
The helper's issue handler accepts a finding only on an exact match of all of them; a finding with no element is never accepted, and every other finding still fails the test.
The four audits that call `performAccessibilityAudit()` directly have no exceptions.

One exception remains:

| Audit point | Type | Element | Measurement |
| --- | --- | --- | --- |
| `16mm-title-accessibility-largest` | Contrast | "Deliberate framing, finer grain" | At rest 21.00:1 light, 13.94:1 dark. At the title pose the held drags leave its first lines under the navigation bar's scroll-edge blur in every run (`title-pose-held-drags-light.png`); with the bar's own title over the same strip, the faded text cannot be sampled on its own, and under earlier free-swipe poses the auditor's screenshots measured 1.73 to 18.92:1. |

Entries removed because the deterministic poses no longer produce their findings, with the measurements that had supported them:

| Audit point | Type | Element | Measurement kept for the record |
| --- | --- | --- | --- |
| `16mm-title-accessibility-largest` | Contrast | "Silent capture" | At rest 21.00:1 light, 13.94:1 dark; 20.87:1 light and 13.94 to 14.43:1 dark in the auditor's screenshots. |
| `16mm-command-accessibility-largest` | Contrast | "Movie Orientation" | At rest 21.00:1 light, 13.94:1 dark; 1.78:1 light and 4.18:1 dark under the scroll-edge blur. |
| `16mm-command-accessibility-largest` | Contrast | "Portrait" | At rest 21.00:1 light, 9.12:1 dark. |
| `16mm-command-accessibility-largest` | Contrast | "Trial status unavailable" | At rest 21.00:1 light, 13.94:1 dark. |
| `16mm-command-accessibility-largest` | Contrast | "Your Camera and Movie Orientation cannot change after loading." | At rest 21.00:1 light, 13.94:1 dark. |
| `16mm-command-accessibility-largest` | Contrast | "Film title" heading (`film-title-heading`) | At rest 21.00:1 light, 13.94:1 dark; 20.64:1 in the dark screenshot that flagged it. |
| `Super8-load-default` | Dynamic Type | "Movie Orientation", "Portrait", "Landscape" | Position findings above; Dynamic Type is no longer audited at this point. |

Contrast was measured with `qa13-measurement-049/contrast.swift.txt` on each element's reported frame (`contrast-measurements.log`).
"At rest" means the 16mm load screen at AX XXXL with the element scrolled fully between the navigation bar and 80 pt above the screen bottom (`AtRestContrastTests.swift.txt`, run temporarily, not part of the suite); screenshots `rest-*.png`.
"Load Film" and "Subscription", flagged in 049 on older source, measure 7.23:1 and 21.00:1 light and 8.24:1 and 13.94:1 dark at rest.
If any element is flagged later, that finding must be measured and re-examined, not added automatically.

## Narrowness Checks

- `AuditExceptionTests.testOnlyTheExactAuditTypeAndLabelAreAccepted` checks that another label, a longer label, no label, another audit type, a combined audit type and another audit point are all reported.
- `JournalFlowTests.testAuditStillReportsContrastFindingsOutsideItsExceptions` runs the real contrast audit at the same 16mm title pose with the description's entry withheld and expects the audit to fail, reporting exactly that element.
  If the auditor stops flagging it, this test fails, which is the signal to re-examine the entry.

## Text-Size Test History

The original `ContentSizeTests` measured only the Movie Orientation label and "Portrait" and launched the app at all twelve sizes in one test, which took 2 min 10 s in CI run 37012282575 against the script's 3-minute per-test allowance and exceeded it locally under host load.
It was first split into three tests and is now the full measurement above, one size per test; under host load locally, the largest size took about 2 minutes.

## Executed Gates

Environment: macOS 26.6.2, Xcode 26.5 (17F42), Swift 6.3.2; task-owned iPhone 17 Pro simulators on iOS 26.5 (23F77) `6CCFC689-F961-4141-AA5F-FD026F032199` (light, large text, as CI pins) and `940137D1-7B30-497B-B06D-69E54D9F6FBF` (dark), and on iOS 26.2 (23C54) `5ABCEA87-5FA7-4CCA-A4E5-3D0E39DBCF2D`.
The host ran other workloads throughout (load average up to about 400), so local durations are not CI durations.

Final source, `ImmerseUITests` six times, each on an erased simulator with a build into new derived data (`confirmation-runs.log`): three light and three dark runs each passed 17 tests with 1 expected failure (the contrast negative test).
Every run flagged exactly one finding, the 16mm description at the title pose (accepted), plus the same element in the negative test, and every run reached the same command pose.
In the same runs `ContentSizeTests` measured all 15 elements at all 12 sizes in the run's appearance; `super8-xs-l-axl-axxxl-light.png` and `-dark.png` show the Super 8 screen at XS, L, AX L and AX XXXL with nothing clipped.
Two negative checks on the same measurement code, each restored afterwards, failed as intended: a fixed 17-point font on the "Movie Orientation" label (no growth from L to XL), and the label clipped to a 20-point frame (no growth from AX M to AX L).

Fresh derived data is used for the confirmation runs because `xcodebuild test` against the shared `DerivedData/ValidationSimulator` folder sometimes ran a previously built UI-test bundle after a source change (test lists or failure messages that did not match the source); earlier records here that came from such runs say so.

Full gate on the final source, with the dark audit pass added to `Scripts/validate-local.sh`: erased simulators and no previous build products, all three simulator variables, exit 0 in 2,440 s (40.7 min) on this loaded host.

| Stage | Outcome | Local duration |
| --- | --- | --- |
| Requirement map, packages, probes, documents ZIP, unsigned builds | Passed: FilmDomain 17, MediaCatalog 4, RenderFixtures 2, RenderCore 11, FilmPersistence 29, NativeAdapters 28, EntitlementCore 6, FilmRuntime 48; TrialCommitStudy 17, DevelopmentProcessExit 3; 25-entry ZIP comparison. | |
| Populated harness (`Populated-20261003T060250Z.xcresult`) | 12 of 12 passed. | 713 s |
| Production UI, light (`Validation-20261003T061454Z.xcresult`) | 17 passed, 1 expected failure (the contrast negative test). | 720 s |
| Accessibility audits, dark (`ValidationDark-20261003T062701Z.xcresult`) | 5 passed, 1 expected failure: `JournalFlowTests` and `AuditExceptionTests` from the same build with the simulator set to dark. | 236 s |
| iOS 26.2 hosted (`StoreKit-20261003T063104Z.xcresult`) | 24 of 24 passed: 9 CaptureController, 11 Journal and 4 local StoreKit tests. | 251 s |

CI time budget: in main run 37012282575 the job reached the UI stage 15.7 minutes after `xcodebuild -version` and failed at 19.9 minutes; its populated-harness stage took about 8.9 minutes against 11.9 here.
Scaling the new stages by that ratio gives about 9 minutes for the light UI stage, 3 for the dark pass and 3 for the iOS 26.2 stage, so roughly 33 minutes for the job against its 40-minute limit; the PR's CI run gives the real figure.

| Artifact | Hash |
| --- | --- |
| `Validation-20261003T061454Z.xcresult` | `f4c58b40464d6042dac043a51f3d025832041984929dc2d8c6bf977ef3c4462d` |
| `ValidationDark-20261003T062701Z.xcresult` | `9e69bc04b51a32c37cea6a44d8b94154aff4a35ab0b939ae62290c5ad259ad1b` |
| `Populated-20261003T060250Z.xcresult` | `1e699d4bae51189237b2af0bb0f647e0f7ed6167087d73a7c2a50a02c57c3299` |
| `StoreKit-20261003T063104Z.xcresult` | `865286c6938a0526e1a8a4138fcacf465bab0eb782ef1b23924034af773b43b2` |

Earlier full gate, on commit `ef8829d` (before the determinism work), also exited 0:

| Stage | Outcome |
| --- | --- |
| Requirement map, packages, probes, documents ZIP, unsigned builds | Passed: FilmDomain 17, MediaCatalog 4, RenderFixtures 2, RenderCore 11, FilmPersistence 29, NativeAdapters 28, EntitlementCore 6, FilmRuntime 48; TrialCommitStudy 17, DevelopmentProcessExit 3; 25-entry ZIP comparison. |
| Populated harness (`Populated-20261002T220341Z.xcresult`) | 12 of 12 passed. |
| Production UI (`Validation-20261002T221453Z.xcresult`) | Passed on that source. |
| iOS 26.2 hosted (`StoreKit-20261002T222441Z.xcresult`) | 24 of 24 passed: 9 CaptureController, 11 Journal and 4 local StoreKit tests. This is the stage CI has never reached. |

After the final-source runs above, the unused identifier matching and its `AuditExceptionTests` case were removed, and the dark pass no longer reruns `AuditExceptionTests`, whose matching does not depend on appearance.
The production UI suite is now 16 tests plus the expected failure, and the dark pass 3 plus the expected failure; the records above keep the counts of the runs as executed.
A record cannot include the CI run of the commit that adds it; that run is reported on the PR.

## Limits

The auditor's internal method is not documented; the position rule and the in-place clamping are inferred from the probe variants, per-size frames, the frames in its findings and its screen recordings.
`ContentSizeTests` measures text height in screenshots, not font metrics; a change that keeps text height but breaks reading, such as truncation with an ellipsis, is not caught by it.
Setting `XCUIDevice.shared.appearance` from a test did not change the app's rendering on iOS 26.5.
`Scripts/validate-local.sh`, and so CI, runs the full UI suite in light and then the accessibility audits again from the same build with the simulator set to dark (`App/Immerse/README.md`); `ContentSizeTests` in dark was confirmed locally only.
Contrast sampling approximates the text color from the element's pixels and cannot report a ratio above the true text contrast.
Simulator rendering only.
