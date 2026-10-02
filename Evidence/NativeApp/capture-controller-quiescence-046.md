# CaptureController Quiescence and Late Callbacks 046

Continuation from `de68de97c78d1f0bb1d76ea93f8e3e6fc5ba9e6d`.
This checkpoint covers the remaining-engineering item for capture quiescence and late callbacks at the app's `CaptureController` level, plus the denied Camera request in the actual production views.
It drives the real `CaptureController`, `AVFoundationCaptureBackend`, `TrialCoordinator`, `FilmRepository` and `FilmProcessor` with synthetic media on a simulator, which has no camera.
It is not hardware capture, an actual AVFoundation save callback, a physical interruption, Keychain, power-loss or full-v1 acceptance.

## Reproduced Defects

All four controller defects were reproduced by new hosted tests against unchanged production behavior (`DerivedData/CaptureController-046-red-2.xcresult`).
The only production edit in that run was the test seam described below, which leaves the shipping default unchanged.

| Defect | Observed before the fix | Reachable path |
| --- | --- | --- |
| Discarding a revealed print deleted another capture's unfinished save | `JournalModel.remove(_:sequence:)` called the whole-Film privacy cancel for a single Discard. The backend's cancel removes every uncommitted staged capture for that Film. After Discarding Instant print 1, the staged second print was gone; Resume Save then left the Film at 1 saved and 9 left, so the person's second print was lost without being saved or counted. | The camera was opened for that Film in this session and a later print's save was retained after a failure. Film detail then shows Resume Save while revealed prints remain openable and can be Discarded. |
| The camera could start after Done | An `open` still awaiting the recovery of a retained save continued after Done and called `AVFoundationCaptureBackend.start`. On the simulator, `start` failed at its own OS authorization guard and `open` threw `notRunning`, which shows the start was attempted after the camera screen closed. On a device `start` would succeed and run the camera with no viewfinder until the app resigned active. | Open Camera on a Film with a retained save, then tap Done while that save finishes. The device effect is unverified here. |
| A late save event during Delete Film showed a failure | The recovered Instant print's save event requested development of the Film being deleted. Deletion succeeded, then an alert said "Could not finish / The operation did not finish. Saved captures remain private; retry after checking available storage." | Tap Done and Delete Film while an Instant print's save is still finishing. |
| Resume Save showed a failure after succeeding | With the camera attached, Resume Save committed the retained Instant print. The print's save event then requested development while Resume Save still owned the Film, and the same storage alert appeared after a successful save. | Resume Save on an Instant Film after a failed save in the same session. |

The actual app also showed storage advice for a Keychain failure.
In the first denied-Camera UI attempt, XCTest's own alert handling allowed Camera access, so Load Film reached the Trial check and the unsigned simulator's Keychain returned -34018.
The red text read "The operation did not finish. Saved captures remain private; retry after checking available storage. The iPhone's secure Trial record could not be read or updated (Keychain -34018). Trial eligibility has not been reset." (`capture-controller-046/before-load-keychain-storage-copy.png`).
A Keychain failure is not a storage problem.

The full gate then exposed a crash on the iOS 26.2 runtime, which CI uses for the hosted and StoreKit tests.
`JournalIntegrationTests.testPermissionAndStorageFailuresGiveGuidanceWithoutPlaceholderErrorText`, added in 045, which never ran that stage, aborted when its `JournalModel` was released.
The crashing frames are `SubscriptionController.__deallocating_deinit` → `swift_task_deinitOnExecutorImpl` → `malloc_report` → `abort` (`DerivedData/StoreKit-20261002T005851Z.xcresult`, crash log attached).
`SubscriptionController` used an `isolated deinit`, and the 26.2 runtime aborted when that deinit ran on the main thread outside a task, as in a synchronous test.
The same test passed on iOS 26.5.
A new hosted test of the startup path, where `JournalModel(root:)` cannot open its storage and releases the controller inside a task, threw cleanly on 26.2 (`IsolatedDeinit-046-red.xcresult`), so the "Journal unavailable" screen was not shown to crash.
The fix still matters for any synchronous release on a supported runtime that behaves like 26.2; only 26.2 (aborts) and 26.5 (passes) were executed.

## Correction to Checkpoint 045

`permission-storage-failures-045.md` says a denied Camera cannot be staged on the simulator because `simctl privacy` has no camera service.
The service list is right, but the simulator does present the actual Camera request when the app asks (observed 2026-10-01 on the owned iOS 26.5 simulator).
XCTest answers that request with Allow unless the test registers an interruption monitor, which is why the first UI attempt was allowed.
`JournalFlowTests.testDeniedCameraAtLoadFilmLoadsNothingAndPointsToSettings` now resets the Camera status, declines the actual request through a monitor and asserts that the monitor ran.
Reopening an existing Film's camera with a denial is still not driven through the actual views, because the populated harness has no Camera usage key and no production UI path can create a Film on the unsigned simulator.

## Source Change

- `JournalModel` and `CaptureController` take an optional `CapturePermissionAuthorizing` (the existing NativeAdapters protocol). The default is still `AVFoundationCaptureAuthorizer`, and `AVFoundationCaptureBackend.start` keeps its own OS authorization check, so an injected value cannot start a camera. Only the hosted tests pass one, because hosted tests cannot answer the simulator's Camera request. This was reported to Firstmate before the dependent change.
- `JournalModel.remove(_:sequence:)` privacy-cancels the capture backend only for Delete Film. Discard goes straight to `FilmProcessor.discard`, whose repository tombstone already covers any staged copy of the discarded capture. SQLite `BEGIN IMMEDIATE` transactions keep a concurrent save and Discard serialized.
- `CaptureController` keeps a session request counter. Done, an Instant print being presented, `finishSaves` and a privacy cancel each close the camera. An `open` that started before a close returns without starting the session, and rechecks after `start` returns.
- The capture event loop rechecks cancellation after awaiting the backend phase. Instant development after a save goes through `JournalModel.developSavedPrint`, which returns quietly when the Film is gone, being removed, owned by another operation or has another pending save. The print then stays sealed and Film detail offers Resume Development, as it already did after launch recovery.
- A successful privacy cancel also clears the controller's last message and recording start.
- `FailureCopy` gives `TrialKeychainError` its own text without storage advice. It keeps the Keychain status for support.
- `SubscriptionController` keeps its StoreKit update listener in a write-once `nonisolated(unsafe)` property and cancels it from a plain `deinit` instead of an `isolated deinit`.

No schema, receipt, Trial, capacity, reveal, export or deletion-ordering rule changed.
User-visible behavior changes: Discard keeps another capture's unfinished save for Resume Save, the camera stays closed after Done, and a print saved while another operation owns the Film waits for Resume Development instead of failing with an alert.
Whether such a print should develop automatically once the other operation ends is a reversible UX default for review, not a settled product choice.
The copy is a reversible engineering default, not approved support text.

## Observed Behavior

| Case | Expected and observed result | Evidence |
| --- | --- | --- |
| Discard with another unfinished save | Discarding revealed Instant print 1 leaves its numbered placeholder, keeps the staged second print and Resume Save. Resume Save then saves it: 2 saved, 8 left, placeholder [1], staged file removed after commit. | `CaptureControllerIntegrationTests.testDiscardingRevealedPrintKeepsAnotherCapturesUnfinishedSave` |
| Resume Save with the camera attached | Resume Save commits the retained Instant print with no alert and no pending save. The print is either already revealed or sealed for Resume Development, which reveals it. | `testResumeSaveForAttachedInstantCameraShowsNoFailure` |
| Done while open finishes a save | With the Trial receipt update held, Done is tapped. After release, `open` returns without error and without a preview, phase stays interrupted, the first capture is saved and sealed, the staged file is gone and the Trial is consumed once. | `testDoneDuringCameraOpenFinishesTheSaveWithoutStartingTheSession` |
| Delete Film while its save is held | Done, then Delete Film while the first Trial print's receipt update is held. After release the Film, its staging and media are gone, the controller is detached, no alert appears and the Trial stays consumed. | `testDeletingFilmWhileItsSaveIsHeldIgnoresTheLateSaveEvent` |
| Switching Films with an unfinished save | Opening a second Film first finishes the previous Film's retained save. When that save fails, the second Film does not attach and the save stays pending; after the failure clears, the save commits before the second Film attaches. | `testOpeningAnotherFilmFinishesThePreviousFilmsSaveFirst` (passed before and after the fix) |
| Denied Camera at the controller | Reopening a Film's camera with Camera denied throws `cameraDenied`, attaches nothing and creates no staging directory. Load Film with Camera denied writes no Film and no Trial record. | `testDeniedCameraOnReopenAttachesNothingAndLoadsNoFilm` (passed before and after the fix) |
| Denied Camera in the actual app | Load Film shows the actual Camera request. Declining it shows "Camera access is off. No Film was loaded. Allow Camera in iPhone Settings." with no alert, the Journal stays empty and Settings shows "Camera, Off". The simulator records the decision as user consent, denied. | `JournalFlowTests.testDeniedCameraAtLoadFilmLoadsNothingAndPointsToSettings`, `capture-controller-046/load-camera-denied.png`, `settings-camera-denied.png` |
| Keychain failure copy | A `TrialKeychainError` raised by the production store for a locked or unavailable Keychain has no storage advice or placeholder error text and says Trial eligibility has not been reset. With the old copy restored, the test failed on the storage advice (`KeychainCopy-046-red.xcresult`). | `JournalIntegrationTests.testPermissionAndStorageFailuresGiveGuidanceWithoutPlaceholderErrorText` |
| Releasing the Journal on iOS 26.2 | The test above no longer crashes on iOS 26.2, and a Journal whose storage cannot be opened throws instead of crashing. | Same test plus `testJournalThatCannotOpenItsStorageFailsWithoutCrashing`, `StoreKit-046-final.xcresult` |

The hosted tests hold a Trial receipt update by blocking an injected in-memory Keychain call on the Trial owner's thread, never the main actor.
A staged synthetic photo stands in for a capture whose save has not finished: it is the same photo and metadata pair the backend writes to the Film's staging directory before committing.

## Executed Gates

Environment: macOS 26.6.2 (25G83), Xcode 26.5, Swift 6.3.2.
Hosted and UI execution used the owned iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, iOS 26.5 (23F77).

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
  -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' \
  -derivedDataPath DerivedData/ValidationSimulator \
  -resultBundlePath DerivedData/CaptureController-046-green.xcresult \
  -only-testing:ImmerseTests/CaptureControllerIntegrationTests -only-testing:ImmerseTests/JournalIntegrationTests \
  -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
  CODE_SIGNING_ALLOWED=NO test
```

| Run | Outcome |
| --- | --- |
| `CaptureController-046-red.xcresult` | Unchanged behavior. Four controller defects reproduced; other failures came from the test omitting launch recovery, which left every Film reporting a pending save. Log `capture-controller-046/hosted-red-1-setup.log`. |
| `CaptureController-046-red-2.xcresult` | Unchanged behavior with corrected setup. Four failed exactly as listed under Reproduced Defects; the Film-switch and denied-camera tests passed. Log `hosted-red-2.log`. |
| `CaptureController-046-green.xcresult` | After the fix, 6 new and 5 existing Journal tests passed. |
| `CaptureController-046-repeat.xcresult` | The 6 new tests with `-test-iterations 5`: 30 of 30 repetitions passed. |
| `CameraDenied-046-1.xcresult` | UI attempt failed: XCTest allowed the actual Camera request, Load Film reached the unsigned Keychain failure. |
| `CameraDenied-046-2.xcresult`, `-3` | UI attempts declined the request and showed the denial copy; the Settings row lookup failed first because the row was below the fold, then because Form rows combine label and value. Test mechanics only. |
| `CameraDenied-046-4.xcresult` | UI test passed. |
| `sh Scripts/validate-local.sh` with both iOS 26.5 UI variables set | Exit 65 (`capture-controller-046/validate-local-1-test-compile.log`). Requirement map (122 IDs, 72 clauses, 9 invariants), all package tests (FilmDomain 13, MediaCatalog 4, RenderFixtures 2, RenderCore 11, FilmPersistence 25, NativeAdapters 24, CapturePipeline 6, EntitlementCore 12, FilmRuntime 43), TrialCommitStudy 17, DevelopmentProcessExit 3, AssetReviewGenerator build, the 25-entry documents ZIP comparison, unsigned simulator and device builds and the populated harness (10 passed, `Populated-20261002T004700Z.xcresult`) passed. The UI stage then failed to compile the hosted test target, because the new copy test called `TrialKeychainError`'s internal initializer; the test now gets the error from the production store. No package source changed in this checkpoint. |
| `CaptureController-046-green-2.xcresult` | After that test fix, 6 new and 6 Journal tests passed on iOS 26.5. |
| `Validation-20261002T005626Z.xcresult` (`-only-testing:ImmerseUITests`, light, large text) | The new denied-Camera test passed. The two original tests failed only on audit findings: Super 8 "Movie Orientation" Dynamic Type, 16mm title "Deliberate framing, finer grain" contrast, and in the 16mm command audit "Silent capture" and "Trial status unavailable" contrast. 045 run 3 reported that command audit as one contrast finding with no element; both named elements appear in earlier diagnoses (`accessibility-physical-frame-diagnosis.md`, `accessibility-original-matrix-diagnosis.md`). No accessibility source changed; QA-13 remains failed and unwaived. |
| `StoreKit-20261002T005851Z.xcresult` (iOS 26.2, `-only-testing:ImmerseTests`) | 15 passed, 1 crashed: the `isolated deinit` abort above. |
| `IsolatedDeinit-046-red.xcresult` (iOS 26.2) | Before the fix: the synchronous copy test crashed again; the new startup-failure test passed. |
| `StoreKit-046-final.xcresult` (iOS 26.2, `-only-testing:ImmerseTests`) | After the fix, 16 passed: 6 CaptureController, 6 Journal and 4 local StoreKit tests. |

| Final affected stages on the final source (`capture-controller-046/final-affected-stages.log`) | Unsigned generic simulator and device app builds exit 0; populated harness 10 passed (`Populated-046-final.xcresult`); 6 CaptureController and 6 Journal hosted tests passed on iOS 26.5 (`CaptureController-046-final.xcresult`). The package, ZIP and requirement-map stages from the full gate above did not change. |

The iOS 26.2 simulator is `A5825795-2E74-49C8-BC64-A5CDCB27AF8B` (iPhone 17 Pro, iOS 26.2, 23C54), shut down after use.
Simulator UI stages ran pinned to light appearance and large text, and the owned simulator's own light/accessibility XXXL settings were restored after each run.

Result bundle hashes, computed as the SHA-256 of sorted per-file SHA-256 lines inside each bundle:

| Artifact | Hash |
| --- | --- |
| `CaptureController-046-red.xcresult` | `79f4e559fb0f037bb588adb5cdb3e48a4d3546ecc674611255eb7ec839581710` |
| `CaptureController-046-red-2.xcresult` | `1b50e80964fc14037ee2bf06006f28ec0451c7ab756e7bcb8fede4466b045eeb` |
| `CaptureController-046-green.xcresult` | `ebe5357f4b97edf5f19c28351b595b7dda13add40c575704d617ca8d7937d6aa` |
| `CaptureController-046-green-2.xcresult` | `b17534d9b04a174fe5e537f9cdda7a588884849cfbbb3a232a611036c90758b0` |
| `CaptureController-046-repeat.xcresult` | `4969c6d3e94ab7186236b4908691198d2214245cedfa90968d05f390041740ad` |
| `CaptureController-046-final.xcresult` | `b03601f56d64dd549e5250a47dc4b729884c8ce8c39f9a0de762c402cb72255a` |
| `CameraDenied-046-1.xcresult` | `d3ed5f4ae0cc5c914d568cafa8cf724ba1f1e1d07f54b06b3fd56304b208d36a` |
| `CameraDenied-046-2.xcresult` | `7cd5339ddfec1b5493e30ac69c8478f4046f53b8fa6c8d05aff7dfa0dbe07f51` |
| `CameraDenied-046-3.xcresult` | `525dce23b895a40c709f68d3d1f8b5c589f3ec53195993c41db2587ae8752109` |
| `CameraDenied-046-4.xcresult` | `0d676d9d24049538ffe38ff964147ebd31c38926683cc3688ca8c7c3c8423091` |
| `KeychainCopy-046-red.xcresult` | `1b6ea20d400ad2527172b3cbeb935cdd66924a5638637467aaf28cdfe7edacb7` |
| `Validation-20261002T005421Z.xcresult` (full gate UI stage, test compile failure) | `70e351ef452361b48f826683eacf86cd223b639ae9678c9fde68af0aa1009dc5` |
| `Validation-20261002T005626Z.xcresult` | `e2797c8cd032a4fc32bb6fd5161f8a381c6e53c1849e17cc9ccb70b682b328ef` |
| `Populated-20261002T004700Z.xcresult` | `46d94bd2654e11a970bf3759f99c780ce78de51ddcc14c5996529e98e1eae936` |
| `Populated-046-final.xcresult` | `c97eebe12ba1871f5c9ee0e48c270665d2f192005930d26db84f1fb2be4f5a11` |
| `StoreKit-20261002T005851Z.xcresult` | `31462f289f68a93b294f80debbc6d0a17210db184c1b5818cb9bd23cb2cc353e` |
| `IsolatedDeinit-046-red.xcresult` | `99fd9bf58ae0d0c06eb785bed8d8f59440024af4f8be0c6a526b4cca02ddc2c7` |
| `StoreKit-046-final.xcresult` | `ebd8ccd35699df408722e5a24c05552167dc6b94e9074a499c530a10211c49df` |

Changed sources are hashed in `capture-controller-046/source.sha256` against base `de68de9`.

## Limits

The simulator has no camera, so `open` always stops at `start`; no capture session runs, no AVFoundation photo or movie callback fires and no viewfinder appears.
The camera-after-Done defect is shown by the attempted `start`, not by an observed running camera; the device check is in `manual-validation.md` case M07.
The unfinished save is a staged synthetic photo, not an actual failed AVFoundation save, and the held save is an injected Keychain call, not Security or storage behavior.
Reopening an existing Film with Camera denied is covered at the controller only; prompt timing, a restricted Camera, and a Settings change while the app runs are not executed.
Original QA-13 accessibility findings, hardware capture/Photos/Keychain/backup gates and product decisions are unchanged and remain open.
