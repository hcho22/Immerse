# Visual Sweep and Capture Screen Layout 048

Continuation from `96799ed`.
After 047 found dark-mode contrast defects that no test had seen, this checkpoint reviews the actual screens in dark and light appearance and the capture screen on three iPhone sizes.
It also drives reopening an existing Film's camera with Camera access declined through the actual views, which 045 and 046 left at controller level.
It is not VoiceOver, Switch Control, an all-category accessibility audit, device display or capture acceptance.

## Review Method

- The full populated harness ran in dark appearance at large text (`DerivedData/DarkSweep-048-1.xcresult`, all tests passed) and its 26 screenshots were reviewed: Journal, Film detail for every scenario, Instant, Movie, Darkroom, Originals, Photos-denied alerts and Settings.
- Production-only screens (empty Journal, Camera catalog, load screen, Subscription, Settings and Archive) were captured in dark and light with a temporary UI test that was removed afterwards; it made no assertions and is not part of the suite (`DerivedData/Sweep-048-dark.xcresult`, `Sweep-048-light.xcresult`).
- The capture screen was captured on the owned iPhone 17 Pro (402 x 874 pt) and on two task-owned iOS 26.5 simulators created for this check: iPhone 13 Pro (390 x 844 pt, the captain's device size) and iPhone SE (3rd generation) (375 x 667 pt, the smallest supported screen).

## Defects Found and Fixed

| Defect | Before | Fix and after |
| --- | --- | --- |
| Settings and Camera Samples Done buttons unreadable in dark mode | iOS 26 fills an icon-only confirmation with the tint, so the white checkmark sat on the light mint accent, as with the 047 filled actions. | `.tint(.primaryAction)` on both; white on deep green, 5.4:1 by the 047 values. The color now lives in `Color.primaryAction`, used by `primaryAction()` too. |
| The shutter was below the fold on smaller iPhones | With Camera declined, the shutter's bottom edge was at 909 pt on the 844 pt iPhone 13 Pro and at 863 pt on the 667 pt iPhone SE (`Shutter-048-red-*.xcresult`). On the SE it is below the fold even without any status text, and at larger text sizes on every iPhone. On the iPhone 17 Pro it touched the bottom edge. | The switch-lens, shutter and flash row is pinned in a bottom safe-area bar; the rest of the screen scrolls. |
| Declined-Camera guidance hidden and a dead end | Moving the shutter showed that status text lived below the viewfinder, so the guidance scrolled out of view. The only action was Resume Camera, which cannot succeed while access is off, although the text says to allow Camera in iPhone Settings. | Status (Pack or Film complete, failure text, message, Open iPhone Settings for a declined camera, Resume Camera) now sits above the viewfinder, centered. |

After the fix the denied-reopen test passes on all three sizes with three repetitions each (`Shutter-048-green3-*.xcresult`); screenshots are `visual-sweep-048/after-capture-denied-iphone-se.png`, `-iphone-13-pro.png` and `-iphone-17-pro.png`.
Before: `capture-camera-denied-light.png` and `capture-camera-denied-dark.png` on the iPhone 17 Pro.

## Denied Camera on Reopen in the Actual Views

`CameraPermissionWorkflowTests.testDeniedCameraOnReopenShowsGuidanceAndLeavesFilmUnchanged` resets the harness's Camera authorization, opens an existing Film with 25 exposures left and taps Open Camera.
An interruption monitor declines the actual system request; the test asserts that it ran.
The capture screen then shows "Camera access is off. Allow Camera for Immerse in iPhone Settings. Saved captures are unchanged." and Open iPhone Settings, both on screen without scrolling, with Resume Camera; the shutter is disabled and fully on screen.
After Done, the Film still shows 25 exposures left, Open Camera, and no revealed photo.
The harness gained a Camera usage key for this test only; no other test opens the camera.
The first attempt on the iPhone SE failed because one tap ran before the slower simulator showed the request, so the monitor never fired; the test, and 046's production Load Film test, now tap until the guidance appears.

## Observations Not Changed

- Movie waste reads "164.663 seconds wasted" with millisecond precision, while the catalog shows "3:20 of film". This is DEC-01 copy, recorded for review.
- Photo tiles in Film detail letterbox 4:3 frames in square cells with a neutral band. This is the existing contact-sheet layout.
- In dark mode the black viewfinder has no edge against the black background until a preview appears.
- Scrolled content passes under the iOS 26 navigation and bottom bars with the standard edge effect, as recorded in 045.

Colors, layout and copy remain reversible engineering defaults for DEC-01 review.

## Source Change

- `App/Immerse/Sources/CaptureView.swift`: pinned shutter row, status above the viewfinder, Open iPhone Settings for a declined camera, centered status text.
- `App/Immerse/Sources/FilmPresentation.swift`: `Color.primaryAction`.
- `App/Immerse/Sources/SettingsView.swift`, `CameraSamplesView.swift`: filled Done buttons use it.
- `App/Immerse/UITests/JournalFlowTests.swift`: the denied Load Film test taps until the guidance appears.
- `Probes/PopulatedJournalHarness/project.yml` (and the regenerated project): Camera usage key; new `CameraPermissionWorkflowTests.swift`; README.

## Executed Gates

Environment: macOS 26.6.2 (25G83), Xcode 26.5, Swift 6.3.2, iOS 26.5 (23F77) simulators: owned iPhone 17 Pro `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, and task-owned iPhone 13 Pro `48739B52-A691-4863-8245-C313996DE53B` and iPhone SE (3rd generation) `3F8CF83E-0A5D-4F42-BC9A-05D622D7A87E` created for this check and kept for later layout checks.
Runs were pinned to large text, light unless named dark, and each simulator's own settings were restored afterwards.

| Run | Outcome |
| --- | --- |
| `Shutter-048-red-*` (iPhone 13 Pro, SE) | Before the layout fix: shutter bottom 909 > 844 pt and 863 > 667 pt. The iPhone 17 Pro passed that assertion with the shutter touching the edge. |
| `Shutter-048-green-*`, `-green-2-*` | Intermediate: shutter pinned, but the guidance below the fold; then the SE timing failure described above. |
| `Shutter-048-green3-*` | Final layout: passed on all three sizes, three repetitions each. |
| Final gates (`visual-sweep-048/final-stages.log`) | Unsigned generic-device build exit 0. Camera layout test passed on the SE and 13 Pro (`CameraLayout-048-*`). Full populated harness passed 12 (`Populated-048`). `ImmerseUITests` (`Validation-048`): the denied-Camera Load Film test passed; the two original tests failed only on retained audit findings (Super 8 "Movie Orientation" Dynamic Type; one 16mm contrast finding), within the variance recorded in 046 and 047. |

No package or hosted-test source changed, so those gates were not rerun; the UI and harness builds compiled the app and test targets on this source.
The evidence map's CAP-03, CAP-09 and QA-13 rows changed, and the requirement-map check and 25-entry documents ZIP comparison passed.

Result bundle hashes, computed as the SHA-256 of sorted per-file SHA-256 lines inside each bundle:

| Artifact | Hash |
| --- | --- |
| `DarkSweep-048-1.xcresult` | `692c7777b95769d7ee66f478c688fad22b35af740f302706b40f8db927a18ec4` |
| `Sweep-048-dark.xcresult` | `4bd77f34ac4f36167581aca752a3f7911bcfb10e2d3f464178d8b906cc56389a` |
| `Sweep-048-light.xcresult` | `7bd8f6442b6028994438b1d37814382a945a6f5dc96f1fe0c24167872a1769e6` |
| `CameraReopen-048-light.xcresult` | `eb13c8a3745acbf9eb60a30ab591cbeed7dff831026697a2ab1d6937b342d8ef` |
| `CameraReopen-048-dark.xcresult` | `0b0d2566aa28f1001fe04b96c9e41ae51f0c1c9a1c543b8b69f18312a8822eeb` |
| `Shutter-048-red-48739B52-A691-4863-8245-C313996DE53B.xcresult` | `315969d3eafab8e07c8b95d9e0b89414f2fd09117620fd1bec9aa9c486291334` |
| `Shutter-048-red-3F8CF83E-0A5D-4F42-BC9A-05D622D7A87E.xcresult` | `10e125b1dbec123b2c0b6e4dd211cb3297a7a68b78710da6e6722ce3f89f51ef` |
| `Shutter-048-green3-3F8CF83E-0A5D-4F42-BC9A-05D622D7A87E.xcresult` | `48044df375cacfb2956bc0c4494d658a2776947a11788e12ae00dd5693b1a736` |
| `Shutter-048-green3-48739B52-A691-4863-8245-C313996DE53B.xcresult` | `cf0c521b35e61ba430e11d61c223a3c1d7124483c5e3efabc3ee3061c59750d9` |
| `Shutter-048-green3-AA6AD12A-9D0E-4948-ABD2-760AA97B6A60.xcresult` | `91fb885ce12565afd1062d63b4971da8eafb5f36331762e1665a71238f90704d` |
| `CameraLayout-048-3F8CF83E-0A5D-4F42-BC9A-05D622D7A87E.xcresult` | `2119db9d608f00d69c3dba2a93dddd63a87a04e9ed401d4f06a4076200bf0f2a` |
| `CameraLayout-048-48739B52-A691-4863-8245-C313996DE53B.xcresult` | `f828e695538c63ff6d8ae7e63d38b83de7db789c33b005cdcdfc93182c56ecd5` |
| `Populated-048.xcresult` | `abfc5e9443f4968bd890094f18dfa5ccdcd1708a40cbadaa63a341f27cfd34e3` |
| `Validation-048.xcresult` | `eb435196f999ec3e6d796653b20a0140693ebb4e725fad098ff660944090cf60` |

Changed sources are hashed in `visual-sweep-048/source.sha256` against base `96799ed`.

## Limits

The simulator has no camera, so the capture screen was reviewed only in its declined state; a live preview, recording timer, focus and exposure sliders and flash toggle were not rendered.
Screens behind a configured StoreKit catalog, a soundtrack catalog and real Photos were not reviewed.
Increase Contrast, Smart Invert, Bold Text and accessibility text sizes were not swept, and device displays may differ.
The original QA-13 audit failures remain failed and unwaived.
