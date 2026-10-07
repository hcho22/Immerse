# CI Flakes 057

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work.
Main's Native validation run 37627486582 (job local-native, commit 72669c1, a documentation-only change) failed two UI tests; the next main run on 607d703 passed.
This record covers simulator evidence for the automated UI tests only.

## JournalFlowTests.testExtraSmallLoadScreensAudit

### Failure

The test exceeded its 3-minute allowance (`-maximum-test-execution-time-allowance 180`) with no assertion or audit finding.
It had finished four Cameras and was on the 16mm title field, so no step was stuck.

### Mechanism

Passing runs 37651456823 and 37631403143 took 1 minute 24 and 1 minute 28 seconds in the light pass and 1 minute 21 seconds in dark.
In the failing run the Cameras took about 35 seconds each instead of about 17, with one 41-second gap between two snapshots.
The runner's Spindump in the failing test (GitHub-hosted macOS 26.6, 3 CPUs, 7 GB) shows an ordinary test runner, not an app hang.
The cause is therefore headroom: one test ran five full audits in series with about twice its time to spare, and a slow runner removed that.
`053` split the landscape Settings measurement into two tests for the same reason.

### Fix

One test per Camera (`testExtraSmallLoadScreenAudit{Disposable,Instant,6x6,Super8,16mm}`) sharing one helper, with the same launch arguments, scroll, push wait, field check, audit and back navigation.
Each test now has the full allowance for one audit, and a runner would have to be many times slower to fail.
Nothing in the audit or its exceptions changed.

## TestingUnlockUITests.testUnlockIndicatorFollowsThePersistedSettingsSwitch

### Failure

On the third pass through Load and Plans the catalog's navigation bar did not appear within 5 seconds of the tap on Start a Film, and the next tap failed because the Journal was still showing.
The test took 1 minute 29 seconds, in line with passing runs (1 minute 26 and 1 minute 35), so the runner was not slow here.

### What the evidence shows

- The tap's synthesized event targets (201, 822) in the failing launch and in the passing launches, the centre of the button's 38 pt frame (182, 803).
- The Journal in the screen recording is fully drawn and the button is not marked disabled in the hierarchy captured six seconds later.
- The Journal is only created after launch recovery finishes (`JournalLauncher.open`), so the button's `initialRecoveryPending` disabling cannot be what the tap met. A counterfactual with an 8-second delay in `recoverAtLaunch` passed.
- A probe that launches, waits for Start a Film and taps it immediately did so 12 and then 41 times on a very loaded host (load average 50 to 100) without a miss.

### Unresolved

The cause of the one lost tap is not established.
It is not recovery, tap position, runner slowness within the test or a disabled button.
The remaining candidate is the iOS 26 bottom toolbar still settling after the Journal first appears (every launch logs "Adding 'UIKitToolbar' as a subview of UIHostingController.view is not supported"), which no run here reproduced.

### Mitigation

`openCameraCatalog(_:)` in `UITestSupport.swift` taps Start a Film, and only if the catalog did not appear after 5 seconds, which shows that the tap did nothing, keeps a screenshot named "Start-a-Film-tap-did-not-open-the-catalog" and taps once more before failing.
The test's assertions about the indicator and the persisted switch are unchanged.
If those screenshots start to show up in CI results, the lost tap is a real app defect worth chasing; a second miss still fails the test.
The other tests that tap Start a Film (`JournalFlowTests`, `MovieCapacityUITests`, `ContentSizeTests`) still use the single tap.

## Validation

Xcode 26.5, a new iPhone 17 Pro simulator on iOS 26.5 (the CI device and runtime), Large text, light, on a host with a load average above 50, `-test-iterations 4` with no retry on failure:
the five new audit tests and the unlock test passed in all 24 repetitions, and the unlock test never needed its second tap.
