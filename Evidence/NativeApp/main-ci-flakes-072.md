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

## The shooting screen's test that ran out of time on this pull request's check (run 39292846150)

This pull request's own check, at 135c9a1, failed its ui-flows part, and `local-native` then failed because that part had.
The harness part, which holds this change, passed; the ui-text part was cancelled at the job's 75-minute limit with its text-size tests still running, which this record does not cover.

| Test | Message | Ran |
| --- | --- | --- |
| `CaptureSidewaysUITests.testDisposableShootingScreenKeepsItsLayoutHeldSideways` | Test exceeded execution time allowance of 3 minutes | 17:27:53 to 17:30:53 |

Nothing in the test got stuck.
It had loaded its Film, measured the shooting screen in all three holds, turned the Film screen and deleted the Film, and the allowance stopped it in its last wait, for the deleted Film's Journal row to go.
It is not the Darkroom animation stall of record 069: all 31 of its waits for the app to idle returned, and its activity log has no "App animations complete notification not received".
It is not a dropped touch either: the check's own log found none, so the rerun did not apply.

### Where the time went

The Super 8's test after it runs the same steps, and took 89.7 s in the same run.

| Steps | The Disposable's test (first to launch the app) | The Super 8's test |
| --- | --- | --- |
| launch to the Journal at rest | 62.6 s | 9.9 s |
| Start a Film, a Camera, Load Film, Open Camera | 41.8 s | 25.9 s |
| the three holds on the shooting screen | 27.6 s | 25.2 s |
| Done, the Film screen turned | 13.0 s | 7.2 s |
| the relaunch, then Delete Film | 33.9 s, cut off | 21.2 s |

The difference is the session's first launch and the first showing of each screen; the turns on the shooting screen took about as long in both.

- XCTest installs the app at a session's first launch, inside the test that makes it: the simulator's log has the install request at 17:27:57, 4 s into that launch.
- That launch took 48.2 s.
  In the app's log its scene was set up at 17:28:04.99, its window's orientation preferences came 9.7 s later, its first frame at 17:28:33.21 and its main run loop's idle at 17:28:40.52: 36 s from scene to idle.
  The relaunch in the same test took 7.7 s from scene to idle, and every launch after it 1.3 to 2.6 s.
- The runner was a `VirtualMac2,1` with 3 CPUs and 7 GB, booted 12.5 minutes before the timeout (the spindump XCTest took at 17:30:53).

The Disposable's test is the first in ui-flows to launch the app (`AuditExceptionTests`, before it, launches none), and in every ui-flows bundle read it is the slowest of the four tests that run these steps:

| Run | The Disposable's test | its first launch | The Super 8's test | its first launch |
| --- | --- | --- | --- | --- |
| 39073238912 (`main`, 0738226) | 168 s | 10.7 s | 97 s | 6.3 s |
| 39098085159 (`main`, 7447153) | 113 s | 13.0 s | 95 s | 6.7 s |
| 39165281093 (`main`, 3a008ba) | 134 s | 21.2 s | 91 s | 5.6 s |
| 39196559304 (`main`, 433490b) | 110 s | 18.2 s | 84 s | 4.8 s |
| 39202888924 (pull request 43) | 103 s | 13.2 s | 84 s | 4.7 s |
| 39252986897 (`main`, d348d99) | 149 s | 23.2 s | 84 s | 5.6 s |
| 39292846150 (this pull request) | 180 s, stopped | 48.2 s | 90 s | 5.5 s |

The dark pass, a second session on the same simulator that installs the app again, made its first launch in 6.9 to 10.1 s (runs 39252986897, 39196559304 and 39202888924), so the cost is the app's first run on a new simulator more than the install.
The harness part's first launch in this run took 10.3 s, and its first test, 27 s long, had room for it.
In run 39073238912 the turns were slow too (29 and 25 s against the Super 8's 9) and the Instant's test took 121 s, so the runner can be slow through a whole test as well, which no change here addresses.

So the cause is that XCTest counts the app's install and its first, cold launch in whichever test launches the app first, and in ui-flows that is a 90-second test; this run's first launch, 43 s over the Super 8's, took it past 3 minutes.
On `main` at d348d99 (run 39252986897, which failed for the harness test above) the same test took 149 s.

### Fix

`ScreenTestCase` and `HarnessTestCase` launch the app once in their class `setUp`, then end it, before the class's first test.
XCTest starts a test's 3 minutes only when the test starts, which was checked here: with a 75-second sleep added to that class `setUp` (not committed) and a 60-second allowance, `LowStorageUITests.testLoadFilmShowsNoWarningWhenTheReadingFails` passed in 10.8 s, and the runner's log has "Resetting test case timeout timer with an effective execution time allowance of 60" as the test started, 75 s after the class's launch ended.
On a new simulator here the class's launch made the install and took 5.3 s, and the Disposable's test then launched in 3.2 s and passed in 78 s.
So a session's install and first launch come before any test's allowance.
Had the class launched first in the failing run, the test's own launch would have been the session's second, which took 15.4 s there, and its relaunch the third, about 5 s, against 48.2 and 15.4 s: about 137 s for the test, inside its 3 minutes.

Each class now launches the app once more: six classes in ui-flows (and four in its dark pass), one in ui-text and five in the harness, about 5 s each on CI.
The harness launched with no arguments makes one more synthetic Film history in its own documents, as each of its tests does.
The first showing of each screen still costs the first test that shows it, and a runner slow through a whole test, as in run 39073238912, still eats into the allowance.
How XCTest reports a launch that fails in a class `setUp` was not tried.

## Everything left as it was

The app's sources are unchanged: the slider is SwiftUI's own with the binding it had, and the failure is the same with the binding written plainly.
No assertion was loosened, no audit exception was added, the dropped-touch rerun and its record are as they were, and no test was skipped, slept longer or given a retry.
The Darkroom animation stall of record 069 stays with the captain, who decided to wait for a second sighting; this failure is not a sighting of it.
