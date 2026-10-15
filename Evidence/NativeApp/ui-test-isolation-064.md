# Screen Tests Leave No Film Behind 064

Captain's standing words: "Apply the same high standards to engineering excellence: lint, test failures, and test flakiness. If you see one, even if it's not caused by what you are working on right now, still fix it."

On 2026-10-14 the crop-fit change (`crop-fit-short-screens-063.md`) saw two failures in the dark rerun of the screen-flows part on this Intel Mac, both outside its own change.
`LowStorageUITests.testFilmScreenWarningAtTheLargestTextSizeHidesNoControl` ran past its 3-minute allowance while the Mac was loaded far beyond its cores.
`MovieCapacityUITests.testMovieTimeReadsAsMinutesAndSecondsAtLargestText`, which runs after it, then failed its contrast audit on the Journal, on the title of a Disposable Film it had not loaded.
That record also left one failure of main's own check unexplained: a tap on the Darkroom's Crop switch in the populated Journal harness that did nothing.

This record is simulator evidence on this Intel Mac (iPhone 17 Pro, iOS 26.5).

## Reproduction on Main

Main at `38792bb`, a new simulator, the two suites in the order the part runs them.

| Run | Result |
| --- | --- |
| `LowStorageUITests` then `MovieCapacityUITests`, light | All 9 passed; the largest-text Film screen test took 2 min 2 s |
| The same, dark | All 9 passed; that test took 2 min 3 s |
| The largest-text Film screen test alone, dark, its allowance cut to 1 minute | Stopped at its allowance after it had loaded its Disposable Film |
| Then `testMovieTimeReadsAsMinutesAndSecondsAtLargestText` alone, dark | Failed: "Contrast failed", on the leftover Film's title |

So the leftover Film is not left by a Low Storage test that finishes, pass or fail.
It is left only by one stopped at its time allowance, and then every later test that reads the Journal meets it, in every run on that simulator until the app is removed.
That is why the crop-fit run saw it fail again when the two ran together, and pass with the app freshly installed.
GitHub's Apple silicon Macs finish the Low Storage test well inside its allowance, so they never stop it and never leave the Film.

## Cause

Each test that loads a Film deletes it in a `defer` (`deleteFilm(titled:_:)` in `App/Immerse/UITests/UITestSupport.swift`).
A test that runs past its execution time allowance is not unwound: XCTest ends the test runner mid-test and starts a new one for the next test, so no `defer` and no teardown block runs.
The Film the stopped test had loaded stays in the app's container on the simulator.

The Movie capacity test's audit then sees two cards in "On the roll" at the largest text size.
Its own 16mm card rests whole on screen, and the leftover Disposable card below it passes under the screen's bottom edge, where its title fades into the scroll edge effect behind Start a Film.
The contrast audit reads that faded title as low contrast.

## The Fix

`launchWithEmptyJournal(_:)` in `UITestSupport.swift` launches the app, waits for Start a Film to be enabled (it stays disabled until launch recovery ends), and deletes every Film in the Journal through the Film screen's Delete Film, as `deleteFilm` does.
It counts the Journal's Films once a pass and stops when there are none, then waits for the empty Journal's "Your Journal begins here".
Every test that loads a Film or reads the Journal starts with it: the Low Storage tests that load a Disposable, both Movie capacity tests, both Film Stock tests that load a Film, `JournalFlowTests.testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore`, which audits the empty Journal, `JournalFlowTests.testDeniedCameraAtLoadFilmLoadsNothingAndPointsToSettings`, which returns to it, and the twelve `ContentSizeTests` Journal and catalog tests, which measure its text, each at its own text size.
Each Film it finds is kept as a screenshot named "Film-left-by-an-earlier-test" before it is deleted, so the earlier test's failure stays visible in the result bundle.
Delete Film removes the Film, which leaves the Film screen showing "Film removed" without its actions, and then closes the screen, which stays in the tree until its pop ends.
The Journal's rows are in the tree only while the Journal shows, so a row counted or missed before then says nothing, and a Journal audited or measured mid-pop is still sliding in (`push-audit-055.md` saw the same for a push).
So each deletion, at the start of a test or at its end, waits for the Film screen's actions to leave (the Film was removed), then for "Film removed" to leave (the screen has closed) and for Start a Film to show, before the Journal's Films are counted, a row is looked for, or the test goes on.
It does not count the Journal's rows to prove a deletion: the Journal's list is lazy, so with more Films than fit on the screen, deleting one brings another row into the tree and the count can stay the same.
The tests still delete their own Film at the end, so a test that finishes leaves the Journal as it found it.
No test was reordered.

The Journal's Film rows carry the accessibility identifier `journal-film`, so a test can find a Film whatever its title.
It is not read aloud and changes nothing a person sees.

The Movie capacity test now also states the pose its contrast audit needs: the Journal holds only its Film, and that card ends above Start a Film.
It returns from its Film to the Journal through `goBack`, which waits for the Film screen's bar to leave the tree, so the audit never starts while the Journal is still sliding in.
Before, it tapped Back and went on, and only the extra queries `scrollUp` made after reaching the row (below) gave the pop time to end.

With the leftover Disposable from the stopped run still on the simulator, the next run of the branch deleted it at the start of the first test and all 9 tests passed in dark, then all 9 in light.

## Is the Faded Title a Defect a Person Can Meet

No.
A person with enough Films meets the same pose: at the largest text size the next card's title rests partly under the screen's bottom edge.
There it fades into the scroll edge effect of the bar that holds Start a Film, which `JournalView` keeps on purpose, the same fade the iOS 26 bottom toolbar draws under every scrolling screen (`ci-flakes-057.md`).
The fade marks that the list goes on, and the title is read by scrolling it up, where it has the card's full contrast; the audited 16mm card in the same screenshot, clear of the edge, passed.
This is the case the audit rules already name: a heading left half under the bottom edge is flagged for contrast in dark, and the audited pose scrolls the whole element into the window (`title-field-tap-054.md`).
So the app is unchanged, and the audit's rule is kept: an audited Journal holds only the test's Film, ending above Start a Film, rather than an exception for a faded card.

## The Low Storage Largest-Text Test's Time

On main the largest-text Film screen test took about 2 minutes of its 3 at normal load, with little room for a loaded Mac.
Two things in the shared scroll helper wasted about a third of it, and one wait in the test itself wasted more the same way.

- `scrollUp(_:until:)` asked `isHittable` of a row the lazy Form had not made yet.
  For a missing element XCTest looks twice more before it answers, about 2.3 seconds a drag.
  It now asks `exists` first.
- `scrollUp(_:by:until:)` looped `for _ in 0..<16 where !done()`.
  A `where` clause skips the drag but does not end the loop, so once the row was reached it asked again on every remaining pass, about 15 more queries and 3 to 5 seconds a scroll.
  It now returns when `done` holds.
  `deleteFilm` had the same loop and now stops too.
- The wait for the loaded Film's screen, `for _ in 0..<20 where !actions.exists`, tapping the bar so the Camera request is answered, went on asking the same way after the screen showed, about 18 more queries.
  It now stops once the screen shows, as do the same waits in the Movie capacity and Film Stock tests.
  Those extra queries had also given the catalog sheet time to leave: the Film screen shows while the sheet that loaded it is still going, and the Load screen there has its own low-storage warning.
  So each of the three then waits for the tapped Load Film button to leave the tree, which it does only with the sheet, before it reads, audits or taps the Film screen (`push-audit-055.md` does the same for a push).

What is left is the test's own work at the largest text size: about 11 held drags to reach Load Film, two audits, and deleting the Film from a fresh launch.
In the four full runs below it took 1 min 20 s to 1 min 27 s in light and 1 min 26 s to 1 min 53 s in dark, while other work shared this Mac.
The 3-minute allowance stays: the test is not slow by design, and a larger allowance would only hide a hang.
A Mac loaded several times past its cores, as on 2026-10-14, can still stop it; the Film it leaves is now deleted by the next test.

The same helpers serve every suite, so the other largest-text and Load screen tests got faster too (for example the largest-text Load Film warning test went from 1 min 34 s to 53 s in light).

## The Crop Switch Tap

Main's check of the low-storage merge failed `RetainedWorkflowTests.testDarkroomAccessibleControlsReachNonGestureEditingPaths` in the harness part: after the tap on the Crop switch the Crop size slider never appeared.
Its result bundle shows the tap synthesized at (356.5, 758), the centre of the switch control itself (325 to 388 by 744 to 772 pt), with the switch's value 0 in every snapshot after it.
The tap was aimed at the control and arrived at the right place; the app did not take it.
The check's dropped-touch scan found no dropped touch for it, so `Scripts/screen-tests.sh` did not rerun it.

Here the test ran 10 times in a row on main at `38792bb`, which has the crop-fit change, and 10 times on `5c427bc`, the build whose check failed, on the iPhone 17 Pro simulator in light.
All 20 passed, and each tap turned the switch on.
Why that one tap did nothing is still not known, so nothing was changed for it: a second tap or a retry would only hide it.

## Other Failures of Main's Check

Main's check failed on four other pushes in the two days before this record, and they are left for their own changes:

- the whole check once, on `5c3a217`, before it was split into parts, cancelled at its 120-minute limit with no test failed (`dropped-touch-059.md`);
- the screen-text part twice, `ContentSizeTests.testFilmStockLoadScreenTextAtAccessibilityExtraExtraExtraLarge` once and `ContentSizeTests.testLandscapeSettingsTopTextAtAccessibilityExtraExtraExtraLarge` once;
- the packages part once.

In the screen-text part this change touches only `ContentSizeTests`' Journal and catalog tests, which now start on an empty Journal; the two tests that failed there launch as they did before.

## Runs of This Change

| Run | Result |
| --- | --- |
| Screen-flows part (`IMMERSE_VALIDATE_PART=ui-flows sh Scripts/validate-local.sh`), twice, before `deleteFilm`'s loop was made to stop | Passed both times: light 23 tests and the expected audit failure, dark rerun 20 and the expected audit failure, no rerun |
| The same part twice in a row on the change as it stood before review | Passed both times the same way, no rerun |
| The Crop switch test, 10 times each on `38792bb` and `5c427bc` (above) | All 20 passed |
| After the first review round, whose deletions waited for the Film screen's actions to leave and Start a Film to show but not for the pop to end, on a new simulator in light with this Mac loaded about eight times past its cores: `testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal` with a 1-minute allowance | Passed in 59 s, deleting its Film at the end |
| Then `testMovieTimeReadsAsMinutesAndSecondsAtLargestText` with a 1-minute allowance | Stopped at its allowance after loading its 16mm Film |
| Then `ContentSizeTests.testJournalAndCatalogTextAtLarge` and `JournalFlowTests.testDeniedCameraAtLoadFilmLoadsNothingAndPointsToSettings` | Both passed; the first kept the leftover 16mm Film as "Film-left-by-an-earlier-test" and deleted it before measuring the empty Journal |
| After the second review round, with the waits above, on another new simulator in light with this Mac less loaded: `testMovieTimeReadsAsMinutesAndSecondsAtLargestText` with a 1-minute allowance, then `JournalFlowTests.testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` | The first stopped at its allowance after loading its 16mm Film; the second deleted that Film, its three waits each passing at their first check about a second in, then audited the empty Journal and passed |
| Then the same stopped test, then `ContentSizeTests.testJournalAndCatalogTextAtAccessibilityExtraExtraExtraLarge` and `testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal` | Both passed; the first kept and deleted the leftover Film before measuring, and the second deleted its own Film at the end |
| After the third review round, which returns the Movie capacity test to the Journal through `goBack`, on another new simulator in light: both `MovieCapacityUITests` tests | Both passed (1 min 49 s at the largest text size, 1 min 52 s at the default); in each the Film's bar left the tree and "Film Journal" showed at the first check, about a second after Back, before the Journal's audit |
| After the fourth review round, whose waits for a loaded Film's screen stop once it shows, on another new simulator in light: `LowStorageUITests.testFilmScreenWarningAtTheLargestTextSizeHidesNoControl`, `FilmStockUITests.testSixteenMillimeterLoadsOnTheBlackAndWhiteFilmStock` and `MovieCapacityUITests.testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal` | All passed (1 min 25 s, 57 s and 56 s); in the Low Storage test the wait stopped on its second pass, two checks of the Film actions in all |
| After the fifth review round, which then waits for the Load Film button to leave with the sheet, on another new simulator in light: both Low Storage Film screen tests, `FilmStockUITests.testSixteenMillimeterLoadsOnTheBlackAndWhiteFilmStock` and `MovieCapacityUITests.testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal` | All 4 passed (50 s and 1 min 30 s, 1 min 4 s, 1 min); in the largest-text Low Storage test the Load Film button had left at the wait's first check, about a second in, before the Film screen's warning was read |
