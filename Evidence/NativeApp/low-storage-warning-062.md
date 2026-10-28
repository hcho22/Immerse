# Low-storage warning

Prepared 2026-10-13 on branch `fm/immerse-low-storage-warning`, from `d82c6fa`.
The captain approved the DEC-12 targets that day, which include "The app warns below 2 GB free", and said of the warning "Build it now".
The fuller text he agreed to is the DEC-12 row "Preflight warns below 2 GB free; saves fail honestly with no capacity debit when final private write cannot complete."
The branch was brought up to `main` at `80d5e91` on 2026-10-14 with one merge commit, which numbered this record 062.

Neither text says where the warning appears, what it says, or whether it stops anything.
Those three choices were put to the captain on 2026-10-13 with screenshots of the warning as built, and he answered "low storage - approve".
So the two places, the two sentences word for word, and warn only are decided as of 2026-10-13.

## What the app does

When the iPhone has less than 2 GB free, the app shows a warning before each step that needs space.

- The Load Film screen shows it just above Load Film.
- The Film screen shows it just above Open Camera while the Film is open.
- The Film screen shows it just above Develop Film, or Resume Development, from the time the Film is complete until it is developed.
- A developed Film shows none.

Before captures it reads:

> This iPhone has less than 2 GB free, so a capture may not save. A capture that does not save uses no exposures or time, and saved captures are unchanged. Free space in iPhone Settings.

Before Development it reads:

> This iPhone has less than 2 GB free, so Development may not finish. Saved captures are unchanged, and Development can be resumed. Free space in iPhone Settings.

The warning is text on the screen, with no button and nothing to dismiss.
It stops nothing: Load Film, Open Camera and Develop Film work as before.
It goes when the iPhone has 2 GB free again.

| Screen | iPhone 17 Pro | iPhone SE (3rd generation) |
| --- | --- | --- |
| Load Film | [light](low-storage-warning-062/load-film-iphone17pro-light.png), [dark](low-storage-warning-062/load-film-iphone17pro-dark.png) | [light](low-storage-warning-062/load-film-iphonese-light.png), [dark](low-storage-warning-062/load-film-iphonese-dark.png) |
| Film, open | [light](low-storage-warning-062/film-open-iphone17pro-light.png), [dark](low-storage-warning-062/film-open-iphone17pro-dark.png) | [light](low-storage-warning-062/film-open-iphonese-light.png), [dark](low-storage-warning-062/film-open-iphonese-dark.png) |
| Film, ready to develop (synthetic harness Film) | [light](low-storage-warning-062/film-ready-to-develop-iphone17pro-light.png) | not taken |
| Load Film, largest text | [light](low-storage-warning-062/load-film-largest-text-iphone17pro-light.png), [light, end of the Form](low-storage-warning-062/load-film-largest-text-end-iphone17pro-light.png) | [light, end of the Form](low-storage-warning-062/load-film-largest-text-end-iphonese-light.png) |
| Film, open, largest text | [light](low-storage-warning-062/film-open-largest-text-iphone17pro-light.png), [light, scrolled to Open Camera](low-storage-warning-062/film-open-largest-text-end-iphone17pro-light.png) | not taken |

## Choices and why

### The reading

`VolumeFreeSpaceReader` (`Packages/NativeAdapters/Sources/NativeAdapters/FreeSpace.swift`) reads `volumeAvailableCapacityForImportantUsage` on the volume that holds the Films.
Apple gives three readings of a volume's free space.
The one for important usage is the one it recommends for space an app needs for something the person asked for.
It counts what iOS can clear to make room, such as purgeable caches.
The plain `volumeAvailableCapacity` leaves that out and reads lower than a save can use, so it would warn on an iPhone that still has room.
The opportunistic reading is for data the person did not ask for, which a capture is not.
Each reading clears the URL's cached resource values first, so it asks the volume again.
A URL returns a value it has read until the run loop of the thread that read it turns, and the app reads on threads that run none, so without that the warning kept its first reading until the app restarted.

### 2 GB

2 GB is 2,000,000,000 bytes, not 2 × 1024³ (2,147,483,648).
iPhone Settings shows storage in decimal gigabytes.
A person checks the warning against iPhone Storage, so the warning stops when Settings shows 2 GB free.
`FreeSpaceTests.testLowIsLessThanTwoDecimalGigabytes` holds the number and says it is not the binary one.
Less than the line is low.
Exactly 2,000,000,000 bytes is not, because he read "below 2 GB".

### A reading that fails

When the system gives no reading, the app shows no warning.
The warning states a fact about the iPhone, and the app does not state one it could not read.
A warning that had been showing goes when the next reading fails, for the same reason.
Nothing depends on the warning, so a save that cannot complete still fails honestly.

### When the app reads

`LowStorageCheck` (`App/Immerse/Sources/LowStorage.swift`) reads off the main actor, since the system can take a moment to count what it could clear.
It reads when the Load Film screen or the Film screen appears.
It reads again whenever the Journal refreshes: when the app comes to the front, after each saved capture and after each operation.
So a person who frees space in iPhone Settings and comes back sees the warning go without restarting the app.

### Nothing is stopped

He read "The app warns below 2 GB free", which is a warning, and he approved warn only on 2026-10-13.
2 GB is a caution line well above the point where a save fails, so stopping there would refuse captures that would have saved.

### Where it is not

The camera screen has no warning.
A line above the viewfinder pushes the viewfinder down, and at the largest text sizes off the first screen.
The cost is that space running out in the middle of a long shoot is not warned about until the person is back on the Film screen.
The Development confirmation sheet has none, since the Film screen's warning is one tap before it.
Saving to Photos has none, since exports are outside this change.
The captain was told the camera screen and a pop-up were left out and why, and that saving to Photos has no warning and one there would be a follow-up.
He asked for none of them, so none is built.

## What did not change

No capture, save, Development or export code changed.
A save that cannot complete still fails with no capacity used.
The tests that hold that passed on this branch on 2026-10-13: `swift test` for FilmDomain (24 tests), FilmPersistence (37), NativeAdapters (42, three of them new) and FilmRuntime (55).
They include `testDurablePhotoDebitHappensOnlyForSavedCaptures`, `testMovieDebitHappensOnlyForSavedDurationAndPreventsOverrun`, `testFailureBeforeDurableMoveDoesNotDebitOrLeaveSource`, `testFailureAfterDurableMoveBeforeDebitLeavesNoDebitAndRecoveryRemovesOrphan`, `testFailedPersistenceRetainsCaptureAndPreventsRecaptureOrLensSwitchUntilRetryCommits` and `testFailedUnsavedCaptureAndZeroSaveDeletionAllowReplacement`.
No product string that existed before changed.

## Scenarios

Every scenario sets the free-space reading from a test.
No disk was filled.

| Scenario | Expected | Observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Line is 2,000,000,000 bytes | 1,999,999,999 low; 2,000,000,000 and 2,000,000,001 not; 2,100,000,000 not | As expected | Pass | `FreeSpaceTests.testLowIsLessThanTwoDecimalGigabytes` |
| The real reading | A positive number of bytes on a Mac and in the simulator; an error where nothing can be read | As expected on macOS and on the iOS 26.2 simulator | Pass | `FreeSpaceTests`, `LowStorageTests.testTheAppsOwnReadingIsAvailable` |
| Each step, each reading | Warning with its exact words just under; none at exactly 2 GB or just over | As expected for captures and for Development | Pass | `LowStorageTests.testWarningShowsBeforeEachStepOnlyBelowTwoGigabytes` |
| Failed reading | No warning, and an earlier warning goes | As expected | Pass | `LowStorageTests.testAReadingThatFailsShowsNoWarningAndClearsAnEarlierOne` |
| Space freed while the app is away | The next Journal refresh clears the warning | As expected | Pass | `LowStorageTests.testJournalReadsFreeSpaceAgainEachTimeItRefreshes` |
| The real reading, read again | After its directory is removed, the same reader's next reading fails instead of returning its first one | As expected on macOS | Pass | `FreeSpaceTests.testVolumeReaderReadsAgainEachTimeRatherThanReturningItsFirstReading` |
| Which step a Film's screen warns before | Captures while open, Development once complete, nothing once developed | As expected for a Disposable Film through its life and an open Instant Film | Pass | `LowStorageTests.testFilmScreenWarnsBeforeCapturesThenBeforeDevelopmentAndNeverOnceDeveloped` |
| Load Film screen, just under | Warning above Load Film; Load Film enabled | As expected, light and dark | Pass | `LowStorageUITests.testLoadFilmWarnsJustUnderTwoGigabytes` |
| Load Film screen, exactly at, just over, failed | No warning | As expected, light and dark | Pass | `LowStorageUITests.testLoadFilmShowsNoWarning...` (three tests) |
| Loading with the warning showing | The Film loads; its screen warns above Open Camera, which is enabled | As expected, light and dark | Pass | `LowStorageUITests.testLoadingStillWorksAndTheFilmScreenWarnsBeforeOpenCamera` |
| Film screen with saved captures, just under | Warning above Open Camera; after completing early, the Development words above Develop Film; Development runs; the developed Film has no warning | As expected | Pass | `LowStorageWorkflowTests.testFilmScreenWarnsBeforeOpenCameraThenBeforeDevelopFilmJustUnderTwoGigabytes` (harness) |
| Film screen, exactly at, just over, failed | No warning before Open Camera or Develop Film | As expected | Pass | `LowStorageWorkflowTests.testFilmScreenShowsNoWarning...` (three tests, harness) |
| Largest text size | The warning and each command are reached by scrolling; nothing is clipped; the warning fits the width | As expected on the Load Film screen and the Film screen, light and dark; on the harness Film screen in both states, light | Pass | `LowStorageUITests.test...AtTheLargestTextSizeHidesNoControl` (two tests), `LowStorageWorkflowTests.testFilmScreenWarningsAtTheLargestTextSizeHideNoControl` |
| Text follows the text size | The warning's text grows at each step from L to AX XXXL, never shrinks below L, and is never clipped | As expected at all twelve sizes, light | Pass | `ContentSizeTests.testLowStorageWarningTextAt...` (twelve tests) |
| Release build | No set reading | See [Runs](#runs) | See [Runs](#runs) | `sh Scripts/verify-release-excludes-testing-unlock.sh` |
| A nearly full iPhone | The list under [What only a nearly full iPhone can show](#what-only-a-nearly-full-iphone-can-show) | Not run: no device work is authorized for this task | Untested | None |

## Accessibility

The warning is one accessibility element whose label is its words, so VoiceOver reads it whole.
Its symbol is decorative and hidden from VoiceOver.
The symbol grows with the text only as far as 23 points, the size of body text at Extra Extra Extra Large.
Left to grow, it took a third of the row at the largest size and left the words a column two or three words wide.

The warning's text measured 21.00:1 on the Load Film screen and 18.82:1 on the Film screen in light, and 13.94:1 and 17.01:1 in dark.

The audits run every type except Dynamic Type, as the project's audits do, and `ContentSizeTests` measures the text at all twelve sizes in its place.
They ran on the Load Film screen and the Film screen, at the default and the largest text size, in light and dark.

### Two accepted findings, measured

The default-size Load Film audit is taken at the end of the Form, where the warning and Load Film are on screen together.
The Form stops there in every run with two of the Camera's rows under the navigation bar's scroll-edge blur, and the contrast check reports them there.
Both were reported at the same frames in three light runs and two dark runs.
At rest, at the top of the Form, each measured 21.00:1 in light and 13.94:1 in dark.
`App/Immerse/UITests/AuditExceptions.swift` accepts exactly these two at this one audit point: "Fixed focus, fixed exposure, optional flash and a live low-light cue" and "Borderless 3:2 picture, warm, saturated color, heavy grain, harsh flash and soft edges".
Neither is the warning.

The 2026-10-26 phone feedback changed both rows' words, and on 2026-10-27 the two exceptions were measured again for the new words on an iPhone 17 Pro simulator with iOS 26.5, one run in light and one in dark.
The Form stopped at the same pose in both, with the end of the controls line and the start of the look line under the navigation bar's blur.
Light reported the look line only; dark reported both.
At rest, at the top of the Form, each measured 21.00:1 in light and 13.94:1 in dark, as before.
The exceptions now accept exactly "Focus switch: Auto / Fixed; tap to focus in Auto; fixed exposure, optional flash and low-light cue" and "1990s disposable camera: borderless 3:2 picture, warm, saturated color, heavy grain, harsh flash and soft edges".

### The largest-text audit pose, 2026-10-28

On 2026-10-28 the largest-text Load Film audit at the warning failed on CI (run 40707150573) and in 4 of 4 local runs on an iPhone 17 Pro simulator with iOS 26.5, in light.
Each time the auditor reported "Text of this element may be clipped at larger Dynamic Type sizes" with no element.
The test audited where the warning first scrolls into view, and the phone feedback's longer Disposable rows had moved that pose: the Film title sat half under the navigation bar.
The screenshot of that pose shows the entitlement row and Subscription whole and the warning's first line uncut; only the Film title is cut, by the bar.
A diagnostic run stepped through the Form in drags of about 65 points and audited clipped text alone at each pose.
It reported the element-less finding only where the Camera's rows or the Film title were under the bar, including poses with no warning on screen, and never where only the warning was under it.
So the test now goes on in 100-point drags until the warning's top reaches the bar, where the warning fills the screen whatever rows come above it, and audits there.
The finding came from the scroll pose, not from clipped text in the warning or a control, and no exception was added for it.
The new pose was run only on the iPhone 17 Pro, the gate's simulator; the iPhone SE results below are from before it.

### Existing Film screen findings, fixed

The Film screen had no full audit before this change.
Auditing the warning there reported three items that were already on the screen.
Review on 2026-10-14 found a fourth, on a Movie Film's screen, which no audit reaches.

| Item | Before | After |
| --- | --- | --- |
| Remaining-capacity line and date line, light | System secondary label, 3.44:1 on white | `Color.cardSecondaryText`, 4.58:1 |
| "Sealed" and "Discarded" captions on a frame's gray ground, light | System secondary label, 3.29:1 | `Color.frameSecondaryText`, 4.82:1 |
| Progress bar under the capacity line | Its own element, 4 points tall, reported as a control too small to tap | Hidden from accessibility; VoiceOver reads the capacity line above it, which says the same in words |
| "Discarded" in a Movie Film's clip list, on the screen's white ground, light | System secondary label, 3.44:1 on white | `Color.cardSecondaryText`, the capacity line's color on the same ground |

Dark mode keeps the system colors, which passed.
No text changed.
The captain was told on 2026-10-13 that the gray text on the Film screen becomes slightly darker.
The contrast figures are measured from screenshots of the runs: the text color against the ground's most common color.
The clip list's "Discarded" was not measured from a screenshot: it takes the color and ground of the capacity line, measured at 4.58:1.

The populated Film screen, with frames on it, still has no full audit.
The harness's tests are functional, as its README says.

### On an iPhone SE

The gate's simulator is an iPhone 17 Pro.
The warning's tests also ran once each in light and dark on an iPhone SE (3rd generation) simulator, the project's small screen, and the results there are kept as they came.

- The Film screen audits passed at the default and the largest text size, in light and dark.
- `ContentSizeTests` measured the warning's text on the Load Film screen at all twelve sizes in light: it grew at every step and was never clipped (12 of 12).
  At the largest size its longest word, "unchanged.", fits the column and Load Film is reached below it.
- The default-size Load Film audit reported contrast on "Film title", the row that the end of the Form puts under the navigation bar on that screen.
  The two accepted findings are the rows under the bar on an iPhone 17 Pro, so they do not cover it, and nothing was added for it.
- At the largest text size the Load Film audit at the warning reported "Text of this element may be clipped at larger Dynamic Type sizes" with no element, in 3 of 3 runs, along with contrast on the entitlement row under the bar.
  A control run of the same screen and size with no warning reported only the contrast finding.
  So the element-less finding comes with the warning's row, which at that size is 1,271 points tall on a screen 667 points tall.
  The project has met this before: `prd-2-slice-3-film-stock.md` records the same element-less finding for a 589-point row in the lazy Load Film Form.
  The direct measurement above shows no clipped text.
  On the iPhone 17 Pro the same audit passed in every run, see [Runs](#runs).
  A finding without an element cannot be accepted, and none was.

## The privacy manifest

Apple requires an app that reads free disk space to declare the reason in `PrivacyInfo.xcprivacy`.
The app had none.
`App/Immerse/Sources/PrivacyInfo.xcprivacy` declares the disk-space category with reason E174.1, which covers checking whether there is enough space to write files and behaving differently in a way the person can see.
It also declares no tracking and no collected data, which is true of v1 (no server, Accounts or analytics).
The Release build uses no other API that needs a declared reason: `UserDefaults` appears only under `#if DEBUG`.
The captain was told of the file on 2026-10-13.
It gets its full review with the launch review, DEC-13.

## The Debug-only reading

Screen tests and the populated Journal harness set the reading with the launch argument `-ImmerseDebugFreeSpace <bytes>`.
Any other value, such as `unreadable`, is a reading that fails.
Without the argument the app reads the iPhone.
`DebugFreeSpace` is under `#if DEBUG`, and `Scripts/verify-release-excludes-testing-unlock.sh` now requires its type name and its key in the Debug bundle and their absence from the Release bundle.

## Runs

All runs were on 2026-10-13 with Xcode 26.5 (17F42), on simulators made for this task and deleted afterwards: an iPhone 17 Pro on iOS 26.5 for the screen tests and the harness, an iPhone 17 Pro on iOS 26.2 for the hosted tests, and an iPhone SE (3rd generation) on iOS 26.5.
The Mac was shared with other work, at load averages between about 5 and 80.

### The project's check, part by part

Each part ran as `IMMERSE_VALIDATE_PART=<part> sh Scripts/validate-local.sh` with its simulators, on commit `848c223`.

| Part | Outcome |
| --- | --- |
| packages | Passed. Script tests 52 of 52; the parts guard and the requirement map; every package and probe on the Mac (NativeAdapters 42 with the three new tests); the document package; unsigned simulator and device builds; the Release check ("Debug bundle: testing unlock and set free-space reading present", "Release bundle: testing unlock and set free-space reading absent"); RenderCore in the simulator 95 passed, 1 skipped; hosted `ImmerseTests` 51 of 51 on iOS 26.2, the seven `LowStorageTests` among them |
| harness | Passed, 35 of 35, the five `LowStorageWorkflowTests` among them |
| ui-flows | Passed, 23 of 23 in light and 20 of 20 in dark, the seven `LowStorageUITests` in each |
| ui-text | Passed, 72 of 72, the twelve low-storage text-size tests among them |

No screen test needed a rerun, so `DerivedData/validation-notes.txt` was empty.

After those parts, each screenshot in `LowStorageUITests` was moved to before its audit, since the audit's text-resizing checks leave a scrolled list somewhere else and two largest-size screenshots had come out blank.
The suite then ran again on the iPhone 17 Pro: 7 of 7 in light and 7 of 7 in dark.
The screenshots in this record are from that run, except the iPhone SE and harness ones.

`LowStorageUITests.testLoadFilmWarningAtTheLargestTextSizeHidesNoControl`, the audit that reported an element-less finding on the iPhone SE, passed on the iPhone 17 Pro in every run of the day: 6 of 6 in light and 4 of 4 in dark.

### Failures on the way, kept

- The first screen-test run audited the Load Film screen with the warning scrolled just into view, which left "Sealed until Development" and the controls line under the navigation bar, and failed on their contrast.
  The audit moved to the end of the Form, the one pose that is the same in every run, which led to the two measured exceptions above.
- The same run's Film screen audit failed on the capacity line's contrast and the progress bar's size, and the harness's Film screen audit on the "Sealed" captions.
  These are the first three fixes above.
  The harness's audits were then removed, since that harness's tests are functional by its own README, and its tests kept their checks of the words, the order and the commands.
- The iPhone SE runs failed as described under [On an iPhone SE](#on-an-iphone-se): 2 of 4 tests in light and in dark, and 2 of 14 in the control run, one of them the control itself.
- Review on 2026-10-14 found that the real reader returned its first reading on every later read, so on an iPhone the warning would neither go when space was freed nor come when it ran out.
  A probe outside the repository, on macOS 26, read one URL from a detached task before and after writing 300 MB beside it: without clearing the URL's cache the reading did not drop, and with it cleared it dropped by 301,146,112 bytes.
  No test had seen it, because every screen test sets the reading.
  The reader now clears the cache before each reading, and `FreeSpaceTests.testVolumeReaderReadsAgainEachTimeRatherThanReturningItsFirstReading` holds it without depending on how much the disk changes: it fails without the fix and passes with it.

### After the merge with main

On 2026-10-14 the branch took `main` at `80d5e91`, which brought the Darkroom and export change (#28) and the Instant study and toning change (#29), in merge commit `c89b815`.
The merge needed no hand resolution, and against `main` the branch still changes only this warning's files, the three Film screen fixes and the documents.
`main` had changed the Film screen (the Instant's question about each new print's original), `JournalModel`, `CaptureView`, the harness and its tests, and the shared documents, so every part that holds a test of this change ran again on the merge commit, on new simulators made for the run and deleted after it: an iPhone 17 Pro on iOS 26.5 and one on iOS 26.2.

| Part | Outcome on `c89b815` |
| --- | --- |
| packages | Passed. Script tests 52 of 52; the parts guard; the requirement map (137 intake IDs, 74 acceptance clauses, 9 invariants); every package and probe on the Mac, NativeAdapters 42 with `FreeSpaceTests`; the document package, regenerated in the merge; both unsigned builds; the Release check (set free-space reading present in Debug, absent in Release); RenderCore in the simulator 111 passed, 1 skipped; hosted `ImmerseTests` 54 of 54 on iOS 26.2, the seven `LowStorageTests` among them |
| harness | Passed, 42 of 42, the five `LowStorageWorkflowTests` among them |
| ui-flows | Passed, 23 of 23 in light and 20 of 20 in dark: the seven `LowStorageUITests` with their audits at the default and largest text sizes, and the two accepted findings, in both |
| ui-text | Passed, 72 of 72, the twelve low-storage text-size tests among them |

No screen test needed a rerun.

Carried over without running again, because the merge changed nothing they depend on:

- The contrast measurements and the two accepted findings' measurements at rest: the colors and rows they measure are unchanged by the merge, and the ui-flows run's audits passed in light and dark.
- The iPhone SE runs and the control run: the warning, the Load Film screen and the Film screen's header and actions are unchanged by the merge.
- The screenshots: they are of screens the merge did not change.

## What only a nearly full iPhone can show

No simulator run fills a disk, and the simulator reports its Mac's volume.
These are for the manual iPhone test plan.

1. With iPhone Storage in Settings showing less than 2 GB free, the Load Film screen and an open Film's screen show the warning.
2. With iPhone Storage showing 2 GB or more, neither does.
   Note the number Settings shows when the warning first appears: the app's reading counts space iOS can clear, and Settings may count it differently, so the two can disagree near the line.
3. After freeing space in Settings and returning to the app without restarting it, the warning goes.
4. With a little under 2 GB free, a photo, an Instant print, a Movie clip and a full Film's Development still save.
5. As the iPhone fills further, a save that cannot complete fails with its existing message and uses no exposure or time, and the warning was showing before it.
6. The reading does not fail or return nothing free on a healthy iPhone.
   A failed reading shows no warning, so this can only be seen by the warning's absence on a nearly full iPhone.
7. The reading takes no noticeable time when a screen opens.
8. VoiceOver reads the warning as one element in each place, and at the largest text size every command is reachable.
9. On a small iPhone at the largest text size, the whole warning reads without a clipped word, since the simulator's auditor reported an unattributed finding there.
