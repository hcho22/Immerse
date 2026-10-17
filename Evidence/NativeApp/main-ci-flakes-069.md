# Main CI Flakes 069

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work, and start a bug fix from the failure as a person would meet it.
On 2026-10-17 Native validation on `main` failed after each of its last two merges, while the same code had passed the same checks on its pull request.
This record names what failed in each run, what the result bundles and the simulators' logs show, what was reproduced here and what was not, and what changed.
GitHub's Macs are Apple silicon and this Mac is Intel; every number from CI below is read from the run's own result bundle (`xcresulttool`, `log show --archive` on its `system.logarchive`).

| Run | Commit | Part | What failed | Kind |
| --- | --- | --- | --- | --- |
| 38980604148 | 003d8d4 (pull request 37, the Instant camera restart) | harness | `PopulatedWorkflowTests.testDarkroomRestsDodgeBurnAndCropBesideADisposablePrintInLandscape` (3-minute allowance) and then `testDarkroomRestsEveryCropControlOnScreenAtTheDefaultSize` | XCTest's wait for the app to stop animating never ended after a rotation, then the first test's timeout left the simulator sideways for the second |
| 39041986761 | 79a1b1c (pull request 38, the sideways shooting screen and 6×6 zoom) | ui-flows | `TestingUnlockUITests.testUnlockIndicatorShowsAfterTheSettingsSwitchIsTurnedOn` | The simulator registered its touchscreen late, so the tap on a switch reached the app as a 4 ms touch, which a switch ignores |
| 39004998658 | 2eda3b4 (pull request 38's first run) | ui-flows | 26 of 29 tests, from `CaptureSidewaysUITests` on | Not a failure of `main`: the first capture test failed on that revision, and the tests after it launched sideways, the same leftover as the second harness failure |

## Why main failed where the pull request passed

None of the three failures is in either pull request's code.
Pull request 38's portrait hold (`InterfaceOrientationLock`, `ImmerseAppDelegate.supportedOrientations`) is not what failed run 39041986761: the failing test is a portrait test, its screenshots are portrait, and the landscape tests that ran after the capture tests in the same part (`JournalFlowTests.testLargestDynamicTypeCatalogAndLandscapeSettings` and the rest) passed.
Run 38980604148 is the commit before pull request 38 and its harness app has no such hold.
A pull request is pushed again until its run is green and only a green one merges, while a run on `main` is read once.
Of the last 60 completed runs of the workflow (2026-10-06 to 2026-10-17), 9 of 23 on `main` failed and 7 of 37 on pull requests, and the earlier ones had other causes (`ci-flakes-057.md`, `dropped-touch-059.md`, `main-ci-flakes-066.md`).

## The unlock switch's lost tap (run 39041986761)

### Failure

`testUnlockIndicatorShowsAfterTheSettingsSwitchIsTurnedOn` turns the Settings switch off and then on across a relaunch.
The second tap, on the switch at (340.5, 250.3), left it off ("0" is not equal to "1", at `TestingUnlockUITests.swift:44`), and the Load screen then showed no indicator.
The screen recording shows no movement of the thumb at all in the 2.4 seconds after the tap, and the first tap, at the same point, had turned it.
`Scripts/screen-tests.sh` found no discarded touch in the test's window, so it did not rerun it.

### What the simulator's log shows

XCTest sends each tap through a touchscreen it attaches for that one gesture.
For every other tap of the run, 280 of them, `backboardd` logs the touchscreen attached, the finger down 1 to 11 ms later and the finger up 59 to 75 ms after the finger down.
For this tap it logged:

- 15:20:25.460, `digitizer attached`.
- 15:20:25.579, `restore persistent props`, 119 ms later: the touch service was late to register the touchscreen.
- 15:20:25.580, the finger down, and 15:20:25.584, the finger up, 4 ms apart.
- Thirteen `Event latency` lines of 121 to 122 ms for the touchscreen's events, which `backboardd` writes only for a late event.
  No other touchscreen of the run has one.

So XCTest's two events were created 66 ms apart as usual, the simulator handled them 120 ms late and delivered both at once.
The touch was delivered to the app (`touchstats` names Immerse as its destination), so this is not the dropped touch of `dropped-touch-059.md`: nothing was discarded, which is why the rerun's record does not see it.
One other tap of the run had a late registration, 628 ms, and its 19 ms touch landed on a button of a test that passed.

### Reproduced

A switch ignores a touch whose finger-down and finger-up arrive a few milliseconds apart after a late registration, and a button does not.
To make the simulator register late, `kill -STOP` and `kill -CONT` on the simulator's `backboardd` (the touch service) freeze it for 130 ms every 300 ms while a test taps the Settings switch 80 times, checking after each tap that it turned.
A freeze that starts between the touchscreen's attach and its registration, a window of about 2 ms, is what delays the finger-down; it lands there for about one tap in a hundred.

| Input on the switch under that freeze | Taps | Touches with a late registration (120 ms or more) | Of those, a finger-up within 10 ms of the finger-down | Taps that did not turn the switch |
| --- | --- | --- | --- | --- |
| `tap()` | 480 | 5 | 3 | 3, each of them one of the 3 |
| a press held 0.3 s | 480 | 25 | 0 | 0 |

The three lost taps had `backboardd` timings of 135 ms and 6 ms, 177 ms and 6 ms, and 137 ms and 6 ms (registration lag, then finger-down to finger-up), as the CI tap had 119 ms and 4 ms, and the log of each has the same `Event latency` lines.
The two other late registrations, with a finger-up 72 and 91 ms after the finger-down, turned the switch.
With a button, 120 taps under the same freeze (60 Settings, 60 Done) all worked, among them one touch of 139 ms and 4 ms.
Without the freeze, 150 taps of the unlock test's flows had a registration lag of 1 to 11 ms and a median of 69 ms between finger-down and finger-up, and the unlock test passed 15 of 15.
A short press that is not late is not enough to lose the tap: presses of 0 to 66 ms made by XCTest with no freeze turned the switch 7 times in 9, so it is the late registration, with both events delivered at once after it, that loses the tap.

### Fix

`flipSwitch()` (`UITestSupport.swift`, and `HarnessTestSupport.swift` for the harness) presses a switch for 1 s where `tap()` presses for 66 ms.
The 480 presses of the table above were made with a press held 0.3 s, whose finger-up is scheduled 300 ms after the finger-down, and their 25 late registrations (136 to 179 ms) kept a finger-up 154 to 350 ms after their finger-down, 23 of them 300 ms or more.
The hold was then raised to 1 s, because the same CI run logged one registration 628 ms late (above), a lag no experiment here produced and longer than a 0.3 s hold covers.
That a 1 s hold covers such a lag is argued from when its finger-up is scheduled, 1,000 ms after the finger-down, and was not measured against such a lag.
A 1 s press turned the Settings switch and the Crop switch in every test of the harness and ui-flows parts run with it (see "Repeated runs"), the only measurement of the 1 s hold, and none was made against a lag of 628 ms.
It is one press, never a second tap, and it is used where the tests flip a switch: the Settings switch in `TestingUnlockUITests` and the Crop switch in the harness's seven places.
Buttons keep `tap()`.

## The Darkroom test that timed out, and the one after it (run 38980604148)

### Failure

`testDarkroomRestsDodgeBurnAndCropBesideADisposablePrintInLandscape` ran from 23:31:47 to the 3-minute allowance, 23:34:47, with no assertion failing.
Its activity log in the bundle:

- 23:31:59.5, "Setting device orientation to Landscape Left", then "Wait for the app to idle" for 60.0 seconds, ending "App animations complete notification not received, will attempt to continue."
- 23:33:02, the tap on the Dodge / Burn tool, and another 60.0 seconds of the same wait.
- 23:34:02.8, the tap delivered, and a third wait that the allowance cut off.

`testDarkroomRestsEveryCropControlOnScreenAtTheDefaultSize` started 28 seconds later, at 23:35:15, and failed in 56 seconds: its tap on the Journal's Film card did nothing, so the Film screen never opened and "Open photo 1" was not found.
Its tap was synthesized at (18.2, 437) in the device's own frame, which is (437, 383.8) of the 874 by 402 landscape screen: 18 points above the bottom edge, in the home indicator's area.
`backboardd` logs `GraphicsOrientation = 4` for that touchscreen.
That test never sets the orientation (the other tests that turn do, first thing), and the test before it, stopped at its allowance, runs no `defer` or teardown, so the simulator was still on its side.
Run 39004998658 is the same cascade in the app's own screen tests: `CaptureSidewaysUITests` stopped, `JournalFlowTests` launched with "Interface orientation changed to Landscape Right", and 25 tests failed on taps and queries that were aimed for a portrait screen.

### What the stall is

XCTest's wait for the animations to stop is a counter in the app, `XCTActiveAnimationsCount` in `XCTAutomationSupport`.
It goes up on each `UIViewAnimationState animationDidStart:` and down on each `animationDidStop:finished:` (a stop with no start is logged and put back to 0), and it answers the runner's "notify when animations are idle" request only when it goes from 1 to 0 or when it is asked while it is 0.
The app's log of the failing run holds 107 of those requests and 104 replies.
The three without a reply are the three waits above, the first received at 23:31:59.233, 37 ms after "Scene will change interface orientation", where the previous test's rotation (23:31:21) was answered 1.29 seconds after its request, once the rotation's 399 animations of 0.3 s had ended.
So the counter stood above 0 in an app that was doing nothing:

- The spindump XCTest took at 23:34:47 shows the runner waiting in `-[XCUIApplication _waitForQuiescenceAsPreEvent:]`, and the app's main thread idle in its run loop (it last ran 27 seconds before), its `inProcessAnimationManager` thread idle since 23:32:00, `backboardd`'s render server idle, and the Mac's only busy process the spindump itself.
- Nothing else in the log of that minute is unusual, and no touch was discarded.

An animation whose start was counted and whose stop never arrived is what leaves the counter above 0, and every later wait then ends only at XCTest's 60-second limit.
The Darkroom is where the app tears down one tree and builds another while UIKit's rotation animations run: `DarkroomLayout` shows `stacked` (with a bottom-bar toolbar item) in portrait and `sideBySide` in landscape.
That is a reading of the counter's code and of one log, not something this record proved.

### Not reproduced

The stall did not recur in more than 200 rotations here (an Intel Mac with 20 logical cores and an iOS 26.5 simulator): the eight rotating tests of the harness 11 times each, 30 turns in one open Darkroom, 76 fresh launches that turned 0 to 3 seconds after the Darkroom opened, and the others, and in none did the counter stay above 0 (a temporary probe read `+[XCTAnimationsIdleNotifier isAnimationInProgress]` every 50 ms; a normal turn sets it for about 1 second).
Of the five harness bundles of CI runs read here (the failing one, two others that failed for other reasons and two that passed) and two ui-flows bundles, only this one has an unanswered wait.
So no change to the Darkroom or to a test's turn can be shown to prevent it, and none was made.
Turning off UIView animations in the harness app, which would stop the counter being fed, left the Darkroom busy at 89% of a core for the 20 minutes the test was left to run, so it was not adopted either.

### Fix of what the stall did to the next test

Every screen test class now derives from `ScreenTestCase` (the app's) or `HarnessTestCase` (the harness's), whose `setUp` holds the simulator portrait.
A test stopped at its allowance still leaves it sideways, but the next test no longer starts that way, so a stall costs its own test and not the ones after it.
The same setUp covers run 39004998658's cascade.
`Scripts/verify-validation-parts.sh` finds the screen tests' suites by their `XCTestCase` superclass, so it now also reads `ScreenTestCase`'s subclasses, and leaves `ScreenTestCase` out as a suite with no tests of its own.

### What still fails

A stall still fails its own test at the 3-minute allowance.
`Scripts/screen-tests.sh` reruns a failed test once only on a discarded touch in the simulator's log (`dropped-touch-059.md`), and it was not widened here, since the captain said never to.
The stall has its own exact record, if he wants the rerun to take it: XCTest's activity "App animations complete notification not received, will attempt to continue." inside the failed test, and the app's own log line "Received request to notify when animations are idle" without a "Sending animations idle reply" after it.
It is a decision for him and is left open.

## Repeated runs

On this Mac (Intel, Xcode 26.5, iOS 26.5 simulators made and quieted as validation makes them), with the changes in this record.
The first six rows' runs after the change were made with `flipSwitch()` holding its press 0.3 s, before the hold was raised to 1 s (see "Fix" above).
The last two rows were run with the 1 s hold.

| What | Before the change | After the change |
| --- | --- | --- |
| The test after one that was stopped sideways: the harness runner is killed once the simulator turns landscape in `testDarkroomRestsDodgeBurnAndCropBesideADisposablePrintInLandscape`, then `testDarkroomRestsEveryCropControlOnScreenAtTheDefaultSize` runs alone | failed in 59 s with the three failures of run 38980604148 (`PopulatedWorkflowTests.swift` lines 1219, 714 and 715: the Film screen did not open, "Open photo 1" was not found) | passed in 46 s |
| The Settings switch, 480 presses under the 130 ms freezes of the touch service | 3 lost, each a touch with a finger-up 6 ms after its finger-down | 0 lost with a press held 0.3 s, 25 late registrations (table above) |
| The two unlock tests together, 8 rounds, with the touch service frozen 100 ms of every 160 ms | 8 of 8 passed (2 of the rounds' touches were compressed, none on a switch) | 8 of 8 passed |
| The two unlock tests together, no freeze | 15 rounds passed | the same tests, now in the validation below |
| Harness part of `Scripts/validate-local.sh` | not run before the change | 52 of 52 tests passed, no rerun (34 minutes) |
| ui-flows part, light, then the audits again in dark | not run before the change | 28 of 29 passed and the 1 expected failure (`testAuditStillReportsContrastFindingsOutsideItsExceptions`), then 20 of 21 and the same 1, no rerun |
| Harness part, ui-flows part and its dark audits, with the 1 s hold | not run before the change | harness 52 of 52 passed, no rerun (33 minutes); ui-flows 28 of 29 passed and the 1 expected failure (`testAuditStillReportsContrastFindingsOutsideItsExceptions`), no rerun (24 minutes); dark audits 20 of 21 and the same 1, no rerun (13 minutes) |
| `python3 -B -m unittest discover -s Scripts/Tests` | 5 of 52 failed at this branch's first commit, whose tests still copied the UI test classes by their `XCTestCase` superclass | 53 of 53 passed |

The 8-round row shows only that the change breaks nothing there: the freezes of that row lost no switch tap before the change either, so the 480-press row is what shows the cause and the fix.
The stall of the second failure is not in this table, since it did not recur (see "Not reproduced").

## Everything left as it was

The app's sources, the Darkroom and the shooting screen's portrait hold are unchanged, no assertion was loosened, no audit exception was added, and no test was skipped or given a retry.
