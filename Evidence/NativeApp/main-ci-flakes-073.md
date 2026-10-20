# Main CI Flakes 073

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work, and start a bug fix from the failure as a person would meet it.
On 2026-10-19 `CaptureSidewaysUITests.testDisposableShootingScreenKeepsItsLayoutHeldSideways` ran past XCTest's 3-minute allowance in the ui-flows part twice: in run 39292846150 (the last section of record 072) and in attempt 1 of run 39307626086, which already had record 072's launch before each class.
A third run, 39299169914 on `main` at b9b834a, passed it in 177.8 s.
This record names why the test runs out of time on a slow runner, which lead of record 072 (the simulator's `apsd` retry loop) it excludes, what was reproduced here and what was not, and what changed.
GitHub's Macs are Apple silicon with 3 CPUs and 7 GB, and this Mac is Intel with 20 logical cores.
Every number from CI below is read from the run's own result bundle (`xcresulttool`, `log show --archive` on its `system.logarchive`, and the spindump XCTest took at the allowance).
Times are UTC, on 2026-10-19.

The stalls that carry the test past its limit come at the start of the session, in four of the seven runs read, and what makes them is not shown.
What is shown is that the test spent half of its own time in waits that cost a second each when the element was already there, and that is what changed.

## What failed

| Run | Test | Message | Ran |
| --- | --- | --- | --- |
| 39307626086, attempt 1 | `testDisposableShootingScreenKeepsItsLayoutHeldSideways` | `UITestSupport.swift:138: failed - The Camera catalog did not open within 5 seconds of the tap on Start a Film`, then `Test exceeded execution time allowance of 3 minutes` | 19:12:07 to 19:15:07 |

Attempt 2 passed it in 127.8 s.
The test had loaded its Film and measured the shooting screen in all three holds, turned the Film screen and relaunched, and the allowance stopped it a third of a second into its last wait, for the deleted Film's actions to go.
It is not the Darkroom animation stall of record 069: its activity log has no "App animations complete notification not received", and its 35 waits for the app to idle carry no such note.
It is not a dropped touch: `Scripts/dropped-touch-tests.py` on the run's bundle and log archive finds no discarded touch in the test's window, and the log has no "didn't see a previous touch down".

## Where the time went

In attempt 1 six single operations took 6.6 to 25.3 s each, 72 s together, in a test that takes about 100 s when nothing stalls:

| Time into the test | Operation | Took |
| --- | --- | --- |
| 14 s | the synthesized tap on Start a Film, the session's first tap | 17.8 s |
| 37 s | the screenshot of the miss (see below), the session's first | 25.3 s |
| 99 s | the first turn to landscape | 7.5 s |
| 124 s | reading the shooting screen's frames | 7.4 s |
| 149 s | the relaunch to delete the Film | 7.2 s |
| 156 s | setting up the automation session of that launch | 6.6 s |

The first tap is what failed.
The tap was played at 19:12:33.6 and the sheet did not show in the 5 s the test gave it, so `openCameraCatalog` failed the test, spent 30 s on debug descriptions and a screenshot of the Journal, and the test went on, since the sheet did come.
In the simulator's log `backboardd` took the finger down at 19:12:43.1 and up at 19:12:49.45 ("EventType 11 from 15.75 seconds in the past"), and the app's first UIEvent of the tap came at 19:12:49.458, 15.7 s after XCTest played it.
The 5 s window had closed at 19:12:43.7, 5.7 s before that.
In the same stretch SpringBoard logged "Finished getting 21 applications, took 19.213625 seconds" and an extension it had asked to launch was ended by the watchdog ("launch failed", 15.6 s after the request).
The whole simulator was slow, not the app: its main run loop answered the idle request the moment it was asked (19:12:39.015).

The same test in every ui-flows bundle read, with the seconds that single operations took beyond 3 s (accessibility-tree dumps and the 1 s polls left out) in it and in the test after it:

| Run | The Disposable's test | Stall seconds in it | In the next test | The test less its stalls |
| --- | --- | --- | --- | --- |
| 39202888924 (pull request 43) | 103 s | 15.9 | 10.1 | 87 s |
| 39252986897 (`main`, d348d99) | 149 s | 65.8 | 6.6 | 83 s |
| 39299169914 (`main`, b9b834a) | 178 s | 79.8 | 19.6 | 98 s |
| 39292846150 (pull request 45) | 180 s, stopped | 84.6 | 0.0 | |
| 39307626086 attempt 1 | 180 s, stopped | 92.5 | 6.9 | |
| 39307626086 attempt 2 | 128 s | 25.0 | 6.6 | 103 s |
| 39342462086 (`main`, d1ce143) | 105 s | 3.9 | 8.7 | 101 s |

Every other test in these runs has at most 22 s of stalls and most have none, so the stalls are at the start of the session, in whichever test comes first.
The test less its stalls is 83 to 103 s every time, so its time is about 95 s of its own and whatever the runner stalls, and 3 minutes holds up to about 85 s of stalls.
Two of the seven runs had as many or more and were stopped, and two more came within 30 s.

The test's own 95 s is where this change works.
Of 127 s in attempt 2, `waitForExistence` and `waitForNonExistence` took 50 s over 40 calls (the next test, which does the same steps, 44 s over 39 calls), because each returns no sooner than about a second after it is called, even for an element that is already there: 1.04 s at the median over the 387 calls of attempt 1, in the seconds `apsd` was busy and in the seconds it was not.
Most of the 40 calls are for an element that is there, read three at a time by `layout(_:)` after every turn of the screen.

## The runner's `apsd`

Record 072 named the simulator's `apsd` retry loop (1,300 to 3,600 lines a second) as a lead and measured nothing against it.
It is measured here and it is not the cause of this test's overrun.

What the loop is: `apsd` connects to Apple's sandbox push courier on port 5223 and completes a TLS 1.3 handshake, asks the simulator for a certificate and is refused (`MobileActivation` error -25, "Client is not supported"), disconnects ("Refreshing cert/nonce/sig failed, not sending a presence", reason 14) and connects again at once, 12 times a second at its slowest and 39 times a second in its busy stretches.
Each turn sends every push client in the simulator (a dozen daemons) a "connectionStatusChange", and about every other turn asks `trustd` for a trust evaluation.
It is 3.8 million of the 5.8 million log lines of attempt 1's archive, 66 %, in an archive of 292 MB.
A simulator on this Mac makes none of it (no line in 10 minutes).

| What was read | Attempt 1 of run 39307626086 | Run 39292846150 |
| --- | --- | --- |
| `apsd` lines a second, median, busiest second | 1,326, 4,965 | 1,652, 2,323 |
| seconds at 2,500 lines a second or more | 623 of 1,977 | 0 of 1,978 |
| the test stalled | yes (stalls from 6.6 to 25.3 s) | yes (stalls from 5.8 to 32.1 s) |

- The run whose `apsd` stayed calm stalled the same way, and its worst stall (32.1 s, the app's idle wait during a launch) came while `apsd` logged 363 lines a second, a fifth of its usual: the simulator was making little progress, not too much.
- Within attempt 1, over all of its 29 tests and 5,754 operations, the operations took the same time in the seconds of 2,500 lines or more as in the others: `Synthesize event` 0.30 s against 0.31 s at the median, the waits for the app to idle 1.52 s against 1.45 s at the 90th percentile.
  A third of the run was in the busy seconds.
- Attempt 1's 25.3 s screenshot was in a calm second (1,138 lines), and its 17.8 s tap was in a busy one.
- The host's CPU was not used up either: the spindump XCTest took at the allowance finds 14.2 s of CPU over 5 s on 3 CPUs, of which 5.3 s was the spindump itself, `apsd` 1.0 s and the simulator's `diagnosticd`, which writes the log, 2.4 s; the other run's, at a calm `apsd`, 8.0 s of 15, 2.3 s of it the spindump, `apsd` 0.3 s and `diagnosticd` 0.8 s.
  `apsd` and `diagnosticd` together took 7 % of the machine's CPU in the calm sample and 23 % in the busy one, and no test was found waiting for it.

Whether it can be quieted: it is the service `user/foreground/com.apple.apsd`, which `launchctl disable` and `bootout` took down on a simulator here and which did not come back, with no other daemon's CPU rising in a minute after.
Its loop could not be reproduced here (it makes no lines), so how the push clients behave without it on CI, and what it saves there, are not shown.
Nothing the app does depends on push: it has no remote notification, `UserNotifications`, CloudKit or push entitlement code, and v1 has no server.
`Scripts/quiet-simulator.sh` is unchanged: the service is not what stalls this test, and a change to every part's simulator that cannot be shown to help is not made.
If a CI run is wanted for it, the comparison is `apsd`'s lines a second and `ps`'s CPU time for it and for `diagnosticd` at the end of one part with the service down and one without.

## Why the test ran out of time

- The trigger is a stall of the simulator at the start of the session, 66 to 93 s of it in the first test in four of the seven runs and shorter stalls to the end of the next.
  What stalls it is not shown: not `apsd`, not CPU use of the host at the end of the test, not a dropped touch.
  The first tap, the first screenshot and the first turn were each 4 to 25 s where every later one was under 3 s, which points at the first use of a path (a cold start) and not at the clock.
- What hid it in every other run is that the test, at about 95 s of its own, had room for up to 85 s of stalls, and the first test of the session had them in only some of the runs.
- The symptom is the allowance, and, when the stall comes at the first tap, the 5 s catalog wait failing first: the miss path then costs the test 30 s of screenshots on a runner that is already slow.

What would show this wrong: a run of the fixed test with its own time (its time less its stalls) over about 70 s on a quiet runner, which the 50 s of polls make unlikely, or a run with the stalls and no first-use cost whose first test still fails with under 85 s of stalls.

## Reproduced

The stalls did not happen here: a fresh simulator, made and quieted as validation makes them, ran the test with no operation over 2.3 s, its first screenshot taking 0.4 s.
The test's own length did reproduce, and so did what it is made of.

| The test, on a fresh simulator, no load (this Mac) | Before | After |
| --- | --- | --- |
| the Disposable's test alone | 89.3 s, 39 waits of 44.4 s (50 %) | 43.4 s, 6 waits of 6.2 s |
| the five tests of the class, in turn | 78.6, 77.1, 81.7, 115.9 (largest text), 79.2 s | 44.6, 44.8, 46.3, 74.5 (largest text), 43.9 s |

Run alternately on the same simulator, the changed tests and the tests as they were on `main`, each class as one `xcodebuild` session, the Disposable's test first:

| Condition on this Mac, the class's five tests (Disposable, Instant, 6×6, 6×6 at the largest text size, Super 8) | As on `main` | Changed |
| --- | --- | --- |
| no load | 78.6, 77.1, 81.7, 115.9, 79.2 s | 44.6, 44.8, 46.3, 74.5, 43.9 s |
| 40 busy loops, and another job's load on the Mac (2 runs) | 112.3, 110.5, 125.2, 167.4, 110.6 s and 111.8, 111.9, 118.8, 169.0, 112.8 s | 74.0, 75.0, 85.5, 133.0, 85.6 s and 82.3, 81.5, 89.1, 136.7, 81.1 s |
| 80 busy loops, 4 times the cores (1 run) | not made: `xcodebuild` itself stopped on an assertion while installing the app | 72.7, 74.8, 83.5, 164.9, 106.7 s |

The changed tests are 25 to 41 s faster in each pair of runs, mostly the polls, which cost the same wall-clock time on any runner.
The one test that stays near its limit under load is the 6×6 at the largest text size, which is held drags that scroll the Camera catalog (31 s of 74) and is not made of polls any more (6 s of 74, against 48 s of 115 before).

To meet the changed tests' risk, which is that a wait that was a second long also let a screen settle, the simulator's SpringBoard and `backboardd` were stopped for 4 to 16 s every 8 to 20 s while the class ran (a script here, not committed; 22 to 38 stops, 232 to 364 s of stop in a run), which is harder than CI's stalls (at most 93 s in one test, none in most):

| Stops, the five tests in order | As on `main` | Changed |
| --- | --- | --- |
| run 1 (38 stops as on `main`, 32 changed) | Disposable failed (the orientation change was not confirmed), 148.3, 152.4, 6×6 largest stopped at 180, 173.8 s | 102.0, 119.2, 142.0, 6×6 largest stopped at 180, Super 8 failed (the orientation change was not confirmed) |
| run 2 (29 stops as on `main`, 22 changed) | 123.9, Instant failed (the orientation change was not confirmed), 130.8, 6×6 largest stopped at 180, 129.9 s | 91.6, 106.2, 81.9, 158.1, 75.4 s, all passed |

Both versions fail on XCTest's "Timed out waiting for confirmation of orientation change", which a stop of SpringBoard over its limit causes, and on the allowance in the largest-text test.
No failure of another kind came with the change: no assertion about the layout, the viewfinder, Done or the Film screen failed, which a screen read before it settled would have.

## Fix

Four changes, in `UITestSupport.swift` and `CaptureSidewaysUITests.swift`.

- `exists(within:)` and `isGone(within:)` on `XCUIElement` answer at once for an element that is already there or already gone and wait as `waitForExistence` and `waitForNonExistence` did, for the same timeout, for one that is not.
  They are used for the elements that are there in a steady state and for the final states a test asserts: the Journal's Start a Film button and empty-state text in `launchWithEmptyJournal` and `openCameraCatalog`, the Journal and the Film's row in `deleteFilm(titled:)` and `deleteFilm(at:)`, Done and the Film screen in the shooting screen's tests, and the three elements `layout(_:)` reads.
  They are not used where a screen is coming up and the next step reads its geometry: the catalog sheet after the tap on Start a Film, the Load screen after a Camera's row and the Film screen after Load Film, which keep `waitForExistence` and `waitForNonExistence`, as does the Film's row after a relaunch.
  The tests make 6 such calls where they made 40.
- `wait(_:until:)` in `CaptureSidewaysUITests` took its settling from `layout(_:)`'s three waits of a second each, so it now asks for it: it reads the layout every half second until the predicate holds and two reads in a row are equal, for up to 30 s, and returns what it last read, for the caller's assertions to fail on.
  The first read of each test, upright, goes through it, which the second of waiting did before without saying so.
  Every assertion of the tests is as it was.
- `ScreenTestCase.setUp` makes the session's first tap (Start a Film, if it is there) and first screenshot, with the launch it already made, before the class's first test.
  The first tap's check for interrupting elements took 3.9, 4.7 and 7.2 s in three of the bundles, and the first screenshot 4.7, 9.5 and 25.3 s in three, where every later one took under a second.
  Nothing is asserted there, and it runs before any test's allowance, as record 072's launch does.
  What this saves on CI is not measured: a fresh simulator here showed no first-use cost at all (above).
- `openCameraCatalog` waits 30 s for the sheet, not 5.
  The finger reached the app 15.7 s after it was played in attempt 1, and the longest single stall read on CI is 32 s.
  A tap that never arrives still fails, 25 s later, with the same screenshot.

On CI the test should take about 65 s of its own where it took 95, so that 3 minutes holds up to about 120 s of stalls where it held 85, and the stalls that stopped it (84.6 and 92.5 s) leave it at 150 to 158 s.
The first tap and the first screenshot were 43 s of attempt 1's 92.5 s of stalls and are no longer in the test.
This is arithmetic from the runs above, not a CI result, which the pull request's checks are.

## Repeated runs

On this Mac, as above, with the changes in this record.

| What | Result |
| --- | --- |
| the Disposable's test alone | 43.4 s, passed |
| the class, no load, 40 busy loops (2 runs), 80 busy loops | 5 of 5 passed in each of the 4 runs; with stops, 3 of 5 and 5 of 5, where the tests as on `main` passed 3 of 5 in both |
| the whole ui-flows selection of light appearance (29 tests, in order, as validation runs it) | passed; the Disposable's test 44.8 s, the Instant's 50.6, the 6×6's 58.8, the largest text 91.7, the Super 8's 55.9; the longest test, 16mm Film Stock, 116.8 s with a 60 s wait described below |
| the four suites validation runs again in dark (21 tests) | passed |
| `FilmStockUITests` in turn, 4 times each | 12 of 12 passed with the change (40.4 to 43.1 s a Camera's test), 12 of 12 as on `main` (49.7 to 52.2 s) |

An earlier full run overlapped another job's load on the Mac (a load average near 1,000) and four tests stopped at the allowance; it is not counted, and no result of it is used here.

## One 60 s idle wait in a passing test, with record 069's note

In the full light run, `FilmStockUITests.testSixteenMillimeterLoadsOnTheBlackAndWhiteFilmStock` waited 60.0 s for the app to idle right after the tap that answers the Camera request (the nav bar tap that the interruption monitor turns into "Allow"), and XCTest's activity log says "App animations complete notification not received, will attempt to continue."
That is the note of record 069's stall, the one the captain decided to wait on.
The test passed, in 116.8 s, and nothing was changed for it.
It happened once: the note is in none of the 203 test runs of the seven CI ui-flows bundles read for this record, in none of 38 runs here with the tests as on `main`, and in one of 93 here with the change, and `FilmStockUITests` alone, 12 times each way, did not show it.
The Mac's log no longer held the app's own lines of that minute, so whether the app logged the request without a reply, the other half of 069's signature, is not shown.
It is a different screen from the Darkroom of record 069 and there was no turn of the device before it.
It is given to him with this record as a possible second sighting and is not treated as one here.

## What is not shown, and what is left

- What stalls the simulator at the start of a session is not shown.
  The reads that bear on it: SpringBoard took 19.2 s to list its apps at the start of the test, the watchdog ended an extension SpringBoard had asked to launch 15.6 s earlier, `backboardd` held a finger for 15.7 s, and the host was not out of CPU outside the spindump's own use.
  The first test of the session met 66 to 93 s of stalls in four of the seven runs, the second 0 to 20 s, and the rest 0 to 22 s.
  One reading is the simulator settling after its first boot while the build before the tests had the machine; no run has measured that.
  The next sighting is read from the result bundle as here: the gaps between a test's activities of 3 s or more, taken per test in order, and the first test's against the others'.
- `apsd` is left running.
  If the captain wants it quieted, the CI comparison named above is what shows whether it matters, and the mechanism is `launchctl disable` and `bootout` of `user/foreground/com.apple.apsd` after the boot, as `Scripts/quiet-simulator.sh` does for `mediaanalysisd`.
- The stalls that remain on CI are not removed, only made affordable.
  A first test with more than about 120 s of stalls still fails its allowance.
- The 6×6 at the largest text size is the class's longest test, at 74.5 s here and 100 to 150 s on CI, and the one that stopped at the allowance in the harsher runs here.
  Its time is held drags, which the polls did not make and this change does not shorten.
- The other suites keep their `waitForExistence` calls apart from the helpers above.
  Each may be a settle that something depends on, and each was not measured; the 40 calls of this test were.

## Everything left as it was

The app's sources are unchanged.
No assertion was loosened or removed in the tests, no audit exception was added, the per-test allowance is still 3 minutes, the dropped-touch rerun and its record are as they were, no test was skipped, and the simulator's setup in `Scripts/quiet-simulator.sh` is as it was.
The only wait made longer is the catalog's, from 5 to 30 s, for a stall read on CI, and it returns at once when the sheet shows.
The Darkroom animation stall of record 069 stays with the captain.
After this merges, the manual iPhone test plan's pin in `Evidence/NativeApp/manual-validation.md` is re-pinned as after the earlier tests-only changes.
