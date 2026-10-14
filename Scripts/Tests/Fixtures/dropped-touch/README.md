# Dropped-touch fixtures

Each directory is cut from one CI result bundle in which the simulator dropped a synthesized touch (`Evidence/NativeApp/dropped-touch-059.md`).
The tests of `Scripts/dropped-touch-tests.py` and `Scripts/screen-tests.sh` answer Xcode's tools from them.

- `tests.json` is `xcrun xcresulttool get test-results tests`, cut down to the failed tests and one other test of each of their suites.
- `test-details.json` holds, for each failed test, the fields read from `xcrun xcresulttool get test-results test-details`.
- `simulator-log.ndjson` is every record the checker's `log show` query returned from that run's simulator log, cut down to six fields.

| Directory | Run | Bundle | Failed tests |
| --- | --- | --- | --- |
| `harness-film-card-tap` | 38412185318, attempt 1, 2026-10-13 | harness | the tap on a Journal Film card, dropped |
| `app-start-a-film-tap-and-a-timeout` | 37627486582, 2026-10-07 | app screen tests | the tap on Start a Film, dropped, and a test that ran out of its 3 minutes |
| `app-back-button-tap-and-clipped-text` | 37788441803, 2026-10-08 | app screen tests | the tap on a Back button, dropped, and a clipped-text audit finding |
