# Main CI Flakes 074

Captain's decision, 2026-10-20, in his words: "Immerse stall - retry".
Main's check on 8a104e1 (run 39424197098, the harness part) failed on the XCTest animation stall of record 069.
This record names the stall's second sighting on CI, what the screen-test rerun now accepts because of it, how that was proved on real result bundles, and what it does not do.
Every number from CI below is read from the run's own result bundle (`xcresulttool`, `log show --archive` on its `system.logarchive`).
Times are UTC.

## The sighting (run 39424197098)

`PopulatedWorkflowTests.testDarkroomTurningLeavesALoadErrorInPlace` turned the device on the Darkroom, then XCTest waited for the app's animations to go idle.
The app logged "Received request to notify when animations are idle" and never sent "Sending animations idle reply".
Two waits ran their full 60 seconds ("App animations complete notification not received, will attempt to continue.", 13:18:55 and 13:20:03) and a third, in teardown, was cut off when the test hit "Test exceeded execution time allowance of 3 minutes" at 13:20:35.
Every assertion in the test passed and XCTest's spindump shows the app's main thread and its animation thread idle.
It is record 069's stall in a Darkroom that failed to load (an unreadable recipe), so a load error is not needed for it, and it is the stall's second sighting on CI in four days (run 38980604148, 2026-10-17, was the first; record 073 has a possible local one with only half the signature).
Its cause is still not found, and the stall has still not been reproduced on this Intel Mac.

In the same run `testInstantLookScreens` failed on a plain dropped touch (`dropped-touch-059.md`: seven discarded touch events in its window).
It got no rerun, because the rerun was allowed only when every failed test in the part was excused by a discard, and the Darkroom test was not.
So one stall cost the part its other, excusable failure as well.

## What changed

`Scripts/screen-tests.sh` now asks `Scripts/rerun-tests.py` which failed tests to run again.
The check holds two records and nothing else excuses a test: the dropped touch (unchanged, from `Scripts/dropped-touch-tests.py`) and this animation stall.
A test is excused by the stall only when all three of these hold for that one test:

1. Its failure is only XCTest's "Test exceeded execution time allowance".
   Every failed `Test Case Run` of the test carries that text; a test that fails an assertion after a stalled wait, or has an assertion failure beside the allowance, is not excused.
2. XCTest's activity "App animations complete notification not received, will attempt to continue." starts inside the test's own time window (its start to start plus its duration, with the same one second of slack the dropped-touch check allows).
3. The app's own log for the launch holds a "Received request to notify when animations are idle", inside the same window, with no "Sending animations idle reply" after it in that launch's section.
   The log is `StandardOutputAndStandardError-<bundle id>.txt` from `xcresulttool export diagnostics` on the failed bundle, which has one section per launch of the app; the test runner's own log, without a bundle identifier in its name, is not read.
   The bundle is exported once, and only after conditions 1 and 2 hold for some test.

Half a signature excuses nothing.
The part's other rules are as they were for the dropped touch:

- The rerun happens once, in one `-only-testing` pass holding every excused test, only when every failed test in the part is excused by one of the two records.
  A stall beside a dropped touch (as on 8a104e1) reruns both together; a stall beside any other failure, or a failure in the rerun, stands.
- No Xcode retry flags, no blanket retry, no extra taps or waits in tests.
- The part's notes (`DerivedData/validation-notes.txt`, the run's summary and a warning on the run's page) name each test that passed only through a rerun and the record that excused it, "dropped touch:" or "animation stall:", so sightings stay countable.
- `AGENTS.md` records that the rerun accepts exactly these two records and that neither is widened, nor a third added, without the captain's word.

Two properties of the app's log shaped condition 3.
Its threads sometimes write a line into the middle of another's, so a line can begin with a piece of another's timestamp, or with none (12 of the 1,995 request and reply lines of this run's app log had another line written into them).
The check reads the timestamp that stands before the process tag, and a request whose line lost its timestamp proves nothing, since it cannot be placed in a window.
A reply whose text was broken the same way would be missed, which could only make a request look unanswered; that needs condition 1 and 2 to hold as well, and an XCTest wait that gave up is not a wait the app answered.

## Proved on real bundles

`python3 Scripts/rerun-tests.py <bundle> --archive <the bundle's system.logarchive>`, the archive taken from `xcresulttool export diagnostics` (`simctl_diagnostics/<udid>/system.logarchive`).
The check exports the app's log from the bundle itself and took about 7 s on the first bundle, whose app log is 165 MB.

| Bundle | Result |
| --- | --- |
| Run 39424197098, harness (the sighting) | Exit 0. `testDarkroomTurningLeavesALoadErrorInPlace` excused as an animation stall (XCTest gave up at 13:18:55, the app never replied to its request at 13:17:55, window 13:17:35 to 13:20:35) and `testInstantLookScreens` excused as a dropped touch (7 events at 13:25:48). Both flags printed, so both would be rerun together. |
| Run 38980604148, harness (record 069) | Exit 1, no rerun. `testDarkroomRestsDodgeBurnAndCropBesideADisposablePrintInLandscape` excused as an animation stall (XCTest gave up at 23:32:59, the app never replied to its request at 23:31:59). `testDarkroomRestsEveryCropControlOnScreenAtTheDefaultSize`, which failed after it with the simulator left sideways, is not excused: its failures are assertions ("XCTAssertTrue failed", "Failed to tap ...") and the log holds no discarded touch in its window. Record 069's `setUp` that holds the simulator portrait now stops that second failure, so a stall of this kind alone would be rerun. |
| Run 39363967185, harness, first attempt | Exit 0. `testDisposableLookScreens` excused as a dropped touch (7 events at 04:01:34), as that run's notes said. |
| Run 39363967185, harness rerun and ui-flows (light) | Exit 1, "holds no failed test": a bundle that passed excuses nothing. |


## Tests

`Scripts/Tests/test_rerun_tests.py` and the new cases of `test_screen_tests.py` run against fixtures cut down from run 39424197098's harness bundle (`Scripts/Tests/Fixtures/animation-stall/`, which also says how they are cut).
They cover the positive case, and these negatives: XCTest's line alone (the last request in the window was answered), the app's unanswered request alone (no XCTest line), a signature outside the test's window (the window, XCTest's line and the app's request each moved out), a failure that is not the time allowance (an assertion, and an assertion beside the allowance), a stall beside a failure nothing excuses (no rerun), a stall beside a dropped touch (both rerun together), a stall that happens again in the rerun (fails), the runner's own log, a request whose line lost its timestamp, diagnostics that cannot be exported, and a bundle with no failed test.
Each condition was also removed in turn from `rerun-tests.py` to see the tests fail.

## What is not shown

A stall cannot be produced on demand, so the rerun path is proved on recorded bundles and fixtures, not on a fresh sighting; the first CI sighting after this change is its live proof, and its part notes will say "animation stall:".
The rerun does not stop the stall and hides it from the check's result unless the notes are read.
A stall that repeats in the rerun, or a real regression that keeps animations running, still fails the part.
The cause is open: the counter that leaves XCTest's animation wait above zero, and the single SwiftUI "ControlsHeightKey ... multiple times per frame" fault at the Darkroom's open in the stalled launch only (`App/Immerse/Sources/PhotoView.swift`), which is a lead from one launch and not a finding.
No app or package code, no test and no assertion was changed.
