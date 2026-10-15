# Main CI Flakes 066

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work.
On 2026-10-14 Native validation on `main` had failed on 5 of its last 8 pushes, mostly on tests unrelated to the change being merged.
This record names the failing test and its cause for four of those runs and says what changed.
The fifth, run 38638875477 (5c427bc), failed on a Crop switch tap in the harness part and belongs to the low-storage test cleanup.

| Run | Commit | Part | What failed | Kind |
| --- | --- | --- | --- | --- |
| 38569804164 | 9d54ba1 | packages | `StoreKitSubscriptionTests.testPendingApprovalAndTransactionUpdate` | Check setup: the simulator's trustd stalled every trust check |
| 38483188498 | 9b99008 | ui-text | `ContentSizeTests.testFilmStockLoadScreenTextAtAccessibilityExtraExtraExtraLarge` | Flaky test: tapped a row with only 17 points of it on screen |
| 38473025368 | d82c6fa | ui-text | `ContentSizeTests.testLandscapeSettingsTopTextAtAccessibilityExtraExtraExtraLarge` | Flaky test: one drag carried an edge past the window, and the loop never went back |
| 38403410314 | 5c3a217 | local-native | Cancelled | Check setup: the old single job hit its 120-minute limit; its rerun never got a runner |

Each of these was read from the run's job log and the result bundle the part keeps (screenshots, screen recordings, UI snapshots, synthesized events and the simulator's system log).
GitHub's Macs are Apple silicon and this Mac is Intel; what only CI showed is said so below.

## StoreKitSubscriptionTests.testPendingApprovalAndTransactionUpdate (run 38569804164)

### Failure

"Asynchronous wait failed: Exceeded timeout of 10 seconds, with unfulfilled expectations: verified entitlement update."
It was the first StoreKit test to run, on the iOS 26.2 billing simulator the packages part creates and boots shortly before these tests.
The other three StoreKit tests passed right after it.

### What the simulator's log shows

- The purchase went to Ask to Buy and the test approved it at 13:48:19.995, two seconds into the test.
- StoreKit's local test server (ASOctaneSupportXPCService) then asked trustd to evaluate a certificate at 13:48:20.050, to sign the approved transaction, and got no answer until 13:50:15.9.
- storekitd's two follow-up requests to that server, the pending-purchase queue check and the subscription status sync, each waited 60 seconds and failed with a URL timeout.
- The update the test waited for reached the app at 13:50:15, two minutes after the approval and long after its 10 seconds.
- trustd had started an update of its certificate revocation ("VALID") database at 13:48:03.
  It logs a revocation check every few seconds during these tests, and logged none from 13:48:03 to 13:50:15.
  Other processes' TLS checks (nsurlsessiond) waited through the same span.
- The update's own download from Apple's revocation server failed with a TLS error at 13:49:55 and was cancelled at 13:50:01; trust checks resumed 14 seconds later.

So the app and the test were waiting on the simulator: for those two minutes trustd answered no trust check, and StoreKit's test server cannot sign a transaction without one.

### What only CI showed

On this Mac the same update ran on three fresh iOS 26.2 simulators and succeeded each time, in 48 to 231 seconds.
The pending approval test ran 310 times on a fresh simulator, 250 of them while its update was downloading and rebuilding the database (07:17:24 to 07:21:15), and passed every time in under 2 seconds.
So here a successful update does not hold trust checks, and the stall was not reproduced.
CI's update failed instead: its download's TLS check is itself a trust check, which suggests trustd was waiting on its own update until the download timed out.
Whether that holds on every runner is not established; what the log does establish is that the stall came from this update and ended with it.

### Fix: switch the update off on test simulators

trustd reads `ValidUpdateEnabled` in the `com.apple.security` preferences and, when it is false, logs "skipping update" and downloads nothing.
`Scripts/quiet-simulator.sh` now writes it into the simulator's own preferences file before the simulator boots, since trustd starts the update within seconds of a first boot, and again through the running simulator.
The Mac's `defaults write` to the file's path left no file there before the boot; `plutil` does.
On two fresh simulators prepared this way trustd's first launch logged "skipping update", and so did its next check four minutes later; the three prepared by the script on `main` scheduled and ran the download each time.
`Scripts/validate-local.sh` now runs the quiet script before it waits for a simulator to boot, so the setting is in place for each part's first boot.
Tests need no revocation data, and the app is unchanged.
The test still waits for the same verified update, for the same 10 seconds.

## ContentSizeTests.testFilmStockLoadScreenTextAtAccessibilityExtraExtraExtraLarge (run 38483188498)

### Failure

"16mm AccessibilityXXXL": the 16mm Load screen did not open, and the test then looked for its Black and white button on the Camera catalog.
`Scripts/screen-tests.sh` found no dropped touch in the simulator's log for the test's time window, so it did not rerun it.

### Cause

After measuring the 6×6 screen the test went back to the catalog and dragged until `isHittable` said the 16mm row could be tapped.
`isHittable` is true while any part of an element is on screen, and XCTest taps the middle of the part that shows.
The synthesized event in the result bundle puts the tap at y 865.7 on an 874-point screen; the hierarchy captured after it has the 168-point row starting at y 857, so 17 points of it showed.
That point is inside the home indicator's area, where the tap did nothing, and the screen recording shows the catalog unchanged after it.
Where a drag leaves the list differs from run to run, so most runs left more of the row on screen.

### Fix

Every row and button the test taps after scrolling is first scrolled whole above the home indicator with `scrollUpUntilWhole`, the helper the audits already use, which finishes in short drags until the element's bottom edge is 40 points above the window's.
That is the 6×6, 16mm and Super 8 rows, the Disposable row of the low-storage tests and the 16mm Black and white button.

## ContentSizeTests.testLandscapeSettingsTopTextAtAccessibilityExtraExtraExtraLarge (run 38473025368)

### Failure

"Test exceeded execution time allowance of 3 minutes", with no assertion.
The recording of that run was cut off unfinished when the test was stopped, so the steps and screenshots in the result bundle are the evidence.

### Cause

The measuring loop checks each element's top edge in a pose where the edge is on screen with at least 50 points of the element below it, and drags 262 points at a time in landscape, so that every edge lands in such a pose.
In the pose where it measured "Trial rule", the top edge of "Trial record" sat a few points above the window's lower limit, too little of the paragraph shown to check it.
The next drag took 4.3 seconds instead of the usual 2.3, and the screenshot after it, where the loop checked the paragraph's bottom edge, shows the list moved about 330 points, so its top edge was already under the navigation bar.
The loop only ever dragged on toward the end, so it never saw that edge again and dragged until the 3 minutes ran out.
A drag carrying the list further than its length is what a loaded runner can do; the loop has to cope with it.

### Fix

After each pose the loop looks for an element whose unchecked edge has passed the window in the direction it is scrolling (a top edge above the navigation bar going down the list, a bottom edge below the home indicator going up it).
If there is one, the next drag brings that edge back to the middle of the window, at most a step at a time, instead of moving on.
What is measured and every assertion on it are unchanged.

### Proof

A build of the tests that is not committed adds a second drag of 60% of a step after every other drag, the overshoot CI saw, and can turn the new correction off.
Run on an iOS 26.5 iPhone 17 Pro simulator here, with `testLandscapeSettingsTopTextAtAccessibilityExtraExtraExtraLarge` and `testLoadScreenTextAtAccessibilityExtraExtraExtraLarge`:

| Overshoot | Correction | Landscape Settings top, AX XXXL | Super 8 and 16mm Load screens, AX XXXL |
| --- | --- | --- | --- |
| every other drag | off | exceeded the 3-minute allowance after 27 overshoots, as on CI | passed |
| every other drag | on | passed in 87 seconds, dragging back 3 times | passed |

On the Load screens no injected overshoot carried an edge past the window, so that test passed either way.

## Run 38403410314 (5c3a217): cancelled

Its first attempt was the check as one job, before the check was split into parts (d82c6fa).
That job ran the screen tests for 46 minutes and the dark audits for 11, and was cancelled by its own 120-minute limit a minute into the StoreKit phase, its last, with no test failure.
Its second attempt, a rerun, never got a runner and was cancelled 15 minutes later without running a step.
Neither needs a change: the four parts now run side by side with 75 minutes each.

## Repeated runs

On this Mac (Intel, Xcode 26.5), with `IMMERSE_VALIDATE_PART` as CI sets it and each billing simulator new and never booted:

| Run | Part | Result | Minutes |
| --- | --- | --- | --- |
| 1 | ui-text | 72 of 72 `ContentSizeTests` passed, no rerun | 45 |
| 1 | packages | all Mac package tests, 112 RenderCore tests in the simulator (111 passed, 1 skipped) and 57 app tests with StoreKit passed; trustd skipped its update from the billing simulator's first boot | 21 |
| 2 | ui-text | 72 of 72 passed, no rerun | 47 |
| 2 | packages | the same, all passed; trustd skipped its update at each of its 3 checks and downloaded nothing | 19 |
| 1 | ui-flows | 23 of 24 screen tests passed in light and 20 of 21 audits in dark, the one left in each being `testAuditStillReportsContrastFindingsOutsideItsExceptions`, which expects its failure; no rerun | 39 |
| 1 | harness | 45 of 45 passed | 33 |
| 3 | ui-text | 72 of 72 passed, no rerun, with every tap through `tapWhole` | 48 |
| 2 | ui-flows | 23 of 24 passed in light and 20 of 21 in dark, the one left in each expecting its failure; no rerun, with the final `tapWhole` | 48 |

The ui-text part runs in light only, as on CI, and the packages and harness parts have no appearance setting.
ui-flows and harness ran once because the quiet script, which every part uses, changed.

## The same sliver tap in the other screen tests

`MovieCapacityUITests`, `JournalFlowTests`, `TestingUnlockUITests` and `deleteFilm` in `UITestSupport.swift` also scrolled with free swipes only until `isHittable` and then tapped, so the same tap on a sliver could happen there, though none failed in these runs.
`FilmStockUITests`, `LowStorageUITests` and the extra-small audits in `JournalFlowTests` scrolled in held drags, but also only until `isHittable`, before their taps.
Every such tap now goes through one helper, `tapWhole` in `UITestSupport.swift`, which scrolls with `scrollUpUntilWhole`, asserts the whole element is on screen and then taps; where a test only checks an element after scrolling to it, it uses `scrollUpUntilWhole` alone.
`MovieCapacityUITests` taps Load Film just after typing the Film's title, so with a keyboard raised "on screen" means 15 points clear of the keyboard, and a scrolling drag starts above it rather than on it, where it would type.
On iOS 26.5 the keyboard's panel is drawn 45 points above the frame its accessibility element reports (from y 538, against 583, on an iPhone 17 Pro), which the helper allows for.
The first version took the reported frame as the keyboard's top: its drags started on the panel, the list never moved and both Movie tests failed, and a second version demanded the home indicator's 40-point margin above the keyboard as well, which the list cannot reach.
With no keyboard raised the limit is 40 points above the window's bottom edge and the drags start where they did, so the audit poses that use them do not move.
Screen tests in `Probes/PopulatedJournalHarness` still scroll until `isHittable` before some taps; the harness belongs to the low-storage test cleanup, which owns its Crop switch tap.

## Node.js 20 actions

GitHub warned on every part that `actions/checkout@v4` and `actions/upload-artifact@v4` target Node.js 20 and were being run on Node.js 24.
`.github/workflows/native.yml` now uses `actions/checkout@v7`, `actions/upload-artifact@v7` and `actions/download-artifact@v8` (the summary job's, also on Node.js 20), whose `action.yml` each declare `node24`.
Their release notes since v4 hold no change to the inputs this workflow uses.
checkout v6 keeps persisted credentials in a separate file, and v7 refuses to check out a fork for `pull_request_target` and `workflow_run`, events this workflow does not use.
upload-artifact v7 adds an `archive` input that defaults to the zipped upload used now.
download-artifact v5 changed where a single artifact downloaded by ID lands, while this workflow downloads by `pattern` into one folder per artifact, which is unchanged.
download-artifact v8 fails on a digest mismatch instead of warning, and leaves files that are not zipped as they are.

## Launches that timed out on a fresh harness simulator (run 38724598104, not fixed)

The harness part of a later pull request's check (run 38724598104, on the low-storage cleanup's branch) failed its first two app launches with "Failed to get background assertion for target app ... Timed out while acquiring background assertion"; its other 43 tests passed.
The simulator's log in its result bundle shows the sequence:

- testmanagerd set the system-wide accessibility messaging timeout to 60 seconds at 11:13:02.312, and its request for the test runner's process assertion was answered at 11:13:02.320.
- SpringBoard finished loading its accessibility support at 11:13:02.605; the simulator had booted about six minutes earlier, and this was the test session's first launch.
- At 11:13:02.613 testmanagerd opened a side connection to runningboardd and looked up SpringBoard's process; that thread then logged nothing for exactly 60 seconds.
- Its requests for the two launched apps' assertions (11:13:24.692 and 11:13:39.671) reached runningboardd only at 11:14:02.526, together, after both launches had given up.
- runningboardd itself was busy throughout, so it was testmanagerd's requests that waited, most likely behind an accessibility call to SpringBoard that ran out its 60 seconds.
- apsd logged about 2,000 lines a second for the whole run, before, during and after; the billing simulator of run 38569804164 shows the same, and nothing ties it to this minute.

Here, three fresh iOS 26.5 simulators prepared as validation prepares them ran the same first suites (`CameraPermissionWorkflowTests` and `LowStorageWorkflowTests`, 6 tests) at once after boot.
Every assertion request was answered within 0.01 seconds, SpringBoard loaded its accessibility support at the first launch 22 to 28 seconds after boot, and every test passed.
The stall was not reproduced, so no settle step (a longer wait for the boot, switching apsd off, or a warm-up launch before the tests) can be shown to prevent it, and none was added; a launch retry would only hide it.
If it recurs, the same three lines in the simulator's log (the 60-second accessibility timeout, SpringBoard's accessibility status change and the late assertion requests) will tell it apart.

## Seen, not changed

- The hosted app tests log "BUG IN CLIENT OF libsqlite3.dylib: database integrity compromised by API violation: vnode unlinked while in use" many times: tests remove a Journal's temporary directory while its Film store is still open.
