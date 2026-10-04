# Debug Testing Unlock

Prepared 2026-10-02 for the captain's request: "for immerse, can you unlock the subscription for now so that i can test all cameras and features manually?"
Branch `fm/immerse-testing-unlock`; the base is `b4d9527` (PR #9).
The change was prepared on `14328bf` and rebased onto `b4d9527` on 2026-10-03.
Every outcome outside [Rebased Head](#rebased-head) was observed on 2026-10-02, before that rebase.
Manual steps are in [manual-validation.md](manual-validation.md#debug-testing-unlock).

## What Changed

- `App/Immerse/Sources/TestingUnlock.swift`, entirely under `#if DEBUG`, holds the switch, the indicator and the Settings section.
- `JournalModel.load`, the only new-Film gating site, passes an active subscription to `TrialCoordinator.load` while the switch is on. `TrialCoordinator.load` then creates a subscription Film without calling `start`, so the Trial record is never read for eligibility or written.
- `SubscriptionController.access` and EntitlementCore's StoreKit verification are unchanged, so the Subscription screen and purchase/restore messages still report the real StoreKit state.
- The app's own Journal reads the persisted switch from `UserDefaults` key `ImmerseDebugTestingUnlock`; it starts on when the key is absent. Directly constructed Journals in tests and the PopulatedJournalHarness start off.
- The Load Film and Subscription screens show **Testing unlock - Debug build** while on. Settings has a **Debug testing** section with the switch.
- Existing UI tests launch with `-ImmerseDebugTestingUnlock NO`, so they keep exercising the shipping gate.
- `Scripts/verify-release-excludes-testing-unlock.sh`, now run by `Scripts/validate-local.sh`, builds the app for devices in Debug and Release.
  It requires the unlock's type name, defaults key and copy in the Debug bundle and their absence from the Release bundle, with `SubscriptionController` present in both as a control.

## Scenarios

| Scenario | Expected | Observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Debug, unlock on | Every Camera loads; no Trial write; StoreKit access unchanged | All five Cameras loaded as subscription Films; a saved capture committed; in-memory Keychain calls recorded no write; Trial state stayed unused; `billing.access` stayed `notPurchased` | Pass | `TestingUnlockTests.testUnlockLoadsEveryCameraWithoutTouchingTheTrialOrStoreKit` |
| Debug, unlock off | Original Trial gating | First load used the Trial and wrote the device record; a second load was refused as Trial in progress; after the first save consumed the Trial, another load was refused with subscriptions unavailable | Pass | `TestingUnlockTests.testSwitchedOffTheTrialAndItsLimitsApplyAsInRelease` |
| Off after on | Unlocked Films stay usable (ADR 0006); Trial untouched; gating returns | Turning off left the Trial unused and unwritten; the unlocked 6x6 Film took another capture, completed and developed; the Super 8 Film remained; the next load used the Trial and the one after was refused | Pass | `TestingUnlockTests.testTurningTheUnlockOffKeepsItsFilmsUsableAndRestoresTrialGating` |
| Default and persistence | On by default in Debug; switch holds across launches | A fresh defaults suite started on; off and on again each held for a new instance | Pass | `TestingUnlockTests.testSwitchStartsOnInADebugBuildAndPersistsAcrossLaunches` |
| Indicator and Settings switch | Indicator on load and plan screens only while on; switch persists across app relaunches | Indicator present, absent after switching off and relaunching, present again after switching on and relaunching; light and dark screenshots retained in the result bundles | Pass | `TestingUnlockUITests.testUnlockIndicatorFollowsThePersistedSettingsSwitch` |
| Unavailable or malformed switch value | Safe default, no protective control removed | No defaults gives off; a non-Boolean value reads as off through `bool(forKey:)`; Release has no switch at all | Pass by construction | `TestingUnlock.init` |
| Release | No unlock path or copy | Debug bundle contains all three markers; Release bundle contains none, while containing `SubscriptionController` | Pass | `sh Scripts/verify-release-excludes-testing-unlock.sh` |
| Physical iPhone | Captain's manual test | Not run: no device action is authorized for this task | Untested | [manual-validation.md](manual-validation.md#debug-testing-unlock) |

## Local Validation Before the Rebase

These runs used `14328bf` as the base.
`sh Scripts/validate-local.sh` ran on 2026-10-02 with dedicated simulators (`Immerse Unlock 26.5` for navigation and the harness, `Immerse Unlock Billing 26.2` for hosted and StoreKit tests), under host load averages of roughly 50 to 660.
All package, study and process-exit tests passed, the document package matched, the unsigned simulator and device builds succeeded, the Release check passed and the PopulatedJournalHarness passed 12 of 12 after its generated project was regenerated to include the new source file.
The script then stopped at the app UI stage with exit 65.

- `TestingUnlockUITests` and `testDeniedCameraAtLoadFilmLoadsNothingAndPointsToSettings` passed.
- `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` and `testLargestDynamicTypeCatalogAndLandscapeSettings` failed only on QA-13 audit findings that `14328bf` still had (Movie Orientation, Portrait, Landscape, Silent capture, Trial status and the 16mm description contrast at the scroll edge; see [qa13-measurement-049.md](qa13-measurement-049.md)).
  None of them was on the unlock UI: the notice is hidden with the unlock off, and the Debug testing section of Settings was not among the findings.
  The same tests on unmodified `14328bf` on the same simulator failed with the same finding types; counts varied run to run, as recorded since 046.
  PR #9 has since fixed those findings and made these audits pass on `b4d9527` ([qa13-audit-exceptions-052.md](qa13-audit-exceptions-052.md)), so this comparison no longer describes the base.
- `ContentSizeTests` exceeded its 3-minute allowance after 6 of 12 launches.
  Unmodified `14328bf` timed out the same way on the same simulator at the same time, which pointed to host load rather than this change.
  PR #9 has since rewritten `ContentSizeTests`.

Because the script stops at the UI stage, the hosted and StoreKit stage was run separately with the script's command: 27 of 28 passed, including all four `TestingUnlockTests` and the four StoreKit tests.
`CaptureControllerIntegrationTests.testDeletingFilmWhileItsSaveIsHeldIgnoresTheLateSaveEvent` failed once with the generic "The operation did not finish" alert.
It constructs its Journal directly, so the unlock is off, and it calls `trial.start` rather than `load`.
Repeated runs: this branch 14 of 15 and then 40 of 40, unmodified `14328bf` 15 of 15.
The failure was intermittent and load-dependent, and the race behind it predates this change.

### Intermittent Delete Failure: Cause Found and Fixed

`JournalModel.reloadFilms` listed Films and then checked each Film's staging directory through `FilmRepository.hasPendingCapture`, which throws `PersistenceError.filmNotFound` once the Film's row is gone.
While `JournalModel.remove` awaits the Trial owner's deletion off the main actor, `CaptureController` refreshes the Journal.
A Film deleted between the listing and its check therefore reached the Journal alert as "Could not finish", and every Film was marked as having a pending save until the next refresh.
`reloadFilms` now drops a listed Film that is no longer found, and it still reports every other failure.
`JournalIntegrationTests.testFilmDeletedBetweenListingAndPendingSaveCheckLeavesTheJournalWithoutAnAlert` deletes a Film right after the Journal lists it and before the pending-save check, through a second repository, as the Trial owner does.
That makes the race deterministic; the test asserts no alert, the surviving Film's pending save still detected, and the deleted Film dropped.
On `Immerse Unlock Billing 26.2`, before the fix, it failed with the same "The operation did not finish" alert, kept the deleted Film listed and marked both Films pending.
With the fix, `JournalIntegrationTests`, `CaptureControllerIntegrationTests` and `TestingUnlockTests` passed 25 of 25.
Then 30 repetitions each of the new test and `testDeletingFilmWhileItsSaveIsHeldIgnoresTheLateSaveEvent` passed 60 of 60, at a host load average of about 110.

## Rebased Head

`b4d9527` made the `JournalFlowTests` audits pass and rewrote `ContentSizeTests`, so their outcome with this change has to be observed on the rebased head, not inferred from the runs above.
The Debug testing section is the first Settings section in every Debug UI run, including `shippingGate()` launches, because the launch argument only turns the switch off.
`testLargestDynamicTypeCatalogAndLandscapeSettings` therefore audits that section in landscape at the largest accessibility text size.

On 2026-10-03, `7e61621` was checked on that one test only, not the full script.
A first run built with Xcode's default local signing failed contrast on the 16mm entitlement line ("One Trial Film on this iPhone") at the Load Film audit.
That build could read the simulator Keychain, so the Load screen showed the unused-Trial line and its longer note instead of "Trial status unavailable".
The held drags then stopped with Load Film at y = 828.7, not at the y = 726.7 pose recorded in 052, and the entitlement line sat under the navigation bar.
The script and CI build with `CODE_SIGNING_ALLOWED=NO`, where the Keychain read fails, as in every 052 run.
Built that way, on a new iPhone 17 Pro simulator with iOS 26.5, light appearance and large text, the test passed.
It reached Load Film at y = 726.7, its only finding was the accepted 16mm description at the title pose, and the landscape Settings audit, Debug testing section included, reported nothing.
The same build and simulator switched to dark failed the test twice, at host load averages of about 500 to 860.
Both times the only findings were Dynamic Type on "One silent Movie after Development" and "Deliberate framing, finer grain" at the 16mm load audit before any scrolling; contrast at both 16mm poses and the landscape Settings audit passed.
Those two rows are unchanged by this branch.

Later on 2026-10-03, `7af6aba` and unmodified `b4d9527` were compared on one new iPhone 17 Pro simulator with iOS 26.5, dark appearance and large text, each built with `CODE_SIGNING_ALLOWED=NO` into its own derived data, at host load averages of about 500 to 1,000.
The same test ran four times, alternating head and base:

- Head, first run: every audit passed, including the 16mm load audit with Dynamic Type and the landscape Settings audit with the Debug testing section.
  The test still failed because it ran 184 s against the script's 180 s allowance, during teardown, and the simulator then shut down.
  The other three runs used a 600 s allowance.
- Base, first run: failed Dynamic Type on "Deliberate framing, finer grain" at the 16mm load audit, the same audit point and element as the dark failures above.
- Head, second run: passed in 147 s.
- Base, second run: passed in 137 s.

So the dark Dynamic Type finding at the 16mm load audit also comes and goes on `b4d9527` without this change, as 052 describes for the Form audit points, and is not caused by this branch.
In both head and base runs, the retained landscape Settings screenshot shows the portrait rendering turned sideways in the left part of the image, so the audit result is the evidence for that pose, not the screenshot.

The unlock itself was driven on `7af6aba` through the real UI with a temporary UI test that was not committed, on a separate new iOS 26.5 simulator built with Xcode's default simulator signing so that the Trial record could be read.
With the unlock on by default after a fresh install, all five Cameras loaded and each Load screen showed the indicator instead of the Trial line.
After turning the switch off in Settings and relaunching, the Load screen read "One Trial Film on this iPhone", the next load used the Trial and the one after was refused with "A Trial Film is already waiting in your Journal".
Turning the switch on again and relaunching brought back the indicator, and the Instant Camera loaded.
`sh Scripts/verify-release-excludes-testing-unlock.sh` passed on the same head.

### CI Rename Step Race

CI on `71017a8` failed `PopulatedWorkflowTests.testEarlyPhotoDevelopmentDarkroomAndRemoval` at "The Rename field is empty before typing", while the other 11 harness tests passed.
The test read the Rename field 0.03 to 0.23 s after `typeText` returned from 22 deletes; the retained screen recording shows the field between "Private" and "P" at those reads and empty about 0.2 to 0.35 s later.
On iOS 26 the keyboard runs in its own process, so typed edits can land after XCUITest's idle wait.
Main's CI on `b4d9527` and the PR #10 CI passed this test, and three local runs of the unchanged test passed, so the race is timing-dependent and predates this branch.
The test now waits up to 10 s for the field to be empty before typing and to hold the new title before tapping Save.
With the wait, the test passed in three local runs on an iOS 26.5 simulator under heavy host load; CI has not yet run it.

### CI Clipped-Text Finding on the Load Screen

CI on `cab756d` and `4647833` failed `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` with one finding at `Super8-load-default`: clipped text on the entitlement line, "Trial status unavailable".
Main's CI on `b4d9527` and the PR #10 CI passed that test.
On iOS 26.5 iPhone 17 Pro simulators with light appearance, large text and `CODE_SIGNING_ALLOWED=NO`, the head failed 3 of 3 runs and unmodified `b4d9527` passed 2 of 2, with identical accessibility trees at the audited pose.
The failing run's screen recording shows the clipped-text check resizing the text in place, with the entitlement line cut by the bottom edge of the screen at one size.
The finding followed any conditional that held the entitlement row: the unlock's `if`/`else` inside its Section (`cab756d`), around the Section (`4647833`) and as two separate `if` statements all failed with it.
Main's unconditional Section in the same head passed.
`LoadFilmView` now chooses between two whole forms built by one `form(access:)` helper, so the entitlement rows are no longer inside a conditional, and the form with the unlock off and in Release is main's.
The unlocked form still shows the indicator and the fixed-Camera copy.
Built that way, the catalog test passed twice (179 s and 184 s) on `Immerse Unlock 26.5`.
On a second iOS 26.5 iPhone 17 Pro simulator with the same settings, `TestingUnlockUITests` passed in 273 s and `testLargestDynamicTypeCatalogAndLandscapeSettings` passed in 263 s.
Host load averages were about 340 to 950; the full script and the dark pass were not rerun.

## Limits

- Simulator results on iOS 26.2 (unit) and 26.5 (UI) with injected in-memory Keychain calls; no physical Keychain, camera or Home Screen launch was exercised.
- The unlock appears only when Xcode's Run action uses Debug. A Run action switched to Release installs the shipping gate.
- Containment is the compile-time Debug scope; restoration is reverting the change. Films created on a phone while unlocked remain there by design.
- The unlock is temporary. Removal or retention is the captain's call once manual v1 testing ends.
