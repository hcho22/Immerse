# Main CI Flakes 071

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work, and start a bug fix from the failure as a person would meet it.
On 2026-10-18 Native validation on `main` failed at 7447153 (pull request 40), in run 39098085159.
Its packages part failed two of the app's 78 hosted unit tests, and the `local-native` summary check then failed because that part had.
The next run on `main`, 39165281093 at 3a008ba, passed every part, and pull request 40's own check had passed.
This record names what failed, what the run's result bundle and the simulator's log show, what was reproduced here and what was not, and what changed.
GitHub's Macs are Apple silicon and this Mac is Intel; every number from CI below is read from the run's own result bundle (`xcresulttool`, `log show --archive` on its `system.logarchive`).
Times are UTC, on 2026-10-18.

## What failed

The packages part's last step runs the app's hosted unit tests (`ImmerseTests`) on the iOS 26.2 "Immerse Billing CI" simulator.
Two of its 78 tests failed, and both with the same message in the result bundle:

| Test | Line | Message |
| --- | --- | --- |
| `CaptureControllerIntegrationTests.testCaptureScreensShowEachCamerasViewfinderShapeAndTheLowLightCue` | `CaptureControllerIntegrationTests.swift:429` | `XCTUnwrap failed: expected non-nil value of type "UIWindowScene"` |
| `CaptureControllerIntegrationTests.testCaptureScreenWhileRecordingCountsDownInMinutesAndSeconds` | `CaptureControllerIntegrationTests.swift:282` | the same |

The job log names only the two tests; the message is in the result bundle (`native-test-results-packages`, `StoreKit-*.xcresult`).
The two tests are the 2nd and 3rd of the run: `CaptureControllerIntegrationTests` is the first class XCTest runs, so they started 9 ms and 0.2 s after its first test and failed after 0.214 s and 0.189 s.
Each puts a window on the app's scene to take a screenshot of the actual shooting screen, and takes the scene with `XCTUnwrap(UIApplication.shared.connectedScenes...first)` on its first line.
Every other test of the run passed, among them those that take the scene the same way in 12 more places (`CaptureSidewaysTests`, `JournalIntegrationTests`), which XCTest ran 13 seconds or more later.

## What the logs show

The app had no scene when the tests started, and got it five seconds later.

| Event | Failing run 39098085159 | Passing run 39165281093 |
| --- | --- | --- |
| The simulator's SpringBoard opens the app | 05:36:20.20 | not read |
| The app's first log line | 05:36:27.55 | 21:38:48.19 |
| The app sends its handshake to FrontBoard (`FBSWorkspaceScenesClient ... sent handshake`) | 05:36:27.58 | 21:38:48.29 |
| FrontBoard hands the app its scene (`UIMutableApplicationSceneSettings setting counterpart class`) | **05:36:34.68** | 21:38:48.33 |
| XCTest's runner is ready | 05:36:28.2 | not read |
| The first test starts | **05:36:29.48** | 21:38:52.47 |
| The two tests fail | 05:36:29.70 and 05:36:29.89 | passed (32.2 s and 1.7 s) |

So in the passing run the scene came 31 ms after the handshake and 4.1 seconds before the first test, and in the failing run it came 7.1 seconds after the handshake and 5.2 seconds after the first test.
The app's own log shows the scene's first window becoming key at 05:36:35.26, and `CaptureSidewaysTests` started at 05:36:42, after it.

The delay is SpringBoard's, not the app's.
In the failing run SpringBoard logged nothing between 05:36:27.82 and 05:36:34.62, and logged "received incoming handshake" from the app at 05:36:34.65.
That is 30 ms after `com.apple.chrono.WidgetRenderer-Default` (the home screen's widget renderer) left the foreground at 05:36:34.62, at the end of a scene update that had run past its 10-second watchdog at 05:36:25.99, so since about 05:36:16, before the app was opened at 05:36:20.
The app's own startup was slow in the same span (process started 05:36:20.47, first log line 05:36:27.55).
That the widget renderer's scene update is what held SpringBoard's FrontBoard queue is a reading of that order, not something shown: freezing the renderer for 15 seconds here did not delay the scene (see "Reproduced").

## Why main failed once

- The trigger was the simulator's SpringBoard handing the app its scene seven seconds after the app asked for it, on a shared Mac runner (why it was late is not shown beyond the reading above).
- What hid the missing wait everywhere else is that the scene normally arrives before XCTest's first test: 4.1 seconds before it in the passing CI run and 0.2 to 1.0 second before it on this Mac.
- The symptom was the `XCTUnwrap`, on the only two tests that run before the scene had its usual head start.

Pull request 40 is not the cause.
It changed UI test and harness files, `Scripts`, `Evidence` and `AGENTS.md` only, and none of those files is in the app or the hosted `ImmerseTests` target, so the app's sources and these tests were the same as in the runs before it.
The two tests had passed on every run that reached them since they were written (`31be8d3` and `fa8eb07`, 2026-10-04 and 2026-10-07), and of the 17 failed runs of the workflow since 2026-10-07, only this one names them among its failures.
A pull request is pushed again until its run is green and `main` is read once (record 069), so a one-off like this is met on `main`.

What would show this wrong: a failing run whose app log shows a scene before the first test, or a run in which the tests wait for the scene and still fail on it.
The first is not in this run (scene at 05:36:34.68 against the first test at 05:36:29.48), and the second is measured below.

## Reproduced

The stall itself cannot be summoned from outside the simulator; what can is a SpringBoard that answers late.

| Condition on this Mac (Intel, Xcode 26.5, an iOS 26.2 simulator made and quieted as validation makes them) | Result |
| --- | --- |
| The failing test alone under 28 busy loops, SpringBoard at its normal priority, 3 launches | passed; the scene came 0.43 to 0.54 s before the test |
| SpringBoard stopped (`SIGSTOP`) from the app's launch, 10 to 12 s, 2 launches | passed, but not the late scene: the app's own startup waits for SpringBoard too, so the tests started after SpringBoard resumed |
| The widget renderer stopped for 15 s from the launch, 1 launch | passed; the scene came 0.28 s before the test |
| 30 busy loops, SpringBoard at the lowest priority (`renice -n 20`, `taskpolicy -b`), `testCaptureScreenWhileRecordingCountsDownInMinutesAndSeconds` alone, 10 launches | **5 failed** with `XCTUnwrap failed: expected non-nil value of type "UIWindowScene"` at line 282, the failure of the run; 5 passed |
| The same, both tests, 5 launches | **1 failed**, both tests, at lines 429 and 282: the two failures of the run; 4 passed |

The last two rows are the reproduction: the same message from the same lines, from launches where SpringBoard hands the scene over after the first test starts.
It reproduces the cause (a late scene), not CI's seven-second stall, and the freezes that came nearest to the stall did not.

## Fix

`hostWindowScene()` (`App/Immerse/Tests/HostWindowScene.swift`) returns the app's window scene, and when there is none waits for it, with a 60-second limit that fails with a message saying the app never received its scene.
It checks the real condition (a connected `UIWindowScene`) every 20 ms and returns at once when it is there, so a run that has the scene pays nothing, and a scene that never comes fails the test at 60 seconds, inside the 120-second allowance of the hosted run, instead of at an `XCTUnwrap`.
It prints how long it waited when it had to, which shows in the result bundle's output for the test.
The 14 places in `CaptureControllerIntegrationTests`, `CaptureSidewaysTests` and `JournalIntegrationTests` that read `connectedScenes` once now call it, the 12 that this run did not trip as well as the 2 it did, since they have the same read and escaped only by starting later.
No assertion was changed or removed: each test still checks everything it checked, after a scene exists.

## Repeated runs

On this Mac, same conditions as the last reproduction row (30 busy loops, SpringBoard at the lowest priority), one fresh launch per run.

| What | Before the change | After the change |
| --- | --- | --- |
| `testCaptureScreenWhileRecordingCountsDownInMinutesAndSeconds` alone | 5 of 10 failed | 20 of 20 passed, in two batches of 8 and 12; 3 of the 12 had to wait for the scene (0.55, 0.65 and 0.80 s). Two more launches of the first batch never started the app ("Simulator device failed to launch"), under a load that also loaded the rest of this Mac, and are not counted |
| the two tests together | 1 of 5 failed, both tests | 6 of 6 passed; one waited 0.32 s |
| the whole hosted target (`-only-testing:ImmerseTests`, 78 tests, as the packages part runs it, with the 120-second allowance), quiet | not run before the change | 78 of 78 passed in 123 s |
| the whole hosted target under the same load | not run before the change | 78 of 78 passed in 143 s and in 146 s; one launch waited 0.34 s |

The batches differ in how late SpringBoard was (5 of 10, then 1 of 5 launches lost the race before the change), since the Mac carried other jobs of its own; what they show is that the same launches no longer fail.
The helper's 60-second failure cannot be reached in a hosted run that gets a scene, so it was read, not run.

## Everything left as it was

The app's sources and every UI test are unchanged, no assertion was loosened, no audit exception was added, and no test was skipped or given a retry.
The rare Darkroom animation stall (record 069) and the clip reader's failure (record 070) are separate and were not touched; XCTest's "App animations complete notification not received" does not appear in the hosted tests' bundle of the failing run.
