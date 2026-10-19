# Main CI Flakes 072

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work, and start a bug fix from the failure as a person would meet it.
On 2026-10-19 Native validation on `main` failed at d348d99 (pull request 43), in run 39252986897.
Its harness part failed one of the harness's 52 tests, and the `local-native` summary check then failed because that part had.
The packages, ui-text and ui-flows parts passed, and pull request 43's own check had passed (run 39202888924).
Pull request 43 changed hosted unit tests under `App/Immerse/Tests` only, not the harness.
This record names what failed, what the run's result bundle and the simulator's log show, what was reproduced here and what was not, and what changed.
GitHub's Macs are Apple silicon and this Mac is Intel; every number from CI below is read from the run's own result bundle (`xcresulttool`, `log show --archive` on its `system.logarchive`).
Times are UTC, on 2026-10-19.

What stopped the app's main thread on CI is not shown, and a stop did not happen naturally here in any run.
The failure's effect was reproduced by injecting a stop, and the change rests on that mechanism, not on a reproduction of CI's stop.

## What failed

| Test | Line | Message | Ran |
| --- | --- | --- | --- |
| `PopulatedWorkflowTests.testDarkroomUnderAnExplanationScrollsItsSliderClearAtTheLargestSize` | `PopulatedWorkflowTests.swift:693` | `XCTAssertTrue failed - Darkroom-explanation-largest: the slider takes the drag` | 13:15:07 to 13:15:58, 53 s |

The job log names only the test; the message is in the result bundle (`native-test-results-harness`).
The test opens the Darkroom of a print whose stored recipe is outside the limits (3.5 stops) at the largest text size, scrolls the exposure slider clear of the fade, and drags its thumb, which rests at the slider's end, to past the other end.
It then expects "-3.0 stops".
The slider read "2.0 stops" (the hierarchy at the failure has `value: plus 2 stops`), and the two assertions after the failed one passed: the print was made, which it is only once the recipe is inside the limits, and the explanation was gone.
So the slider took the drag and moved off 3.5 stops, and ended at 2.0 instead of -3.0.

It is not the Darkroom animation stall of record 069, and nothing about that stall was changed.
The test ran 53 seconds, not to the 3-minute allowance.
Its activity log has no "App animations complete notification not received", and every "Wait for ... to idle" in it returned at once.
In the app's log for the test there are 22 requests to notify when animations are idle and 22 replies.
It is not a dropped touch either: the check's own log found none, so the rerun did not apply, and the touch was delivered (below).

## What the bundle and the simulator's log show

The app was silent for a second in the middle of the drag, and the finger lifted inside that second.

| Time | What |
| --- | --- |
| 13:15:49.674 | `backboardd` attaches XCTest's touchscreen, and the finger goes down 1 ms later, as for every tap of the run |
| 49.947, 50.007 | the app's slider takes its first updates, 1.0000 and 0.9748 of its range (the first move, to 2.8 stops), and sends its control actions; 50.046 is the app's last UIKit log line for a while |
| 50.055 to 51.04 | SpringBoard handles the same touch stream about every 16 ms; the app logs nothing for 0.99 s |
| 50.763 | the finger goes up, 1.088 s after it went down, the length of the drag the test sends (a 0.2 s press, then a drag at 500 pt/s) |
| 50.984 | XCTest asks the app for its main run loop to be idle, since the drag call has returned; the app answers at 51.125 |
| 51.040 | the app takes its next slider update, 0.9550 (2.7 stops), with the finger still counted down |
| 51.088 | 0.0234 (-2.9 stops) with `isActive: NO`: the finger is up |
| 51.138 to 51.521 and on | the thumb moves back up, 0.1218, 0.3344, 0.4022, 0.4685, 0.7511 and on to 0.8289, towards 0.8333, which is 2.0 stops |
| 51.258 | `backboardd`: "synchronize timed out" for the app's window context |

The screen recording shows the same: the slider reads 3.5 stops, its thumb pressed, through the whole drag, with no new frame for about half a second (about 13:15:50.7 to 51.2), and then, about 0.2 s behind the log, 2.8, 2.7, -2.9, -2.3, 1.5, 1.9 and 2.0 over half a second.
The recording's clock is placed from the test's start, so those times are good to a few tenths of a second.

A drag that ends well, as in a run here without a hitch, has the thumb reach 0.0234 (-2.9 stops) while the finger is down, and after the lift (`isActive: NO`) go on down through 0.0089 and -0.0015 to 0.0000, where the app is told -3.0 stops; the label then reads "-3.0 stops".

What the app's main thread was doing in that second is not shown, since the app logged nothing, and it was not the touch service (the finger's events were delivered on time) or the app's idle wait.
That second's slider updates were handled together, after the lift, and the slider then went to a value from before the stop (2.0 stops).
This record reads that from the log and reproduces its effect (below); it has not read UIKit's code.

The run's Mac was slower than the passing run's through the whole test, which is what a stop of the app's main thread would be expected on:

| Point in the test | Pull request 43's passing run (36 s) | The failing run (53 s) |
| --- | --- | --- |
| first tap, after the launch | 5.3 s | 9.1 s |
| the wait for the Darkroom's "Print unavailable" begins | 14.9 s | 19.8 s |
| the four held drags that scroll the slider clear | 12.1 s | 17.3 s |

The simulator's `apsd` (the push service) is in a connection retry loop on CI, about 1,300 to 3,600 log lines a second, and quiet here (12 lines in 10 s); it is as busy in the passing run (54,568 lines in a 15 s window around its test, 19,315 around the failing one), so it is not what separates the two, and nothing was changed for it.

## Why main failed once

- The trigger was a stop of the app's main thread of about a second as the drag began, on a shared Mac runner.
  What stopped it is not shown.
- What hid it everywhere else is that the stop has to end after the finger lifts.
  In a run with no stop, and in one whose stop ends while the finger is down, the slider follows the finger and settles at its end.
- The symptom is the slider's: given the lift together with the moves before it, it ends at a value it had before the stop.

Pull request 43 is not the cause: it changed hosted unit tests, and the harness and the app were the same as in the runs before it.
Of the 31 harness jobs run since 2026-10-14, the day this test was added, this is the only one that failed it; the other three harness failures name other tests.
A pull request is pushed again until its run is green and `main` is read once (record 069), so a one-off like this is met on `main`.

What would show this wrong: a failing run in which the app logs slider updates through the finger's lift (no gap) and the slider still ends away from the finger, or a run with the change below in which the finger lifts after the app has caught up and the slider still ends elsewhere.
The first is not in this run (a 0.99 s gap, the lift inside it), and the second is measured below.

## Reproduced

The stop itself did not happen here, so its effect was made to.

| Condition on this Mac (Intel, Xcode 26.5, an iOS 26.5 simulator made and quieted as validation makes them, the test as in `main`, the app as in `main` with only logging added, and the stop below where named) | Result |
| --- | --- |
| the failing test alone, no load, 4 runs | passed (4 of 4) |
| the same under 80 busy loops, 4 times the Mac's 20 logical cores, 3 runs | passed (3 of 3): load alone gave no stop |
| the app's main thread made to stop for 1 s (a temporary `Thread.sleep` in the slider's change handler, run once after its 1st, 5th and 12th update) | **failed** at the same line, the slider ending at 2.2, 1.4 and 0.5 stops, so the stop's place sets where it ends |
| the same stop for 2 s, after the 1st update | **failed**, at 2.2 stops |
| the same with the app's binding written plainly (no rounding to tenths in the setter), 1 s after the 1st and the 5th update | **failed**, at 2.2 and 1.3 stops: the rounding is not what does it |

The temporary instrumentation also logged each update of the slider and each read and write of its binding, which shows the order: the stop ends, SwiftUI's pending update reads 2.8 (the value before the stop), and then the finger's moves and its lift arrive (`isActive: NO` at -2.9 stops), and the thumb goes back up from there, each frame writing its value to the binding, until it comes to rest short of 2.8.
It was not committed.

The stop that ends before the finger lifts does not do it, which is the change's argument: the same stops with the finger held at the end for a while before it lifts (the lift is 1.05 s after the finger went down, plus the hold):

| Stop (after the 1st update unless noted) | no hold | 0.5 s | 1.0 s | 1.5 s |
| --- | --- | --- | --- | --- |
| 1 s | failed, 2.2 | passed | passed | passed |
| 1 s after the 5th update | failed, 1.4 | passed | | |
| 1 s after the 12th update | failed, 0.5 | passed | passed | passed |
| 2 s | failed, 2.2 | failed, 2.2 | failed, 2.3 | passed |
| 2 s after the 12th update | | | | passed |
| 3 s | | | | failed, 2.3 |

A stop that ends while the finger is still down passes, and one that ends after the lift fails, whatever the hold.

## Fix

`dragThumb(to:)` (`HarnessTestSupport.swift`) presses a slider's thumb for 0.2 s, drags it to the end point at the default 500 pt/s, and keeps the finger down for 1.5 s before it lifts, where the bare `press(forDuration:thenDragTo:)` lifts it as it moves.
A finger still down when the app catches up is handled in order, so the slider ends under it.
The 1.5 s covers a stop that ends up to about 2.5 s after the finger went down, against the 1.37 s of the one in the failing run (which began with the drag's first moves, and ended 0.28 s after the lift), and the 2 s and 3 s rows above bound it: 2 s passes, 3 s fails.
It is one drag, never a second, and the test's assertions are unchanged.
It is the held drag the harness already uses where a drag must not coast (`dragUp`).

It is used where a drag ends on an exact value: this test's exposure drag and the `adjust(_:toEnd:showing:)` helper's finishing drag (which only runs where XCTest's own adjustment stops short of the end), which would fail the same way.
The Crop sliders' drag asserts only that the value changed, so it is not exposed and was left alone.

The assertion that failed now says what the slider read, so a recurrence names its value in the job log, as the clip reader's does (record 070): "the slider takes the drag, and it reads plus 2 stops".

## Repeated runs

On this Mac, as above, no load, with the change.

| What | Before the change | After the change |
| --- | --- | --- |
| the failing test, no stop | 7 of 7 passed (4 here and 3 under load; the figures above) | 10 of 10 passed, 39 to 42 s each |
| the failing test with a 1 s stop after the 1st and the 12th update | failed, failed (rows above) | passed, passed |
| the same with a 2 s stop, after the 1st and the 12th update | failed (after the 1st) | passed, passed |
| the same with a 3 s stop | not run | failed: the limit of the hold |
| `testDarkroomExposureAndDodgeBurnReachThreeStopsAndSave`, which uses the helper | not run before the change | 3 of 3 passed; and once with the helper's early return switched off so its finishing drag ran at all three ends (exposure at 3.0 and -3.0, the strength slider at 3.0), passed |

The stop rows were made with the temporary instrumentation above, which is not in this change.

## What is not shown, and what is left

- What stopped the app's main thread on CI is not shown, and a stop on this Mac could not be made without injecting one.
  The next sighting is read from `system.logarchive` in the bundle's exported diagnostics: the lines of category `FluidSliderInteraction` for the slider's updates, and the gap in the app's own lines across the finger's lift (here 50.046 to 51.040), with the failure message's reading of the slider.
- The hold does not cover a stop that ends later than about 2.5 s after the finger went down or one that begins while the finger is held, and a run where either happens fails this test as before.
  How often the app stops while a finger is held still on CI is not known.
- The runner's `apsd` retry loop (above) is a lead for a source of load, as `mediaanalysisd` and `trustd` were (`Scripts/quiet-simulator.sh`); it is as busy in a passing run, and nothing was measured against it.

## Everything left as it was

The app's sources are unchanged: the slider is SwiftUI's own with the binding it had, and the failure is the same with the binding written plainly.
No assertion was loosened, no audit exception was added, the dropped-touch rerun and its record are as they were, and no test was skipped, slept longer or given a retry.
The Darkroom animation stall of record 069 stays with the captain, who decided to wait for a second sighting; this failure is not a sighting of it.
