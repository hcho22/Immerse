# Main CI Flakes 075

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work, and start a bug fix from the failure as a person would meet it.
Record 073 left one thing open: the first test of a screen-test session met up to 93 s of simulator stalls on CI whose cause it did not find, and its change only made that test affordable.
This record names what those stalls are, what was tried against them on CI and what each showed, what changed, and what is still not shown.
GitHub's Macs are Apple silicon virtual machines with 3 CPUs and 7 GB, and the Mac the tests are written on is an Intel one with 20 logical cores, where none of this reproduces.
So every number below is read from CI: the result bundles of the runs named (`xcresulttool`), the simulator's `system.logarchive` where a failed run kept one, and samplers that ran beside the tests on experiment branches.
Times are UTC, on 2026-10-19 and 2026-10-20.
"Stall" means a gap of 3 s or more between two steps of a test in its activity log, as in record 073.

## What the stall is

It belongs to the first session on a freshly booted simulator, and it is gone from the second.
`Scripts/validate-local.sh` runs the ui-flows part's screen tests in light appearance and then runs four suites again in dark appearance, from the same build on the same simulator, 25 to 60 minutes later.
The first test of that second session had at most 4.4 s of stalls in all seven runs that have both, where the first test of the first session had 3.9, 15.9, 21.6, 25.0, 47.7, 65.8, 79.8 and 170.4 s in the eight runs read (run 39292846150's 170.4 s was stopped by the allowance).

| Run | First test of the light session | First test of the dark session |
| --- | --- | --- |
| 39202888924 | 15.9 s | 4.4 s |
| 39252986897 | 65.8 s | 3.2 s |
| 39299169914 | 79.8 s | 3.7 s |
| 39307626086 (attempt 2) | 25.0 s | 0.0 s |
| 39342462086 | 3.9 s | 0.0 s |
| 39363967185 | 21.6 s | 0.0 s |
| 39377185262 | 47.7 s | 0.0 s |

(The dark session's first test is `FilmStockUITests`' first, a shorter test, so its few seconds are not the same steps; the point is that none of the large ones come.)
The stalls sit in the first few minutes of the first session and then fade: in the same eight runs the second test had 0.0 to 19.6 s and the third mostly none.
The ui-text and harness parts show the same shape with smaller numbers: their first test had 4.2 to 38.8 s (ui-text, seven runs) and 0.0 to 23.8 s (harness, three runs).
It is not a function of how long the simulator had been up: the time from the job's validation step to the build's start, which holds the simulator's first boot, was 96 to 332 s in the eight runs, and the shortest and the longest were both followed by stalls of 65.8 s and 3.9 s.
It is not the first use of one path either: in a stalled first test the app's own launch, made after the class's `setUp` had already launched it once, still took 5.4 s, and setting up its automation session 12.2 s.

## The runner and the simulator on it

Read from the samplers of experiment runs (a `top` and a `vm_stat` every few seconds, a `ps` of the simulator's processes, `iostat`), with the caveat that the first, heavier sampler took 20 to 30 % of a core itself:

- The simulator is about 260 processes (236 on the Mac the tests are written on) with 2.8 GB resident, on a machine of 7 GB.
  Memory pressure reads "warn" from the start of the build to the end of the session, the compressor holds 2.4 to 2.7 GB, swap grows to 0.3 to 1.3 GB and the file cache shrinks from 3.6 GB to 0.8 GB, so the dyld cache and the simulator's frameworks are paged in from disk all the time (200 to 2,400 page-ins a second, 300 to 1,100 disk transactions a second on average).
- The runtime is a 9.9 GB compressed disk image served by `diskimagesiod`, which used 160 % of a core while the simulator booted, and a spindump of the 170 s stall of run 39292846150 has threads of dozens of simulator daemons (`searchd`, `weatherd`, `fileproviderd` and others) waiting in the disk image driver's request pool while the server's workers sit in reads of the image file.
- Storage itself is not slow when it is read cold at the start of a job: 64 random 16 KB reads of the image took 0.1 to 0.5 ms each and 512 MB read in 0.4 s (1.1 to 1.2 GB/s) on all three parts' runners.
- `apsd` (the push service) loops against Apple's courier (record 073), 3.1 million of 5.8 million log lines in a failed run's archive, and its `diagnosticd` takes 25 to 55 % of a core to write them.
  The simulator also respawns `mlhostd` and `managedappdistributiond` about every ten seconds, and `chronod` launched and killed widget extensions again and again, about every 35 s in the stretch read.
- The host is busy: 50 to 58 % user and 36 to 39 % system time on average in the light sampler's runs, the system time being page faults and I/O.

## What was tried, and what each showed

Each arm ran as its own draft pull request, since closed, on the same workflow with the part's session cut down to `AuditExceptionTests` and `CaptureSidewaysUITests` (6 tests, the session's first minutes) where it says so.
A run's own luck is large (a first test of 0 s and one of 170 s on the same code), so a result is only counted from several runs, and none of the first three arms below was run enough times to be more than a lead.

| Arm | What it did | First test, stall seconds | What else it changed |
| --- | --- | --- | --- |
| Control | nothing, with the light sampler | 0, 25 | |
| `apsd` off | disabled before the simulator's first boot, in the simulator's `disabled.plist` | not lower: one full ui-text run (heavy sampler) had 68 s in its first test and 407 s in all, against 59 s in all for its control | simulator CPU halved, the load average fell from 300 to 50, a trivial process spawned in a median of 1 to 1.5 s where it took 2 to 7 s, but the test steps did not get quicker |
| Slim simulator | 51 consumer services disabled before the first boot (push, widgets, Health, Fitness, News, Siri, iCloud and the like) | 49, 47, 40 | processes 270 to 160, swap 300 to 700 MB to under 15 MB, memory pressure "warn" for 12 to 27 % of the run instead of 42 to 76 %, and launches and terminates that waited 11 to 12 s |
| Build before boot | `build-for-testing`, then boot, then `test-without-building` | 66, 0 | |
| Slim and build before boot | both | 47, 40 | |

So the simulator's memory pressure and `apsd`'s loop are real, but removing either did not shorten the first test's stalls, and the slim list made them longer, which looks like steps waiting for the services it removed (`nanoregistryd` is one the simulator will not finish booting without; it is left on).
The lead that survives is the dark session's: the stalls are the first session's.
Run on the same simulator twice in a row, the six tests of the session's first minutes in four jobs, the second pass was quiet where the first was not in the one job whose first pass stalled for the simulator (74.2 s then 0 s; the other three first passes were 10.0, 0.0 and 3.3 s).

## Fix

`SimulatorWarmUp` (in `UITestSupport.swift` for the app's screen tests and in `HarnessTestSupport.swift` for the harness, the same code) runs in the first class's `setUp` of a session, which is outside every test's allowance as record 072 found.
It makes the steps every first test starts with, in the app: launch, open the Camera catalog, turn to landscape and back with a capture each, quit, launch and quit again (the harness's pass leaves out the catalog, which none of its tests opens).
The harness's launches before its tests, the warm-up's and every later class's, seed with `--scratch-history`, in the harness's temporary directory, so they add no history to the six that `run-retained.sh` collects for `inspect-retained.rb`.
It times each pass and stops when a pass is not at least a fifth quicker than the one before, with at most six passes and none begun after 6 minutes, and prints each pass's time to the test runner's output.
Every later class of the session makes the plain first launch of record 073 and nothing more.
Nothing is asserted, no step is retried, and no wait or allowance is longer.
The second change is one the first set of whole-part runs called for: the ten places that tapped Start a Film inline now use `openCameraCatalog`, which waits 30 s for the sheet (below).

On CI the first pass took 15 to 95 s, and the later ones 14 to 37 s, two to four passes in all and 31 to 140 s of passes before the first test (the tables below).
That first pass is the stall: it is two to three times a settled pass, and it is paid before the test starts.

## Repeated runs

### The first minutes, six runs (the ui-flows part cut to `AuditExceptionTests` and `CaptureSidewaysUITests`)

| Run | First test, stall seconds | First three tests | Disposable test | Warm-up passes (s) | Wait before the first test |
| --- | --- | --- | --- | --- | --- |
| 1 | 19.1 | 36 | 1m 19s | 73.8, 19.5, 19.3 | 115 s |
| 2 | 63.3, of which 60.1 s is one wait that is record 069's stall (3.2 s without it) | 67 (7) | 2m 7s | 43.5, 34.0, 20.8, 19.6 | 120 s |
| 3 | 0.0 | 0 | 46 s | 37.9, 26.6, 26.6 | 92 s |
| 4 | 0.0 | 3 | 49 s | 42.2, 14.3, 15.3 | 73 s |
| 5 | 7.3 | 13 | 1m 5s | 60.5, 21.1, 23.0 | 106 s |
| 6 | 6.9 | 7 | 1m 3s | 47.6, 20.8, 19.4 | 93 s |

The Disposable test, which took 77 to 180 s on CI before (56 s in the best run), took 46 to 79 s in five of the six.

### The whole parts, three runs each, twice

The three screen-test parts ran to the end three times each, in two sets, as experiment branches' pull-request runs (the `packages` part does not use the screen-test base classes and was not run).
The first set is the warm-up alone (run 39502687874); the second is the final code, the warm-up and the catalog change below (run 39515205332).

First set:

| Run | Result | First test | First three | All stalls | Longest test | Session | Warm-up passes (s) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| harness 1 | passed 52 | 5 s | 5 | 105 s | 94 s | 47 min | 87.6, 19.7, 25.7 |
| harness 2 | passed 52 | 0 s | 0 | 60 s | 102 s | 42 min | 57.5, 17.8, 16.8 |
| harness 3 | passed 52 | 7 s | 14 | 53 s | 97 s | 41 min | 23.2, 16.4, 18.7 |
| ui-flows 1, light | passed 28 | 10 s | 10 | 98 s | 119 s | 26 min | 40.5, 18.8, 19.5 |
| ui-flows 1, dark | passed 20 | 0 s | 8 | 67 s | 111 s | 16 min | 33.0, 17.8, 17.9 |
| ui-flows 2, light | passed 28 | 0 s | 4 | 59 s | 97 s | 24 min | 44.0, 25.8, 19.8, 16.9 |
| ui-flows 2, dark | passed 20 | 0 s | 7 | 33 s | 92 s | 14 min | 22.0, 15.7, 15.2 |
| ui-flows 3, light | passed 28 | 22 s | 22 | 154 s | 125 s | 29 min | 51.2, 28.7, 21.3, 19.3 |
| ui-flows 3, dark | passed 20 | 0 s | 8 | 76 s | 106 s | 16 min | 31.4, 18.0, 17.0 |
| ui-text 1 | passed 72 | 5 s | 13 | 39 s | 96 s | 45 min | 35.7, 19.5, 19.4 |
| ui-text 2 | 71 of 72 passed, one failed (below) | 0 s | 0 | 28 s | 85 s | 45 min | 70.1, 20.7, 18.3 |
| ui-text 3 | passed 72 | 17 s | 39 | 58 s | 102 s | 46 min | 71.6, 21.3, 28.9 |

The longest test of a run was 85 to 125 s, the 6×6 at the largest text size in ui-text and a held-drag or Darkroom test elsewhere; none came near the 3 minutes.
The light ui-flows session took 24 to 29 minutes with its build, where the run of 39377185262 took 28.

Second set, the final code:

| Run | Result | First test | First three | All stalls | Longest test | Session | Warm-up passes (s) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| harness 1 | passed 52 | 0 s | 3 | 177 s | 127 s | 45 min | 44.6, 14.6, 15.3 |
| harness 2 | passed 52 | 8 s | 17 | 71 s | 90 s | 41 min | 67.0, 14.5, 15.6 |
| harness 3 | 51 passed, one failed on a dropped touch and passed in the rerun | 0 s | 0 | 41 s | 109 s | 44 min | two sessions, see below |
| ui-flows 1, light | passed 28 | 3 s | 8 | 38 s | 87 s | 22 min | 84.5, 15.5, 14.8 |
| ui-flows 1, dark | passed 20 | 0 s | 0 | 10 s | 86 s | 12 min | 17.3, 13.9 |
| ui-flows 2, light | passed 28 | 27 s (one wait for the app to idle of 24 s) | 30 | 137 s | 123 s | 30 min | 32.0, 20.6, 20.2 |
| ui-flows 2, dark | passed 20 | 0 s | 16 | 86 s | 113 s | 17 min | 25.7, 20.3, 21.2 |
| ui-flows 3, light | 27 passed, one failed (below) | 3 s | 24 | 290 s | 153 s | 41 min | two sessions, see below |
| ui-text 1 | passed 72 | 4 s | 15 | 28 s | 87 s | 44 min | 45.4, 18.4, 25.2 |
| ui-text 2 | passed 72 | 4 s | 27 | 52 s | 84 s | 48 min | 94.6, 17.7, 20.2 |
| ui-text 3 | passed 72 | 22 s (11 s waiting for SpringBoard to idle) | 22 | 26 s | 86 s | 40 min | 20.5, 22.5 |

Eight of the nine jobs passed, harness 3 through the dropped-touch rerun that was already in place (`RetainedWorkflowTests.testSavedDarkroomEditAndExactResetPersistAcrossRelaunch`, seven discarded touches in its window).
The ui-flows 3 job failed, 31 minutes into its session, in `LowStorageUITests.testLoadFilmWarningAtTheLargestTextSizeHidesNoControl`: "Failed to get screenshot: Timed out while requesting screenshot."
The test's "Find the Target Application" step took 30 s and the screenshot request timed out after another 30 s, so the simulator did not answer for a minute.
It was the slowest run of the set (290 s of stalls, a 153 s longest test) and neither of the two rerun records fits it (no discarded touch, and its failure is not the allowance), so it failed the part.
That is a stall of the whole simulator in the middle of a session, which the warm-up does not touch.
Each session that had a failure was started again by XCTest for the tests after it, and the new start wrote its own warm-up, which is why those two sessions' output holds two sets (harness 3: 79.3, 23.7 and 36.9 s, then 15.1 and 15.7 s at the restart; ui-flows 3: 38.1, 21.2 and 30.8 s, then 24.3 and 21.1 s).

Taken over the 12 first tests of the ui-flows part with the warm-up (the six runs above, with run 2 counted at 3.2 s, without record 069's 60.1 s wait, and the six of both sets) and the 15 without it (the first column of the table at the top, `main` after record 073 and the experiment runs that changed nothing), the first test had a median of 5.1 s of stalls instead of 21.6 s and a mean of 8.5 s instead of 36.8 s, and 20 s or more in 2 of 12 against 8 of 15.
A permutation test on the 27 values, run 2 at 3.2 s, gives one-sided p = 0.02 for that fall, and Fisher's exact test on the counts of 20 s or more gives p = 0.06, so it is a fall that the runs support and not one they prove.
The two that remain at 20 s or more were 22 and 27 s, one wait for the app to idle each, in tests of about 100 s.

### The first set's failure: a tap that missed the sheet

`ContentSizeTests.testLandscapeSettingsTopTextAtAccessibilityExtraExtraLarge` failed in ui-text 2, 26 minutes into its session, with "Failed to tap "camera-disposable1990s" Button: No matches found".
The test taps Start a Film and, with nothing between, taps the Disposable row.
The first tap's event took 5.3 s to be synthesized, and the next tap, made as it returned, looked for the row for two seconds; the hierarchy it kept shows the Journal with no sheet over it.
The simulator's log holds no discarded touch in the test's window and the result bundle holds none of record 069's signature, so the rerun excused nothing and the part failed.
It is the race record `ci-flakes-057.md` found (a sheet that has not come up when the next tap is made) in the one place the catalog was still opened with a bare tap: ten tests, in `ContentSizeTests`, `JournalFlowTests` and `MovieCapacityUITests`, tapped Start a Film inline and went on at once, and `openCameraCatalog` waits for the sheet for 30 s.
All ten now use it; no assertion was changed or removed.
It is not caused by the warm-up, which ended 26 minutes before the test began.
The failed session's output holds a second session that started two minutes after the failure, with its own two warm-up passes (18.1 and 20.3 s), so XCTest started the test runner again for the tests after the failed one.

### Record 069's stall in the experiment runs

Three passing tests in experiment runs carried the 60 s wait and the note "App animations complete notification not received, will attempt to continue.": the Disposable test of one first pass and the Super 8 test of the second pass of the same job (the two-pass experiment), and the Disposable test of run 2 above.
None failed, and nothing was changed for them; the rerun `main` now has is for a test that fails with it.


## What is not shown, and what is left

- Why a freshly booted simulator answers slowly for its first minutes is not found.
  Memory pressure, `apsd`'s loop, the disk image's userspace server and the consumer services are each present and each was ruled out as the thing that, removed, ends the stalls; what ends them is the simulator doing the steps once.
  The warm-up pays for the stall and does not remove it.
- The warm-up's stopping rule is an engineering choice (a pass a fifth quicker than the last), not a measured threshold; the runs stopped at their second to fourth pass.
- A stall of the whole simulator in the middle of a session is not addressed: one job of the 18 whole-part jobs failed on one (a 60 s screenshot timeout) and the residual 22 and 27 s first-test waits look like the same thing at a smaller size.
  Nothing in this record shows what causes them or that the warm-up shortens them.

## Everything left as it was

The app's sources are unchanged, and the harness's only source change is `--scratch-history`.
No assertion was loosened or removed in the tests, no audit exception was added, the per-test allowance is still 3 minutes, the screen-test rerun and its two records are as record 074 left them, no test was skipped, and `Scripts/quiet-simulator.sh` and `Scripts/validate-local.sh` are as they were: every experiment that changed them (`apsd` off, the 51 services, the build before the boot, the two-pass run, the sampler) ran on a branch that was closed and is not in `main`.
The 60 s waits of record 069 stay with the captain.
After this merges, the manual iPhone test plan's pin in `Evidence/NativeApp/manual-validation.md` is re-pinned as after the earlier tests-only changes.
