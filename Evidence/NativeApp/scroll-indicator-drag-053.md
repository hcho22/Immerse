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
| `ContentSizeTests` AX XXXL | left-margin fix | light | about 100 to 850 | 10 | 0 |
| `ContentSizeTests` AX XXXL | left-margin fix | dark | about 100 to 850 | 10 | 0 |
| `testLargestDynamicTypeCatalogAndLandscapeSettings` | left-margin fix | light | about 100 to 850 | 10 | 0 |
| `testLargestDynamicTypeCatalogAndLandscapeSettings` | left-margin fix | dark | about 100 to 850 | 10 | 0 |
| `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` | left-margin fix | light | about 100 | 10 | 0 |
| `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` | left-margin fix | dark | about 100 | 10 | 1 (empty Journal Dynamic Type) |

"Left-margin fix" is this branch before the decision below, with Dynamic Type still in those audits.
A first dark run of the largest-size test on that source never started: its runner was killed before connecting, at a load average of about 850, and the rerun is the row above.

## Decision: No Audit Runs Dynamic Type

Firstmate decision `dyn-type-inplace-flake` (2026-10-04, option A) revises `dyn-type-determinism`: drop Dynamic Type from every in-place audit and measure all the text those checks covered directly, in light and dark (recorded next to the original decision in `qa13-audit-exceptions-052.md`).

- `JournalFlowTests` runs every audit type except Dynamic Type at all seven audit points (`auditTypes`); every other type, the helper's ordering and the one exception are unchanged.
- `ContentSizeTests` keeps its Load Film measurement and adds three groups, each a test per size: `testJournalAndCatalogTextAt…` measures the empty Journal's title and the catalog's two headers, five Camera names and five capacities; `testLandscapeSettingsTopTextAt…` and `testLandscapeSettingsBottomTextAt…` measure 21 Settings texts in landscape, where Settings is audited: seven headers, the testing switch and its note, the backup, Trial, Photos and privacy copy, the three permission rows, "Open iPhone Settings", Subscription and the version row, plus the Trial error an unsigned build shows.
  Settings is measured in two halves because, at the largest sizes on this host, scrolling the whole screen in held drags took longer than the 3-minute allowance per test (two runs timed out at AX XXL and AX XXXL at load averages of about 450); the top half scrolls down from the top, the bottom half up from the end, which coasting flicks reach quickly.
  `swipeUp()` did not scroll the list in landscape, so the flicks go through the same coordinates as the held drags.
  Navigation titles are system text and are not included, as before; the toolbar buttons have no text.
- `Scripts/validate-local.sh`, and so CI, runs all 48 `ContentSizeTests` in light with the rest of the UI suite.
  A dark rerun of them was added at first and later dropped (Review Round, below); the CI job's timeout is 110 minutes instead of 40 for the added work.

### How the Measurement Changed

- Some Settings paragraphs are taller than the landscape screen at the largest sizes (the backup copy is 651 pt there, against about 290 pt between the navigation bar and the bottom).
  Each element's top edge is now checked once it is on screen with at least 50 pt of the element below it, more than the space between a frame's edge and its text at the largest size (about 25 pt above a section header), and its bottom edge once it is on screen with as much above it; the text height is the frame less those two margins.
  Since the review round below, each margin is measured in pixels from the frame's exact edge, and text within half a pixel of that edge counts as clipped.
  An element that fits is checked in one pose, as before, and the drags are short enough that every edge reaches such a pose in either direction (380 pt in portrait as before, 240 pt in landscape).
  An element must keep its height between the two poses.
- The navigation bar that bounds the visible area is named per screen; sheets keep the Journal's bar in the hierarchy behind them.
- Screens are captured with `XCUIScreen.main.uprightScreenshot()` (`UITests/UITestSupport.swift`), since `app.screenshot()` is wrong in landscape.
- In landscape the drag starts 44 pt from the left edge: at 17 pt, beside the Dynamic Island, it did not scroll; 44 pt is still left of the rows at 78 pt.
- Each test sets portrait before launching, because a test that ran out of time left the simulator in landscape for the next one.

### Test Problems Found and Fixed

Two full runs of all 36 tests in light and dark found these before the final rules:

- The Load screen's entitlement line was measured while it still read "Checking Trial status" (its "g" made it 63 px against 60 px for "Trial status unavailable" at the next size).
  The measurement now holds its pose until that line changes; Settings, which shows nothing while the status is read, first reads it on the Disposable Load screen.
- The empty Journal's element spans its camera symbol, whose top touches the frame, and the "Open iPhone Settings" button's text frame starts at its gear, which the list keeps near one size (92 px at XXXL against 88 px at AX M).
  Both are measured beside their symbol: below the camera, right of the gear.
- Frame heights at one size differed only by floating-point rounding (13.333333333333314 against 13.333333333333371 pt) and are compared to 0.001 pt.

### Two Tolerances, Decision `raster-rules` (Firstmate, 2026-10-04, option A)

Three results were identical in both runs and both appearances without any text-size defect:

- Below L, Apple keeps caption and footnote at one size at XS, S and M, and the frames are identical there (13.333 and 42.333 pt), but the rendered height moves by a pixel with the text's position on the pixel grid: the catalog's Super 8 and 16mm capacities measure 23, 24 and 23 px and the Settings testing note 76, 76 and 75 px.
  Below L only, where the frame height is unchanged, the text may be 1 px shorter; a shorter frame or any larger loss still fails, and the 4 percent rule from L up is unchanged.
- At XS the "p" of "Disposable", in the serif display face, ends exactly on the name's own line box: its 3 px foot is drawn on the last pixel row of the frame and nothing beyond it.
  For the five Camera names only, the bottom edge is judged against the 5 pt gap above the capacity line, so text cut by its row still fails.

The pixel counts above were taken with the earlier arithmetic, which counted margins inside a crop that `CGRect.integral` widens to whole pixels; the review round below has the counts as now measured.
Both tolerances remain as decided.

### Proof

On the source of `7420a38`, before the review round below changed the arithmetic, the whole `ContentSizeTests` class (48 tests: 12 Load Film, 12 Journal and catalog, 12 Settings top and 12 Settings bottom) ran 10 consecutive times on each of two new iPhone 17 Pro simulators with iOS 26.5, one light and one dark, both large text, built with `CODE_SIGNING_ALLOWED=NO`, the app and test runner uninstalled before every run.
All 20 runs passed 48 of 48, at host load averages from about 11 to 700; a run took 25 to 48 minutes on this host.

| Appearance | Runs | Passed per run | Run time |
| --- | --- | --- | --- |
| light | 10 consecutive | 48 of 48 | 1,491 to 2,905 s |
| dark | 10 consecutive | 48 of 48 | 1,499 to 2,905 s |

Before that source, two earlier attempts stopped on their first failure: one ran a stale UI-test bundle from shared derived data (its failure lines matched no assertion in the source, as 052 recorded), hence the uninstall before each run, and one found the AX XXL and AX XXXL Settings timeouts that led to the two halves.

### Full Gate

`sh Scripts/validate-local.sh` on the same source, which still ran `ContentSizeTests` again in dark, with all three simulator variables (the light iOS 26.5 simulator above for the UI and harness stages, a new iPhone 17 Pro iOS 26.2 simulator for StoreKit), exited 0 in 4,353 s at host load averages of about 7 to 30:

| Stage | Outcome | Duration |
| --- | --- | --- |
| Requirement map, packages, probes, documents ZIP, unsigned builds, release excludes the testing unlock | Passed | |
| Populated harness (`Populated-20261004T153943Z.xcresult`) | 12 of 12 passed | 526 s |
| Production UI, light (`Validation-20261004T154834Z.xcresult`) | 53 passed, 1 expected failure (the contrast negative test) | 1,632 s |
| Accessibility audits and text-size measurement, dark (`ValidationDark-20261004T161550Z.xcresult`) | 51 passed, 1 expected failure | 1,556 s |
| iOS 26.2 hosted (`StoreKit-20261004T164150Z.xcresult`) | 29 of 29 passed | 119 s |

The 20 proof runs and this gate used the earlier arithmetic; the review round below reran the class on the current source.

### Review Round: Exact Frame Edges, and No Dark Rerun

Review found that the text height subtracted margins counted from the first and last rows of each element's crop, which `CGRect.integral` widens by a row wherever a frame edge is off the pixel grid, including floating-point noise in frames on the 1/3-pt grid.
Such a sample came out 1 px short, and the clipping checks could take a row outside the frame for its first or last row.

- `inkExtent` now also returns its crop's first row in the screenshot, and each margin is the distance in pixels from the frame's exact edge to the text.
  The text height is the frame's height less both margins, rounded once; when both edges are checked in one pose, that is the rows from the first to the last row of text, as before.
- Text within half a pixel of the frame's exact top or bottom edge fails as clipped; for the Camera names the bottom is still judged against the capacity line below.

The whole class then ran once on each of the two simulators above, light and dark, at the same time, after uninstalling the app and test runner, at host load averages of about 6 to 9.
Both passed 48 of 48 in 1,463 s.

- The catalog's Super 8 and 16mm capacities measure 24, 24 and 24 px and the Settings testing note 76, 76 and 76 px at XS, S and M, in light and dark; the 23, 24, 23 and 76, 76, 75 px came from the earlier arithmetic.
- No element measured shorter at a larger size below L in either appearance, so the 1 px allowance was not used.
  It and the Camera-name clearance stay as decided in `raster-rules`; removing either is a Firstmate decision.
- The smallest growth from L up is 6.4 percent (section headers, 47 to 50 px from XXL to XXXL) in both appearances, above the 4 percent rule.
- 66 of the 588 samples per appearance differ between light and dark by 1 px, none by more: antialiased edge rows cross the ink threshold differently on light and dark backgrounds.

The dark rerun of `ContentSizeTests` is dropped from `Scripts/validate-local.sh`, and so from CI.
The measurement does not depend on appearance: the 10 light and 10 dark proof runs each passed 48 of 48 every time, and so did both runs here, with samples within 1 px of each other, so the rerun doubled the class's cost without a different outcome.
The dark `JournalFlowTests` pass, with contrast and every other audit type at all seven audit points, is unchanged.

### CI Time Budget

Stage durations in seconds, from the step logs of main run 37178893732 (`d9fe760`, 32.2 min) and PR #11's run 37210213939 (54.4 min, the slowest recent success), and the budget for this branch from the slower run:

| Stage | 37178893732 | 37210213939 | Budget |
| --- | --- | --- | --- |
| Setup, checkout, simulators | 24 | 38 | 38 |
| Requirement map, packages, probes, documents ZIP, unsigned builds, release check | 480 | 845 | 845 |
| Populated harness | 525 | 833 | 833 |
| Production UI, light | 617 | 814 | 1,887 |
| Accessibility audits, dark | 147 | 232 | 232 |
| iOS 26.2 hosted | 111 | 453 | 453 |
| Report upload and teardown | 29 | 48 | 48 |
| Total | 1,933 | 3,263 | 4,336 (72.3 min) |

- The light stage of 37210213939 includes PR #11's `MovieCapacityUITests` (123 s), kept in the budget because PR #11 landed first (`31be8d3`, the base this branch is rebased on).
- The 36 added `ContentSizeTests` are estimated from the Load Film tests: 368 s for those 12 in 37210213939's light stage against 362 s in this review's light run, where the added 36 took 1,055 s (Journal and catalog 153, Settings top 379, Settings bottom 523), so about 1,073 s in CI.
- The dark stage keeps the measured `JournalFlowTests` time; dropping Dynamic Type from those audits can only shorten it.
- The job's timeout is 110 minutes: 1.5 times the 72.3-minute estimate is 108.4, rounded up to a multiple of 10.

## Limits

The CI recording, not a local run, reproduces the scroll-indicator trigger; local runs show the identical poses up to the divergence and that the left-margin drag scrolls the same way.
The in-place probes ran once per final size: AX XXXL, XXL and AX M on Super 8, and AX XXXL on 16mm.
Every booted iOS 26.5 simulator on this host ran `mediaanalysisd` at about 250 to 320 percent CPU, including these two, which only ran `ImmerseUITests`; from the extended measurement's proof runs on, it was disabled in these two simulators (`launchctl disable` and `bootout` of `com.apple.mediaanalysisd`), at Firstmate's request to spare the shared host. Local durations are not CI durations.
Simulator rendering only.
