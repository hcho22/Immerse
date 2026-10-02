# QA-13 Audit Fix and Exceptions 052

Captain (2026-10-02), answering Firstmate's proposal: fix the red Native validation check.
The approved approach: fix the orientation control's text sizing properly, and handle contrast findings that measure fine at rest with narrowly documented audit exceptions.
Firstmate decision `dyn-type-band` (2026-10-02) then approved a narrow Dynamic Type exception for a finding shown below to be a position artifact, after the real defect was fixed.
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

## Dynamic Type: the Remaining Finding, a Position Artifact

After the fix, the Super 8 default audit still reports "Movie Orientation", "Portrait" and "Landscape".
This follows the rows' position on the screen, not the elements:

- In the two variants measured at every size (`dynamic-type-probe-runs.log`, probe source `DynamicTypeProbeTests.swift.txt`), the flagged elements are exactly those on screen at AX XL and scrolled out of view by AX XXXL.
  Rows already off screen at AX XL, such as Film title and Trial status, and rows still partly on screen at AX XXXL are not flagged.
  In the other eleven `Form` variants the flags likewise move with the rows in that slot.
- A plain `Text("Probe row")` placed in that slot was flagged in 4 of 4 audits, and an extra row added under the orientation block was flagged as well.
- With the orientation block moved to the top of the section, the unchanged "Handheld, pronounced grain and flicker" and "Silent capture" rows were flagged instead.
- An explicit `.font(.body)` on the label, removing the control's duplicate accessibility label, and a scaling icon font changed nothing.
- One audit with the `Form` replaced by a non-lazy `ScrollView` reported nothing at all, consistent with the lazy `Form` not redrawing rows outside the viewport while the auditor grows the text in place.
  A second such audit flagged every element, so that is neither a reliable nor a proportionate change.

The elements do follow Dynamic Type: in the per-size sweep the label is 20 pt tall at L and 48 pt at AX XL and the options 29 pt and 56 pt, and `ContentSizeTests` measures label and option text growth from XS through AX XXXL.

## Exceptions

`App/Immerse/UITests/AuditExceptions.swift` lists each accepted finding as an exact audit point (the name passed to the `audit` helper in `JournalFlowTests`), one audit type and one exact element label, plus the exact identifier where another element shares the label.
The helper's issue handler accepts a finding only on an exact match of all of them; a finding with no element is never accepted, and every other finding still fails the test.
The four audits that call `performAccessibilityAudit()` directly have no exceptions.

| Audit point | Type | Element | Measurement |
| --- | --- | --- | --- |
| `Super8-load-default` | Dynamic Type | "Movie Orientation" | Position artifact above; grows at every size. |
| `Super8-load-default` | Dynamic Type | "Portrait" | Same; flagged only in this position since the fix. |
| `Super8-load-default` | Dynamic Type | "Landscape" | Same. |
| `16mm-title-accessibility-largest` | Contrast | "Deliberate framing, finer grain" | At rest 21.00:1 light, 13.94:1 dark. At the pose it is under the navigation bar's scroll-edge blur: 1.75 to 7.21:1 light, 3.66 to 10.97:1 dark. |
| `16mm-title-accessibility-largest` | Contrast | "Silent capture" | At rest 21.00:1 light, 13.94:1 dark. 20.87:1 light and 13.94 to 14.43:1 dark in the auditor's own screenshots. |
| `16mm-command-accessibility-largest` | Contrast | "Movie Orientation" | At rest 21.00:1 light, 13.94:1 dark. At the pose it is under the scroll-edge blur: 1.78:1 light, 4.18:1 dark. |
| `16mm-command-accessibility-largest` | Contrast | "Portrait" | At rest 21.00:1 light, 9.12:1 dark; the same in the auditor's screenshots. |
| `16mm-command-accessibility-largest` | Contrast | "Trial status unavailable" | At rest 21.00:1 light, 13.94:1 dark; the same in the auditor's screenshots. |
| `16mm-command-accessibility-largest` | Contrast | "Your Camera and Movie Orientation cannot change after loading." | At rest 21.00:1 light, 13.94:1 dark; the same in the auditor's screenshots, where the row runs past the bottom edge. |
| `16mm-command-accessibility-largest` | Contrast | "Film title" heading, identifier `film-title-heading` | At rest 21.00:1 light, 13.94:1 dark. Flagged in one dark run whose command pose scrolled further, putting it under the scroll-edge blur (20.64:1 in that screenshot). The title field shares the label, so the identifier must match too. |

Contrast was measured with `qa13-measurement-049/contrast.swift.txt` on each element's reported frame (`contrast-measurements.log`).
"At rest" means the 16mm load screen at AX XXXL with the element scrolled fully between the navigation bar and 80 pt above the screen bottom (`AtRestContrastTests.swift.txt`, run temporarily, not part of the suite); screenshots `rest-*.png`.
Every listed element is above 4.5:1 at rest in both appearances, and no listed element is below 9.12:1 there.
Only elements flagged on this source in local audit runs (seven light, three dark) or in CI runs 36979920415 and 36995398670 are listed.
How far the test's swipes scroll before the command audit varies from run to run, so which rows sit under the top or bottom edge there varies too; that is how the "Film title" heading came to be flagged in only one dark run.
"Load Film" and "Subscription", flagged in 049 on older source, measure 7.23:1 and 21.00:1 light and 8.24:1 and 13.94:1 dark at rest but are not listed; if they or any other element are flagged later, that finding must be measured and re-examined, not added automatically.
The same applies if row order or copy on the Super 8 load screen changes and a different element falls into the Dynamic Type band.

## Narrowness Checks

- `AuditExceptionTests.testOnlyTheExactAuditTypeAndLabelAreAccepted` checks that another label, a longer label, no label, another audit type, a combined audit type and another audit point are all reported.
- `AuditExceptionTests.testAnIdentifiedExceptionNeedsTheExactIdentifier` checks that an entry with an identifier rejects the same label with another identifier or none, so the title field is not covered by the heading's entry.
- `JournalFlowTests.testAuditStillReportsFindingsOutsideItsExceptions` runs the real Super 8 Dynamic Type audit with only the label's entry and expects the audit to fail, reporting exactly "Portrait" and "Landscape".
  If the auditor stops flagging them, this test fails, which is the signal to re-examine and remove the Dynamic Type entries.

## Text-Size Test Timing

`ContentSizeTests` launched the app at all twelve sizes in one test, which took 2 min 10 s in CI run 37012282575 against the script's 3-minute per-test allowance, and exceeded it locally under host load.
It is now three tests: XS to L, L to XXXL, and XXXL to AX XXXL.
They cover all twelve sizes, and their overlapping sizes chain the same growth the single test asserted, plus label growth from L to XXXL.
With two tests of seven launches, the standard-size half still exceeded the allowance locally at about 25 s per launch under host load, while the accessibility half passed in 2 min 51 s.

## Executed Gates

Environment: macOS 26.6.2, Xcode 26.5 (17F42), Swift 6.3.2; new task-owned iPhone 17 Pro simulators on iOS 26.5 (23F77) `6CCFC689-F961-4141-AA5F-FD026F032199` (light, large text, as CI pins) and iOS 26.2 (23C54) `5ABCEA87-5FA7-4CCA-A4E5-3D0E39DBCF2D`.
The host ran other workloads throughout (load average up to about 400), so local durations are not CI durations.

Full `sh Scripts/validate-local.sh` with all three simulator variables, on commit `ef8829d`, exited 0:

| Stage | Outcome |
| --- | --- |
| Requirement map, packages, probes, documents ZIP, unsigned builds | Passed: FilmDomain 17, MediaCatalog 4, RenderFixtures 2, RenderCore 11, FilmPersistence 29, NativeAdapters 28, EntitlementCore 6, FilmRuntime 48; TrialCommitStudy 17, DevelopmentProcessExit 3; 25-entry ZIP comparison. |
| Populated harness (`Populated-20261002T220341Z.xcresult`) | 12 of 12 passed. |
| Production UI (`Validation-20261002T221453Z.xcresult`) | 7 passed and 1 expected failure: both original audit tests, the declined-Camera test, three `ContentSizeTests`, the matcher test, and `testAuditStillReportsFindingsOutsideItsExceptions` failing as designed on "Portrait" and "Landscape". |
| iOS 26.2 hosted (`StoreKit-20261002T222441Z.xcresult`) | 24 of 24 passed: 9 CaptureController, 11 Journal and 4 local StoreKit tests. This is the stage CI has never reached. |

The earlier run on the previous working tree (`validate-local-1`) passed every stage before the UI stage, which failed only because the then-two-part `ContentSizeTests` exceeded the allowance; that led to the three-part split.

After `ef8829d`, a dark run flagged the "Film title" heading as described above; its entry and identifier matching were then added.
On that final source `ImmerseUITests` passed in light on `6CCFC689` (`UI3-light`) and in dark on a fresh iOS 26.5 simulator `940137D1-7B30-497B-B06D-69E54D9F6FBF` (`UI3-dark`): 8 passed and 1 expected failure each.
Two earlier dark runs on `6CCFC689` ran a previously installed test bundle after the appearance switch (their test lists did not match the source), which is why the final dark run used a fresh simulator; the app code in those bundles matched, so their findings are still recorded above.
`super8-xs-l-axl-axxxl-light.png` and `-dark.png` show the Super 8 load screen at XS, L, AX L and AX XXXL: the options sit side by side through the default size, stack at accessibility sizes, and nothing is clipped.

Result bundle hashes (SHA-256 of sorted per-file SHA-256 lines):

| Artifact | Hash |
| --- | --- |
| `Validation-20261002T221453Z.xcresult` | `103b200ec79c32166a00286f4c0f605a359b891c4c26624c36da121926454f69` |
| `Populated-20261002T220341Z.xcresult` | `721e64fb965d9e8df03e5948d28c6206b38c8987363ef5df0ef3b14755ff720a` |
| `StoreKit-20261002T222441Z.xcresult` | `1839c8a9286881743479efa11819777e83408f56bf7eb5411e431471c672474b` |

A record cannot include the CI run of the commit that adds it; that run is reported on the PR.

## Limits

The auditor's internal method is not documented; the position rule is inferred from the probe variants and per-size frames, which it fits in every recorded run.
Contrast sampling approximates the text color from the element's pixels and cannot report a ratio above the true text contrast.
Simulator rendering only.
