# Permission and Storage Failure Checkpoint 045

Continuation from `1c019d095a40f9862bdd8dd998a4a6d4db93818f`.
This checkpoint covers representative permission and storage failures that are safely testable with synthetic or injected inputs (instruction 040), including instruction 041's distinction between a missing staging directory and an existing one that cannot be inspected.
It is not hardware capture, PhotoKit write, Camera prompt, physical storage-pressure, Keychain, backup/restore, accessibility or full-v1 acceptance.

## Reproduced Defects

### Existing but uninspectable paths read as absent

`FileManager.fileExists(atPath:)` returns false both for a missing item and for an existing item whose metadata cannot be read (for example when a parent directory denies search, or on an I/O error).
Recovery and privacy-removal code gated on it, so an uninspectable path was treated as already absent.
Before the fix, three new package tests failed against unchanged production code:

| Boundary | Observed before the fix | Retained log |
| --- | --- | --- |
| `CapturedMediaFiles` staging (NativeAdapters) | With the staging parent at mode 000, `pendingRecords()` returned an empty set and `recoveryEvents()` recovered nothing while a valid staged photo existed. `removeUncommitted(id:)` and `removeCommittedFile(for:)` returned success without removing anything. | `permission-storage-045/package-red-native-adapters.log` (4 failures) |
| Repository tombstones (FilmPersistence) | With `Staging/<film>` at mode 000, Discard of a revealed capture returned success and finished the tombstone for a residual staged copy. After permissions returned and launch `recover()` ran, the private staged bytes still existed, because the orphan sweep covers `Media` only. This was a permanent privacy leak. | `permission-storage-045/package-red-film-persistence.log` (2 failures) |
| Trial commit journal (FilmRuntime) | With a verified pending save under `Staging/<film>/Commit` and that Film's staging directory at mode 000, `TrialCoordinator.reconcile(filmID:)` returned normally and treated the journal as empty. | `permission-storage-045/package-red-film-runtime.log` (1 failure) |

The mode-000 directories are created by the tests in temporary directories and restored before cleanup.
Error codes were confirmed first: a missing item is `NSFileReadNoSuchFileError` (260) or `NSFileNoSuchFileError` (4); a denied parent is 257 or 513; a path below a regular file is 256 or 512.

### Photos denial showed storage advice and raw error text

`PopulatedJournalHarnessTests/PhotosPermissionWorkflowTests` drives the actual app views in the populated harness on the owned simulator after `xcrun simctl privacy ... revoke photos-add com.immerse.PopulatedJournalHarness`.
Against unchanged app sources (`DerivedData/Populated-photos-denied-045-red-3.xcresult`):

- Save Developed to Photos showed "Could not finish / The operation did not finish. Saved captures remain private; retry after checking available storage. The operation couldn’t be completed. (FilmRuntime.FilmExportError error 3.)".
  Error 3 is `permissionDenied`, because Swift numbers payload cases first.
  The denial was never shown as success, but it pointed the person at storage and exposed internal text.
- Save Originals to Photos showed only "The operation couldn’t be completed. (FilmRuntime.FilmExportError error 3.)" in red.
- Settings showed Camera "Notdetermined" and Photos (add only) "Denied", built from `String(describing:).capitalized`.

Screenshots: `permission-storage-045/before-developed-export-denied.png`, `before-original-export-denied.png`, `before-settings-privacy.png`.
Two other assertions in that run were test-mechanics failures at the simulator's accessibility XXXL text size (rows below the fold are not in the hierarchy until scrolled).
They were fixed in the test, not in the app.
Earlier attempts `-red` and `-red-2` failed on the precondition query and on scrolling before any export, and are listed in `permission-storage-045/ui-red-failures.txt`.

### Other raw error text on failure surfaces

The same "(Module.Type error N.)" text reached reopening an existing Film's camera ("Camera unavailable. ...", with `JournalError.cameraDenied` rendering as "Immerse.JournalError error 0"), the shutter, Darkroom loading and rendering, Soundtrack, the originals choice, the startup failure screen and purchase/restore messages.
The camera denial on reopen also could not be staged on the simulator, because `simctl privacy` has no camera service.

## Source Change

- `Packages/FilmPersistence/Sources/FilmPersistence/FilePresence.swift` adds `itemExists(at:)`, `contentsOfDirectoryIfPresent(at:)` and `removeItemIfPresent(at:)`.
  Only a confirmed-missing item is absent; every other inspection failure throws.
- `FilmRepository` uses them for verified-master and developed-clip checks, `hasPendingCapture`, launch Work/temporary cleanup, the orphan sweep root, `assetExists`, the durable move and asset/tombstone removal.
  An uninspectable tombstone path now stays pending and the removal throws instead of acknowledging.
- `CaptureCommitJournal`, `FilmProcessor` Work removal and `TrialCoordinator`'s existing-receipt source check use the same helpers.
- `CapturedMediaFiles` (NativeAdapters, which does not depend on FilmPersistence) has a file-private copy of the same three helpers for staging recovery and privacy cleanup.
- `App/Immerse/Sources/FilmPresentation.swift` adds `FailureCopy` and `PermissionCopy`.
  `JournalModel.report`, the originals sheet, CaptureView open/shutter, CameraCatalogView, PhotoView, SoundtrackView, startup, catalog/Trial status and purchase/restore messages use them.
  Photos denial, not-granted, write failure and unconfirmed save each have their own text, and none suggests storage for a permission failure.
  Reopening a Film's camera shows the Camera-access guidance for a denial and keeps "Camera unavailable." for other failures.
  System descriptions such as "there isn't enough space" are kept; Swift errors without their own text no longer add "(Module.Type error N.)".
  Settings shows Not asked yet, Allowed, Limited, Off or Restricted.
- `Scripts/validate-local.sh` revokes add-only Photos for the harness before its suite and now pins each simulator UI gate to light appearance and large text, restoring that simulator's own preferences on exit, like `Probes/PopulatedJournalHarness/run-retained.sh`.
  Without the pin, the first full run failed four existing harness tests at the simulator's saved accessibility XXXL size (see Executed Gates).
- `RetainedWorkflowTests.testDarkroomAccessibleControlsReachNonGestureEditingPaths` (from 044, previously executed only at XXXL) now drags the Darkroom content from the plain "Dodge / Burn" heading until "Undo last stroke" clears the bottom bar before tapping it.
  At the default large size the row rests in the bottom bar's scroll-edge band, where the tap reached the bar and the stroke stayed; the content does scroll clear, as standard iOS 26 bottom-bar behavior.
  Production Darkroom layout is unchanged; whether the last control should rest clear of the bar at the default size is a design observation for the paused QA-13/H-UX review, not a settled finding.

No schema, receipt, Trial, entitlement, capacity, reveal or export-ordering rule changed.
The behavior change is that an existing but uninspectable path now fails the operation and leaves tombstones and pending saves in place instead of reporting empty or removed.
Wording is a reversible engineering default, not approved support copy.
When the app asks for Camera and Photos permission remains an open prototype question; the code keeps its existing default of asking at Load Film and at the first explicit export.

## Observed Behavior

| Case | Expected and observed result | Evidence |
| --- | --- | --- |
| Uninspectable staging directory | `pendingRecords` and `recoveryEvents` throw `fileReadNoPermission`; both removals throw `fileWriteNoPermission`; after permissions return the staged photo and its record are intact. | `CapturedMediaFileTests.testExistingStagingDirectoryThatCannotBeInspectedIsNeitherEmptyNorRemoved` |
| Uninspectable residual staged copy during Discard | Discard throws `fileWriteNoPermission`; the placeholder is recorded; `hasPendingCapture` throws instead of returning false; after permissions return, launch `recover()` finishes the pending tombstone and removes the copy; the surviving capture's bytes are unchanged. | `PrivacyRecoveryTests.testDiscardKeepsTombstoneWhenExistingStagedCopyCannotBeInspected` |
| Uninspectable pending Trial save | Relaunched `reconcile` throws `fileReadNoPermission` with zero saved captures and an unconsumed Trial; after permissions return, the same reconcile projects one capture and consumes the Trial once. | `TrialIntegrationTests.testPendingSaveThatCannotBeInspectedBlocksReconcileUntilReadable` |
| Photos add-only prompt at export | Granted after the prompt writes once and permits only later verified cleanup; denied or restricted after the prompt never dispatches the writer. | `PhotoExportAdapterTests.testCaptureStartPromptWritesOnlyAfterAddOnlyPermissionIsGranted`, `testCaptureStartPromptDenialNeverDispatchesWriter` |
| Denied Photos in the actual views | Settings shows Photos (add only) Off. Save Developed to Photos shows Photos-access guidance pointing to iPhone Settings, with no storage advice, error text or Saved alert. Save Originals to Photos shows the same guidance inline, and the original export stays pending. | `PhotosPermissionWorkflowTests.testDeniedAddOnlyPhotosExportIsNeverSuccessAndPointsToSettings` |
| Failure copy rules in the app model | A Photos denial reported through `JournalModel` produces Photos guidance without storage advice; cancellation shows nothing; camera denial points to iPhone Settings without claiming a Film load; out-of-space keeps the system description; none of eight representative failures shows "error" or "couldn’t be completed". | `JournalIntegrationTests.testPermissionAndStorageFailuresGiveGuidanceWithoutPlaceholderErrorText` |

## Executed Gates

Environment: macOS 26.6.2 (25G83), Xcode 26.5, Swift 6.3.2.
Hosted iOS execution used the owned iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, iOS 26.5 / build 23F77, with the accessibility-extra-extra-extra-large content size left by earlier runs.

Red package runs against unchanged production code, one test each:

```sh
swift test --package-path Packages/NativeAdapters --filter CapturedMediaFileTests/testExistingStagingDirectoryThatCannotBeInspectedIsNeitherEmptyNorRemoved
swift test --package-path Packages/FilmPersistence --filter PrivacyRecoveryTests/testDiscardKeepsTombstoneWhenExistingStagedCopyCannotBeInspected
swift test --package-path Packages/FilmRuntime --filter TrialIntegrationTests/testPendingSaveThatCannotBeInspectedBlocksReconcileUntilReadable
```

Results: 4, 2 and 1 failures as listed above; logs in `permission-storage-045/`.
After the fix, NativeAdapters passed 24 tests, FilmPersistence 25 and FilmRuntime 43.
The first two FilmRuntime attempts after the fix did not compile: its cached SwiftPM build plan still listed the old FilmPersistence sources without `FilePresence.swift` (`package-stale-plan-film-runtime.log`).
`swift package clean` on FilmRuntime, CapturePipeline and the three dependent probes cleared that cache; no source changed.

Hosted iOS used the full Photos-permission command in `Probes/PopulatedJournalHarness/README.md` (after its `simctl privacy` revoke) and:

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
  -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' \
  -derivedDataPath DerivedData/ValidationSimulator \
  -resultBundlePath DerivedData/Immerse-failure-copy-045-final.xcresult \
  -only-testing:ImmerseTests/JournalIntegrationTests -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
  CODE_SIGNING_ALLOWED=NO test
```

The red and green harness runs used the simulator's saved accessibility XXXL size; the green run passed one test.
`JournalIntegrationTests` passed five tests on the final source (`DerivedData/Immerse-failure-copy-045-final.xcresult`).

Full gate, `IMMERSE_WORKFLOW_SIMULATOR_UDID` and `IMMERSE_SIMULATOR_UDID` both set to the owned simulator:

```sh
sh Scripts/validate-local.sh
```

| Run | Outcome |
| --- | --- |
| 1 | Exit 65. Every package, probe, traceability, ZIP and build stage passed. The populated harness at the saved XXXL size passed six tests, including the new Photos test, and failed four existing tests whose rows were below the fold (`validate-local-1-xxxl-failures.txt`). This led to pinning the UI gates to light/large. |
| 2 | Exit 65. With the pin, the four tests from run 1 passed; the 044 Darkroom test failed at the default size because Undo was tapped while resting in the bottom bar's edge band (`validate-local-2-darkroom-undo.txt`, `darkroom-undo-edge-band-large.png`). The test now scrolls the row clear first and passed at both large and XXXL. |
| 3 | Exit 65 on the final source. Traceability (122 IDs, 72 clauses, 9 invariants), all packages (FilmDomain 13, MediaCatalog 4, RenderFixtures 2, RenderCore 11, FilmPersistence 25, NativeAdapters 24, CapturePipeline 6, EntitlementCore 12, FilmRuntime 43), TrialCommitStudy 17, DevelopmentProcessExit 3, AssetReviewGenerator build, the 25-entry documents ZIP comparison, unsigned simulator and device builds, and the populated harness (10 passed, 0 failed) all passed. `ImmerseUITests` then failed only on the original light QA-13 audit findings: Super 8 "Movie Orientation" Dynamic Type, plus the 16mm title description and the command contrast with no element supplied. These are the same three light findings recorded in `accessibility-original-matrix-diagnosis.md`; they remain failed and unwaived. |

Each run restored the simulator's own appearance and text size (light, accessibility XXXL) on exit.

Result bundle hashes, computed as the SHA-256 of sorted per-file SHA-256 lines inside each bundle:

| Artifact | Outcome | Hash |
| --- | --- | --- |
| `DerivedData/Populated-photos-denied-045-red.xcresult` | precondition query failed before any export | `51c343e1753ced10ad3becd9c1763b1461f14b758277281f1414650c90212544` |
| `DerivedData/Populated-photos-denied-045-red-2.xcresult` | choice row below the fold before any export | `d9a57b77640476de91b16e14619a6863cc7f15787222cb4d701d5b88c5d89e50` |
| `DerivedData/Populated-photos-denied-045-red-3.xcresult` | defect reproduced on unchanged app sources | `ceeb889116c4b04cbd32b75cede76339adae5058415022fd4e2ee3594659e660` |
| `DerivedData/Populated-photos-denied-045-green.xcresult` | one test passed | `8c2528c466c190914798ad72d0e348cd849d0d6bf36e38538f1ebd31815ee2b9` |
| `DerivedData/Populated-20261001T231824Z.xcresult` | run 1 harness, 6 passed, 4 failed | `b79374fa0c819408adffcd267cac89bc208d328cbd1b068ec6b5719b296b87be` |
| `DerivedData/Populated-20261001T233019Z.xcresult` | run 2 harness, 9 passed, 1 failed | `f71a6fd777a85a1c34673030ec8d9347d4579cdff994031bf244c057b6cb3cd7` |
| `DerivedData/Populated-darkroom-undo-diag-045.xcresult` | instrumented failure at large | `24d17318e05ecedcea41cd3e530e503b244b53de40e7771efaaf443db78a4b27` |
| `DerivedData/Populated-darkroom-scroll-diag-045.xcresult` | scroll measurement at large | `759e5005b73c47a3d4589afbf5c7e13a2a9645a050f5ea893da6544ed93dc8df` |
| `DerivedData/Populated-darkroom-undo-045-large.xcresult` | Darkroom test passed at large | `35ffbb949eee65d48fa7409b05f86c91365195b7d8b6961ed16f1f94a5b4c6e5` |
| `DerivedData/Populated-darkroom-undo-045-accessibility-extra-extra-extra-large.xcresult` | Darkroom test passed at XXXL | `1b003cb32203a82f7939e557f35ef9956b48fffe2d5d74ff7b40923b74d4d15d` |
| `DerivedData/Populated-20261001T235502Z.xcresult` | run 3 harness, 10 passed | `255bd181569b8805b5ed91ecaec3093aced74700711ca0ce53b46d7cc6fa45dc` |
| `DerivedData/Validation-20261002T000254Z.xcresult` | run 3 app UI, original audit findings | `d4aa5a92f9df30a9b406e4f0712f963bddf53045074a7f0a77131724d186be34` |
| `DerivedData/Immerse-failure-copy-045.xcresult` | hosted, 5 passed before the final camera-copy edit | `95c56aa1fa01d92c487d5858dd4a6dfa21ecfbb0cf4d30f4181b9e9dd0a2607d` |
| `DerivedData/Immerse-failure-copy-045-final.xcresult` | hosted, 5 passed on the final source | `2e01a827b95111b70e01673875244921e2a333d7c59bd77ae677308c0284ad1b` |

Final screenshots at the default size are `permission-storage-045/after-*.png`; changed sources are hashed in `permission-storage-045/source.sha256` against base `1c019d0`.

## Limits

The uninspectable cases use POSIX permissions on macOS temporary directories.
They do not execute iOS sandbox, data-protection or flash I/O failures, physical storage pressure or power loss.
The Photos case reads the simulator's add-only authorization after a host revoke; no PhotoKit write, restricted or limited status, prompt presentation or real Photos library is exercised.
The camera denial is covered only by the hosted copy test, because the simulator cannot stage a denied camera.
Checkpoint 046 found that the simulator does present the actual Camera request and that XCTest allows it unless a test declines it; see `capture-controller-quiescence-046.md`.
`CaptureStartupCoordinator` and its package tests are not used by the app, which checks Camera permission inline in `JournalModel.load` and `CaptureController.open`; its tests do not establish app behavior.
Original QA-13 accessibility failures, hardware capture/Photos/Keychain/backup gates and product decisions are unchanged and remain open.
