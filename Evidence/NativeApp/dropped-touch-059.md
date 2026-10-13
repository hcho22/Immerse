# Dropped Touch And The Four-Part Check 059

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work.
On 2026-10-13 the one check, `local-native`, failed on a pull request that changed six Markdown files (run 38412185318, attempt 1), and was cancelled at its 120-minute limit on `main` (run 38403410314), on the commit that added the per-Camera looks.
This record covers both, and the changes to the check that followed.
It covers simulator evidence for the automated tests only.

## The failed test

`PopulatedWorkflowTests.testSixBySixBlackAndWhiteLookScreens()` failed in the harness with three failures.
The Film screen did not appear within 5 seconds of the tap on the Journal's Film card, "Open photo 1" did not appear in 60 seconds, and the tap on it found no such button.
The Journal was still showing with the Film developed.
The card's label read "Developed photo 1, Developed photo 2", and the screenshot shows two gray prints.
The test took 78 seconds where it takes 15.

### What the evidence shows

- The tap aimed at (201, 387), the centre of the card's frame.
- The test tapped 0.5 seconds after it first saw the Journal.
  The other 34 launches of that run tapped 0.2 to 0.9 seconds after, and each reached its next screen in 1.1 to 1.4 seconds.
- The screen recording shows the Journal fully drawn before the tap and no change after it.
- The look was not involved.
  The run differs from the last passing run by six Markdown files.
  The 6×6 black-and-white prints of both runs have the same mean gray, 147.69, and differ as grain does, by at most 1 of 255 over 24-pixel blocks.
  Three other tests that develop the same Film passed in the failed run.

### Mechanism

A CI result bundle holds the simulator's own log.
`xcrun xcresulttool export diagnostics` writes it out, and `log show --archive` reads its `system.logarchive`.

XCTest sends every synthesized touch through a new virtual touchscreen that it attaches for that one gesture.
For a tap that works, the simulator's touch service, `backboardd`, logs the touchscreen attached, one touch state, the finger down, the finger up 70 ms later, and the touchscreen detached with no contact left.
For the lost tap it logged this, in order:

- `unknown senderID`: the touchscreen's first event arrived before `backboardd` had registered the touchscreen.
- `digitizer attached` and a touch state on one thread, then `*** unknown digitizer` and a second touch state on the thread that took the event.
- `contact 2 presence: touching`: the finger down, recorded in the second state.
- `didn't see a previous touch down or range-in event for pathIndex:2; skipping event`, seven times.
- No `contact 2 presence: none`: the finger up never arrived.
- 170 ms later, `digitizer detached` and `canceling paths` with the contact still touching.

So the app received a touch that began and was cancelled, and a cancelled touch never fires a button.
The reading of a race between two threads comes from the thread ids and the order of the messages, not from `backboardd`'s source.

### How often

Synthesized touches in the simulator logs of every failed run from 2026-10-04 to 2026-10-13 that kept a result bundle, and of two passing runs.

| Run | Date | Bundle | Touches | Without a finger-up | Discard records |
| --- | --- | --- | --- | --- | --- |
| 37198793094 | 10-04 | harness | 150 | 0 | 0 |
| 37198793094 | 10-04 | app screen tests | 220 | 0 | 0 |
| 37263774724 | 10-05 | harness | 150 | 0 | 0 |
| 37263774724 | 10-05 | app screen tests | 422 | 0 | 0 |
| 37496261155 | 10-06 | harness | 150 | 0 | 0 |
| 37496261155 | 10-06 | app screen tests | 446 | 0 | 0 |
| 37627486582 | 10-07 | harness | 149 | 0 | 0 |
| 37627486582 | 10-07 | app screen tests | 445 | 1 | 7 |
| 37725735419 | 10-08 | harness | 149 | 0 | 0 |
| 37725735419 | 10-08 | app screen tests | 435 | 0 | 0 |
| 37788441803 | 10-08 | harness | 211 | 0 | 0 |
| 37788441803 | 10-08 | app screen tests | 472 | 1 | 7 |
| 37986511645, passed | 10-09 | harness | 240 | 0 | 0 |
| 38359655188, passed | 10-13 | harness | 250 | 0 | 0 |
| 38412185318, attempt 1 | 10-13 | harness | 250 | 1 | 7 |

Of 4,139 touches, three lost their finger-up, each with the discard records, and each at the second of a tap that failed a test:

- Run 37627486582: the tap on Start a Film that `ci-flakes-057.md` left unexplained.
- Run 37788441803: a tap on a Back button in `ContentSizeTests.testLandscapeSettingsTopTextAtLarge()`, which then failed to find Cancel.
- Run 38412185318: this tap on a Film card.

That is three of the 38 runs in those ten days.
The other failures in the same bundles have no discard record in their own time: a 3-minute timeout, a clipped-text audit finding and a wrong title-field value.

### Not provoked on demand

On an Intel Mac with 20 logical cores, Xcode 26.5 and an iOS 26.5 simulator, the test passed 30 times in 30.
A probe that sends counted taps to one button sent 2,400, 900 of them while a build loaded the machine, and every one arrived.
The simulator's log held no discard record.
The CI runner is GitHub's standard `macos-26` runner, an Apple silicon virtual machine with 3 cores and 7 GB.
Which difference exposes the fault is not established.

The second attempt of run 38412185318 passed the same test and all 30 harness tests, and was then cancelled at the 120-minute limit.

## The rule against a second tap, narrowed

Record 057 gave a test one tap and no retry, because a second tap would hide a real defect.
That stays true for a tap the app ignored.
A tap the simulator dropped is a different thing, and the simulator's log says which of the two happened.

The captain was asked on 2026-10-13: "When a screen test fails and the simulator's own log proves it dropped that test's tap, may the check rerun that one test once and go green? Any other failure still fails, and a failed rerun fails. This narrows the project's existing rule against a second tap."
His answer, to this and the two questions put with it: "yes to all".

`Scripts/screen-tests.sh` now runs the harness and the app's screen tests.
When a run fails, `Scripts/dropped-touch-tests.py` reads that simulator's log for `backboardd`'s discard record inside each failed test's time window.
Only when every failed test has one are those tests run once more, alone, into a second result bundle.
A failure without the record fails, a failed rerun fails, and a run that passed through a rerun says so in its log, in a warning on the run and in the summary check.
Xcode's `-retry-tests-on-failure` is not used, since it reruns any failure.
The `*** unknown digitizer` record alone is not proof.
It says an event came early, not that one was lost.

`Scripts/Tests` holds the rule to fixtures cut from the three runs.
It excuses the three dropped taps, and not the timeout or the clipped-text finding that failed beside two of them.

## The check's time

### Where two hours went

Minutes by phase, from the job logs of the last passing run before the looks (0e69ed2), the last passing run (961f796, the same tree as `main` at 5c3a217), and the cancelled run on `main`.

| Phase | 0e69ed2 | 961f796 | 5c3a217, cancelled |
| --- | --- | --- | --- |
| Runner setup, checkout, simulators created | 0.7 | 1.3 | 2.1 |
| Package tests and probes on the Mac | 10.7 | 10.4 | 12.5 |
| Document package, app builds, Release check | 4.2 | 2.9 | 3.8 |
| Harness: first simulator boot, build, tests | 27.8 | 25.0 | 31.7 |
| RenderCore tests in the simulator | not yet added | 5.0 | 5.4 |
| App screen tests, light | 46.0 | 46.6 | 47.1 |
| App screen tests, dark audits | 9.7 | 10.4 | 10.9 |
| StoreKit: first simulator boot, build, tests | 7.4 | 8.7 | stopped 54 s into its tests |
| Artifact upload and cleanup | 1.7 | 2.6 | 1.4 |
| Job | 108.2 | 112.9 | stopped at 121 |

- Screen tests on one simulator were 82 of the 113 minutes, run one after another on a 3-core runner.
  `ContentSizeTests` alone was 33 minutes.
- The looks change added about 10 minutes.
  RenderCore's Mac tests grew from 30 to 99, they now run again inside the simulator, and the harness gained seven look-screen tests.
- Runner speed moves the total by about 10 percent.
  One tree took 98 and 108 minutes on two runners.
  The next took 113 minutes once and was cancelled at 120 twice, the second time with six Markdown files added.
- No test failed in either cancelled run.
  Each was stopped within a minute of starting its last phase's tests.
- A faster runner would buy little.
  On the 20-core Mac the screen tests took the same minutes as on the runner, because they wait on the simulator.

### Four parts

`Scripts/validate-local.sh` still runs everything, in the same order, on a Mac.
CI runs it as four parts side by side, chosen with `IMMERSE_VALIDATE_PART`, each on its own runner with a 75-minute limit, behind a summary job that keeps the name `local-native`.

| Part | Holds | Minutes in this change's own checks |
| --- | --- | --- |
| packages | Mac package tests and probes, document package, app builds, Release check, RenderCore in the simulator, StoreKit | 39 and 40 |
| harness | the harness and its screen tests | 35, 39 and 34 |
| ui-text | `ContentSizeTests` | 38, 52 and 49 |
| ui-flows | every other suite of the app's screen tests, then the dark audits | 40 |

Those are the jobs' times on GitHub, from start to end, in runs 38444526282, 38445842024 and 38457648520.
The last of the three was green, and took 51 minutes from its start to its summary check.
The first two carried a planted failing test that stopped ui-flows before its dark audits, and a fault in the scripts' own tests stopped packages in the first.

The parts take longer than the single job's phases suggested, which was 28 to 41 minutes each.
One runner differs from the next by up to a third.
`ContentSizeTests` took 32 minutes of test time on one runner and 43 on another, and the harness tests 26 and 29 against 20 in the last single job.
So a part can pass 50 minutes, and the 75-minute limit is 23 minutes over the slowest part seen.

No test left the check.
`Scripts/validation-parts.sh` says what each part holds.
`Scripts/verify-validation-parts.sh` fails when a package, probe, test target or named suite belongs to no part, so one added later cannot fall out unnoticed.
`Scripts/Tests/test_validate_local.py` holds the four parts together to what the whole script runs.

Each part's order was tried on a new simulator before the split.
The 17 other light tests and then the 14 dark audits passed without `ContentSizeTests` before them, `ContentSizeTests` passed alone, and RenderCore's simulator tests passed on a simulator no other test had used.

### Markdown-only pull requests

The captain was also asked on 2026-10-13: "May a pull request that changes only documents skip the simulator jobs?"
His answer was the same "yes to all".

A pull request whose changed files are all Markdown runs the packages part alone, which holds the document checks and every test that drives no screen.
The summary check says that harness, ui-text and ui-flows were skipped, and why.
Any other file in the change runs all four parts, and so does every push to `main`.
Markdown under `App` or the harness probe counts as code, because Xcode bundles what it finds in their source directories.
`Scripts/validation-scope.sh` decides, and its tests include the six files of the pull request that failed on 2026-10-13.

### Runners

GitHub's standard macOS runners are free for a public repository, and an account that is not on an Enterprise plan runs 5 macOS jobs at once (GitHub's Actions limits page, read 2026-10-13).
One run of the check uses four, so a second run started at the same time finds one runner free.
The limits page does not say what happens to the jobs above the limit, so this change's own checks were made to overlap.
With five macOS jobs running, the next two parts stayed queued for 17 and 25 minutes, and each started within three minutes of a running job ending.
Jobs above the limit wait, then, and nothing fails.
The 75 minutes are, by GitHub's definition of the setting, the time a job runs and not the time it waits.

GitHub can also be short of runners, whatever the account's limit.
On 2026-10-13 it noted "Due to capacity constraints, jobs targeting macOS arm64 runners may experience longer queue times" on its jobs.
Later that day two parts waited 26 and 31 minutes with fewer than five macOS jobs of the repository running, then started and ran as usual.
Twice that day GitHub gave up on jobs it had no runner for, with "The job was not acquired by Runner of type hosted even after multiple attempts".
The first time it cancelled a job after 15 minutes.
The second time it cancelled the harness and ui-flows parts of run 38449942720 after 55 minutes, while that run's other two parts were running.
The summary check is then red through no fault of the change, and rerunning the failed job reruns that part alone.

## Validation

- `python3 -m unittest discover -s Scripts/Tests`: the rerun rule against the three runs' fixtures in both directions, a failed rerun, an unreadable log, what each part runs, the parts against the whole, the guard against a copy of the repository broken in one way per test, and the Markdown-only rule.
  The packages part runs these first.
- The rerun's own machinery on a real simulator, with a planted test that fails once after one tap.
  With the real rule the failure stood and nothing was rerun.
  With a stand-in record that every touch leaves, the test was rerun alone, passed, and the run said so.
  With a test that fails every time, the rerun failed and so did the run.
- On GitHub, in this change's own checks, a planted failing screen test with no discard in the simulator's log failed ui-flows without a rerun, and `local-native` was red while the other three parts passed (run 38445842024).
  The commit after it removed the planted test.
- Not exercised: a real dropped touch on demand.
  The real discard record has been read only from the three collected logs.
- Not exercised on GitHub: the Markdown-only rule, which needs a pull request that changes Markdown alone.
