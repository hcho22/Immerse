# Debug Testing Unlock

Prepared 2026-10-02 for the captain's request: "for immerse, can you unlock the subscription for now so that i can test all cameras and features manually?"
Branch `fm/immerse-testing-unlock`; the base is `14328bf`.
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

## Local Validation

`sh Scripts/validate-local.sh` ran on 2026-10-02 with dedicated simulators (`Immerse Unlock 26.5` for navigation and the harness, `Immerse Unlock Billing 26.2` for hosted and StoreKit tests), under host load averages of roughly 50 to 660.
All package, study and process-exit tests passed, the document package matched, the unsigned simulator and device builds succeeded, the Release check passed and the PopulatedJournalHarness passed 12 of 12 after its generated project was regenerated to include the new source file.
The script then stopped at the app UI stage with exit 65.

- `TestingUnlockUITests` passed. `testDeniedCameraAtLoadFilmLoadsNothingAndPointsToSettings` passed.
- `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` and `testLargestDynamicTypeCatalogAndLandscapeSettings` failed only on the retained QA-13 audit findings (Movie Orientation, Portrait, Landscape, Silent capture, Trial status and the 16mm description contrast at the scroll edge; see [qa13-measurement-049.md](qa13-measurement-049.md)). None is on the unlock UI, which is off in these tests. The same tests on unmodified `14328bf` on the same simulator failed with the same finding types; counts vary run to run, as recorded since 046.
- `ContentSizeTests` exceeded its 3-minute allowance after 6 of 12 launches. Unmodified `14328bf` timed out the same way on the same simulator at the same time, so this is host load, not this change.

Because the script stops at the UI stage, the hosted and StoreKit stage was run separately with the script's command: 27 of 28 passed, including all four `TestingUnlockTests` and the four StoreKit tests.
`CaptureControllerIntegrationTests.testDeletingFilmWhileItsSaveIsHeldIgnoresTheLateSaveEvent` failed once with the generic "The operation did not finish" alert. It constructs its Journal directly, so the unlock is off, and it calls `trial.start` rather than `load`.
Repeated runs: this branch 14 of 15 and then 40 of 40, unmodified `14328bf` 15 of 15. The failure is intermittent and load-dependent and was not reproduced on demand.
Unconfirmed hypothesis for follow-up: `JournalModel.reloadFilms` lists Films and then reads each staging directory, so a Film deleted concurrently by the Trial owner between those reads throws `PersistenceError.filmNotFound` into the Journal alert.

## Limits

- Simulator results on iOS 26.2 (unit) and 26.5 (UI) with injected in-memory Keychain calls; no physical Keychain, camera or Home Screen launch was exercised.
- The unlock appears only when Xcode's Run action uses Debug. A Run action switched to Release installs the shipping gate.
- Containment is the compile-time Debug scope; restoration is reverting the change. Films created on a phone while unlocked remain there by design.
- The unlock is temporary. Removal or retention is the captain's call once manual v1 testing ends.
