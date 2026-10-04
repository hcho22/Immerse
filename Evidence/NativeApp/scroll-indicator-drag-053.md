# Scroll-Indicator Drag and Landscape Screenshot 053

Captain (2026-10-02): "yes, fix the red check", after main's Native validation went red again on `b4d9527`.
This record covers the intermittent `ContentSizeTests` failure on main, the sideways landscape Settings screenshot, and the diagnosis of intermittent Dynamic Type audit findings where the audit still runs Dynamic Type.
It is simulator evidence for the automated UI tests only.

## ContentSizeTests on Main: the Held Drag Grabbed the Scroll Indicator

### Failure

Main's CI run on `b4d9527` (https://github.com/hcho22/Immerse/actions/runs/37161155927) failed `ContentSizeTests.testLoadScreenTextAtAccessibilityExtraExtraExtraLarge()` with "Note AccessibilityXXXL was never fully on screen below the navigation bar".
The same test passed on PR #9's and PR #8's CI runs.
The run's `native-test-results` artifact keeps the result bundle, the measurements and a screen recording.

The test measured the Super 8 Load screen's capacity, reveal, controls, orientation, title and entitlement rows at the same frames as every local run, then made 25 more held drags without measuring anything, and never reached the note, Subscription or Load Film.
The recording shows why (`scroll-indicator-drag-053/ci-scrub-frames.png`, 5 frames per second from 24.3 s): during the upward drag after the entitlement pose, the list moved down toward its start, the opposite of a content drag.
The right edge of the same frames (`ci-grabbed-indicator.png`, 8 frames per second from 23.6 s) shows the thin scroll indicator still visible before the drag, then the thick indicator UIKit draws while it is being dragged, moving up with the finger.
The drag started at 98 percent of the width and 70 percent of the height (394, 612 pt), and at the entitlement pose the indicator spanned about 454 to 716 pt on the right edge, so the touch landed on it.
Every later drag at that spot did the same, so the list kept returning to the top.

### Trigger, Masking Condition and Divergence

- Trigger: a held drag that starts on the scroll indicator while it is still showing from the previous drag scrubs the list instead of scrolling it.
- Masking condition: the indicator fades shortly after a scroll ends, and the touch point is under it only at some offsets.
  On CI a step (drag, snapshot) took about 2.7 s and the next drag started about 0.5 s after the previous one ended.
  On this host, at load averages of about 80 to 280, a drag alone took 3.1 to 3.7 s and a measuring step 5 to 9 s, so the indicator had faded each time.
- Earliest divergence: the fourth drag from the top, at the entitlement pose.
  All earlier frames match CI to the point (for example the entitlement row at y = 457.7 in both); locally that drag scrolled on to the note, on CI it scrubbed back up.

### Local Runs Before the Fix

On a new iPhone 17 Pro simulator with iOS 26.5 (23F77), light appearance and large text, built with `CODE_SIGNING_ALLOWED=NO` like CI:

- The unchanged AX XXXL test passed 10 of 10 runs (`-test-iterations 10`).
- A temporary probe (`scroll-indicator-drag-053/ProbeTests.swift.txt`) made the same 380-point held drags from the top of the Super 8 screen at AX XXXL and recorded how far the rows moved after each one.
  At the right edge, with a snapshot between drags (3 runs) and with drags chained without one (5 runs), every drag scrolled the list down (-367 to -370, then -288 to the end, then 0); none reversed.
  XCTest's idle waits on this host outlast the indicator, and XCTest has no public API to synthesize CI's timing, so the CI recording is the reproduction of the trigger.
- The same probe in the left margin (2 percent of the width, 8 pt, outside the 16 pt inset rows) moved the rows by the same amounts (3 runs), so the drag distance and poses do not change.

### Fix

`drag(_:by:)` in `ContentSizeTests` and `scrollUp(_:until:)` in `JournalFlowTests` start their held drags in the left margin instead of the right edge.
The left margin holds no controls and no scroll indicator, and a vertical drag there does not start the back-swipe gesture.
The thresholds, labels, sizes and stop conditions are unchanged.

After the change, the `JournalFlowTests` poses are the same as recorded in 052: Load Film at y = 726.7 at the command audit and the 16mm description at y = 4.0 to 8.7 at the title audit, under the navigation bar.

## Landscape Settings Screenshot

The retained `Settings-landscape-accessibility-largest` screenshot showed the Settings screen turned sideways in the left part of a black landscape image, on CI and locally (`landscape-settings-before.png`, from CI run 37161155927).
A temporary probe in landscape at AX XXXL compared the capture APIs:

- `app.screenshot()` reported a 402 by 874 pt image, but its pixels were 2622 by 1206 with the landscape layout rotated a second time and cropped, the image in the report.
- `XCUIScreen.main.screenshot()` and the window's screenshot reported 874 by 402 pt and held the whole landscape screen, stored as the display's portrait pixels (1206 by 2622) with an orientation flag that the PNG attachment drops.

`retainScreenshot(name:)` now captures the screen and redraws it upright before attaching it (`landscape-settings-after.png`); portrait screenshots are unchanged at 1206 by 2622 pixels.
The audit itself never depended on the screenshot.

## Intermittent Dynamic Type Findings Where the Audit Still Runs Dynamic Type

Decision `dyn-type-determinism` (052) kept Dynamic Type in the four audits outside the Form audit points.
Two of them flag correctly resizing text from time to time:

- `16mm-load-accessibility-largest`, the 16mm Load screen's top pose at AX XXXL: "User will not be able to change the font size" on "One silent Movie after Development" and "Deliberate framing, finer grain".
  PR #8's retained dark runs on this host failed this way 3 times (`unsigned-dark-audit`, `unsigned-dark-audit-2`, and `dark-base-1b` on unmodified `b4d9527`) and passed 2 times, at load averages of about 500 to 1,000; a sixth run timed out.
- The empty Journal's audit at the default size (`JournalFlowTests.swift:9`): the same finding on "Your Journal begins here", once in 10 dark runs of `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` on this branch (`stab-catalog-dark`, repetition 1).
  Its recording shows the text growing through every size during the audit.

The Dynamic Type check changes the running app's text size in place, from XS to AX XXXL, within about 2 seconds, and judges each element's size on its own schedule; a test can only set the pose before calling it.
An earlier hypothesis, that the 16mm load audit started before the push had finished, did not hold up: in PR #8's failing recording the rows were at rest when the audit started (only the back button was still fading in), and a probe found no outgoing catalog rows at that moment in 10 of 10 local dark runs.

### Text Resizes Correctly in Place

A temporary probe (`ProbeTests.swift.txt`, driven by `inplace.sh.txt`) opened a Load screen and, while it stayed open, stepped the simulator's text size from the host as a person could in Settings, then scrolled through the screen with the held drags and measured every element as `ContentSizeTests` does:

- Super 8, from L through every size to AX XXXL (light): all 13 elements came fully on screen with the same frames and text heights as a fresh launch at AX XXXL, for example the entitlement line at 155.3 pt with 300 px of text, and none was clipped.
- Super 8, from L through XS up to XXL, and up to AX M (light): every element measured exactly as at a fresh launch at that size, for example the entitlement line at 56.0 pt with 47 px of text at XXL and 63.7 pt with 60 px at AX M.
- 16mm, from AX XXXL through every size back to AX XXXL (dark): the capacity and description rows measured 160.7 and 217.3 pt with 318 and 513 px of text, as at a fresh launch.

So a person changing text size on these screens sees every row resize and nothing clipped; these findings come from the auditor's timing, not from the elements.

### Local Rates on This Host

All on new iPhone 17 Pro simulators with iOS 26.5, large text, built with `CODE_SIGNING_ALLOWED=NO`.

| Test | Source | Appearance | Load average | Runs | Failures |
| --- | --- | --- | --- | --- | --- |
| `ContentSizeTests` AX XXXL | base `b4d9527` | light | about 80 to 280 | 10 | 0 |
| `testLargestDynamicTypeCatalogAndLandscapeSettings` | base | dark | about 80 to 280 | 10 | 0 |
| same, with 16 extra busy processes | base | dark | about 250 to 830 | 5 | 0 |
| `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore`, with 16 extra busy processes | base | light | about 250 to 830 | 5 | 0 |
| `ContentSizeTests` AX XXXL | this branch | light | about 100 to 850 | 10 | 0 |
| `ContentSizeTests` AX XXXL | this branch | dark | about 100 to 850 | 10 | 0 |
| `testLargestDynamicTypeCatalogAndLandscapeSettings` | this branch | light | about 100 to 850 | 10 | 0 |
| `testLargestDynamicTypeCatalogAndLandscapeSettings` | this branch | dark | about 100 to 850 | 10 | 0 |
| `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` | this branch | light | about 100 | 10 | 0 |
| `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` | this branch | dark | about 100 | 10 | 1 (empty Journal Dynamic Type) |

A first dark run of the largest-size test on this branch never started: its runner was killed before connecting, at a load average of about 850, and the rerun is the row above.

## Limits

The CI recording, not a local run, reproduces the scroll-indicator trigger; local runs show the identical poses up to the divergence and that the left-margin drag scrolls the same way.
The in-place probes ran once per final size: AX XXXL, XXL and AX M on Super 8, and AX XXXL on 16mm.
Every booted iOS 26.5 simulator on this host ran `mediaanalysisd` at about 250 to 320 percent CPU, including these two, which only ran `ImmerseUITests`; local durations are not CI durations.
Simulator rendering only.
