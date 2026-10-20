# Animation-stall fixtures

Each directory is cut from one CI result bundle in which XCTest's wait for the app to stop animating never ended (`Evidence/NativeApp/main-ci-flakes-074.md`).
The tests of `Scripts/rerun-tests.py` and `Scripts/screen-tests.sh` answer Xcode's tools from them.

- `tests.json` is `xcrun xcresulttool get test-results tests`, cut down to the failed tests and one other test of their suite.
- `test-details.json` holds, for each failed test, the fields read from `xcrun xcresulttool get test-results test-details`: its start and duration, and the name of each failed `Test Case Run`, which is the text of the failure.
- `activities.json` holds, for each failed test, its `xcrun xcresulttool get test-results activities`, cut down to the turns, the waits for the app to idle and XCTest's "App animations complete notification not received, will attempt to continue."
- `app-log.txt` is `StandardOutputAndStandardError-<bundle id>.txt` from `xcrun xcresulttool export diagnostics`, cut down to each launch's header line and the "Received request to notify when animations are idle" and "Sending animations idle reply" lines of three launches: the one before the stalled one, the stalled one and the one after it.
- `simulator-log.ndjson` is every record the dropped-touch check's `log show` query returned from the run's simulator log, cut down to six fields.

| Directory | Run | Bundle | Failed tests |
| --- | --- | --- | --- |
| `darkroom-stall-and-instant-dropped-touch` | 39424197098, 2026-10-20 | harness | `testDarkroomTurningLeavesALoadErrorInPlace`, which ran out of its 3 minutes on two 60-second waits and a third, and `testInstantLookScreens`, whose tap on "Open photo 1" the simulator dropped |
