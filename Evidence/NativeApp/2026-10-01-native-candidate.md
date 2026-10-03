# Native App and Billing Candidate

Status: partial implementation, not full v1 acceptance. Candidate is the source
commit containing this report (developed after `39894a5`). Environment: macOS
26.6.2, Xcode 26.5, Swift 6.3.2, unsigned iPhone targets; no physical device action,
Apple credentials, real purchase, portal changes or release. Production product
IDs remain absent; DEC-02 prices/offers/refund decisions remain open.

## Implementation and Expected Behavior

| Requirements | Implementation | Behavioral verification and gap |
| --- | --- | --- |
| ARC-01, UX-01/02/03/04/05/07/08; FR-02 | `App/Immerse`, JournalView, FilmDetailView, JournalModel; persisted FilmDomain/FilmPersistence | Native Journal, grouped states, multiple Films, title/Archive navigation and revealed-only contact sheet. First empty-Journal/catalog/Settings/Archive UI test passed on iOS 26.5. Populated UI lifecycle and device acceptance remain untested. Backward clock date range regression passes. |
| SET-01/04/05/06/08; FR-03 | CameraCatalogView, JournalModel.load | All five Cameras browse without loading or Trial writes. Explicit load checks Camera permission before activation, locks Camera and Movie orientation. Browsing/cancel UI test passed; actual permission/load flow awaits native execution. SET-03/CAM-10 samples remain missing because no production media is cleared. |
| CAP-01 through CAP-10; CAM-02/03/05/06/07; FR-04 | CaptureController, CaptureView, AVFoundationCaptureBackend | Real rear/front preview and output, hardware capability-gated Disposable flash and 6x6 focus/exposure; square preview crop; durable journals/receipts. Controller owns pending callbacks beyond dismissal, stops on inactive, recovers staging before opening and drains saves before switching/completion. Hosted tests drive the actual controller and backend on a camera-less simulator: Done during a held save never starts the session, a late save event during Delete Film shows no failure, and switching Films finishes the previous save first; the actual app declines the real simulator Camera request at Load Film without loading a Film (`capture-controller-quiescence-046.md`). Reopening a Film's camera with the request declined shows guidance and Open iPhone Settings above the viewfinder, and the shutter stays on screen on iPhone SE, 13 Pro and 17 Pro simulators (`visual-sweep-048.md`). Hardware capture, authenticity, focus calibration, orientation and low-storage paths are not accepted by compilation. |
| MOV-01/02/03/04/05/06/07/10/11; FR-05 | CaptureView, NativeMovieRenderer, FilmProcessor, DevelopedMovieView | Native start/stop, saved-duration budget, chronological native rendering, explicit resume and Movie player. No microphone usage key/input. Native media fixture tests are recorded in the rendering report; later populated/runtime evidence covers stale Movie retirement and public AVKit player/item retirement after first Discard. Actual iPhone playback/export fidelity is pending. MOV-09 soundtrack catalog/rights/selection remains missing. |
| DEV-01/02/03/04/05/06/07/08/10; FR-06 | FilmDetailView, OriginalChoiceView, CaptureView, FilmProcessor | Explicit completion/development, exact waste snapshot checked in SQLite against late captures; Instant reveals each verified print through a photo sheet; rendering resumes persisted assignments. Native ritual, foreground interruptions and final-print UI await execution. Empty-Film policy matches DEC-09. |
| DRK-01/02/03/04/05/06/08; FR-07 | PhotoView/DarkroomView, NativePhotoRenderer | Per-photo persisted exposure, contrast grade, CMY, crop, Dodge/Burn and byte-exact Reset. No Movie entry/saturation/reroll. Native app-model test proves real render/edit/byte Reset and independent photo preservation; later populated harness evidence reaches the actual Contrast/CMY/Crop/non-gesture Dodge/Burn controls, and a drawn dodge stroke paints without scrolling, renders and persists (`darkroom-gesture-tint-047.md`). Assistive-technology execution, chemical-toning applicability and approved ranges are still open. |
| STO-01 through STO-11; FR-08 | OriginalChoiceView, FilmExportWorker, PhotoKit adapter, SettingsView | Separate explicit developed/original exports, no default or automatic Photos save, irreversible originals choice with no preselection, verified cleanup and backup disclosure. Instant choice is currently after individual reveal and remains provisional DEC-11. A simulator-denied add-only status now reaches Photos guidance in the actual views without a write (`permission-storage-failures-045.md`). Actual Photos prompt/write/fidelity, restricted/limited states and hardware backup are untested. |
| PRV-01/05/06/07/08/10, DEL-01/02/03/04; FR-16/18 | JournalModel.remove, capture cancellation, Movie player disposal, repository tombstones and deletion ledger | Hide current app media, cancel/drain capture for Delete Film, cancel render/export, remove source/master/clip/staging/work and preserve placeholders/capacity. Work directory is now ledger-covered and cleared during startup recovery. Persistence fault tests pass, and an existing but uninspectable path now keeps its tombstone pending instead of acknowledging removal (`permission-storage-failures-045.md`). Discard no longer deletes another capture's unfinished save (`capture-controller-quiescence-046.md`); populated AVKit observation covers app-owned player/item retirement after one synthetic Movie discard. Actual in-flight UI/cache/device cancellation remains unaccepted. No deletion can recall Photos or older backups. |
| BIL-01/02/03/05/06/07; FR-20 | StoreKitSubscriptions, SubscriptionController/View, JournalModel.load | Configurable monthly/yearly same-group products, StoreKit prices only, verified purchase/current entitlements/updates, user-requested restore, management link. Existing Film operations remain ungated. Four local fixture scenarios now pass after proving asynchronous fixture delivery; real billing, refund product policy and live products remain unapproved. |
| TRI-01/02/03/04/09/11; FR-21 | TrialCoordinator, Keychain adapter, JournalModel, capture receiver | Native app uses device-only Trial and durable first-save outbox. Keychain unavailable fails closed without blocking Journal browsing. No simulator bypass. Installed-app recovery tests are earlier evidence, not proof of reinstall/restore or the unresolved first-save/uninstall window. |
| QA-01/02/03/04/09/11/12/13/14/15; ARC-08/09/10/11/12 | Native test targets, package tests, validation scripts, CI preparation | Native build and initial navigation are now executable; full tests, accessibility, hardware timing/fidelity/backup, production rights, product judgment and release sign-off remain required. CI configuration is prepared, not observed green. |

## Observed Gates

- `sh Scripts/validate-local.sh > DerivedData/Native-Candidate-Validation-20261001.log 2>&1`:
  exit 0, 04:48 UTC. **88 package tests passed**: FilmDomain 13, RenderFixtures 2,
  RenderCore 9, FilmPersistence 23, NativeAdapters 18, CapturePipeline 6,
  EntitlementCore 6, FilmRuntime 11. The 122-ID/72-clause/nine-invariant coverage
  check, ZIP comparison and both generic unsigned builds passed. Retained log:
  `package-build-validation-20261001.txt`. Setup-only accessibility edits continued
  during/after these builds; this is not a final UI/build acceptance claim. No
  package, entitlement or app-model implementation changed during those executions.
- `DerivedData/Immerse-StoreKit-Journal-Integration-2.xcresult`: **6 passed, 0
  failed, 0 skipped**, iOS 26.2 (23C54), 04:51 UTC. Repeats all four StoreKit and
  two native app-model scenarios against current backend/model/render source.
  Command is the integration command below with `DerivedData/ValidationSimulator`,
  this result path and 180-second maximum. No real purchase/account operation.
- `DerivedData/Immerse-StoreKit-Journal-Integration-1.xcresult`: **6 passed, 0
  failed, 0 skipped**, iOS 26.2, 2026-10-01 04:23 UTC. Four local StoreKit tests
  cover purchase/reopen/restore/expiry, pending approval/update, failure isolation,
  and verified Apple revocation without destroying existing-Film rights. Two
  app-model integration tests exercise real synthetic-photo Development/edit/Reset,
  explicit verified source cleanup, Discard/no refund, Archive/rename/reopen,
  Delete Film and empty-Film behavior with billing unconfigured. They do not use
  a fake production entitlement or write to Photos. Later UI/style and Movie-ratio
  changes are outside this observed test run; the next candidate gate must rerun.
- `swift test --package-path Packages/FilmDomain`: 13 passed, including a clock
  adjustment preserving capture order and capacity (2026-10-01 03:59 UTC).
- `swift test --package-path Packages/FilmPersistence`: 23 passed, including a
  late-save/exact-waste confirmation race and removal/recovery of private render
  and export work (2026-10-01 04:07 UTC).
- `swift test --package-path Packages/EntitlementCore`: 6 pure policy tests passed;
  this is not a StoreKit execution result.
- Initial simulator app build: passed, with one throwing-expression compiler
  correction. Later billing compilation needed concrete default-initializer and
  isolated-deinit corrections; these were build failures, not behavioral passes.
- Generic device app build: passed before the final Work-deletion and StoreKit
  expiration corrections, without signing or installation.
- `DerivedData/Immerse-Journal-UI.xcresult`: 1 UI test passed, 0 failed, iOS 26.5
  task-owned iPhone 17 Pro simulator. The initial unsigned Keychain error alert
  was observed separately and changed to an inline Settings status; Trial still
  fails closed. Re-execution is needed for the later integrated candidate.

## Failed StoreKit Runs, Retained

Exact first execution:

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath DerivedData/Immerse -resultBundlePath DerivedData/Immerse-Native-Tests-2.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 90 CODE_SIGNING_ALLOWED=NO test
```

iOS 26.5 fixture activation failed with `SKInternalErrorDomain Code=3`, followed
by `unexpectedProduct` in the pending-approval test. Restore fell through to an
Apple Account prompt and exceeded its execution timeout. No credentials were
entered. The run was interrupted; bundle finalization also failed, so its retained
`Staging` diagnostics are the authoritative raw artifact, not a complete xcresult.
Copied stdout: `storekit-ios26.5-failure.txt`. No test was counted as passed.

Apple staff identify the related StoreKit Test problem in
[FB22237318 discussion](https://developer.apple.com/forums/thread/826971).
Inference: the matching runtime/error is an environment issue, not evidence that
the purchase code works. Added a strict fixture-product preflight to prevent
purchase/restore fallback. No signing or Apple account changes were made.

Second execution changes only simulator runtime and adds the preflight:

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=A5825795-2E74-49C8-BC64-A5CDCB27AF8B' -only-testing:ImmerseTests/StoreKitSubscriptionTests/testRealLocalPurchaseReopenRestoreAndExpirationPreserveExistingFilm -derivedDataPath DerivedData/Immerse -resultBundlePath DerivedData/Immerse-StoreKit-26.2.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 90 CODE_SIGNING_ALLOWED=NO test
```

On iOS 26.2, local products, actual test purchase, cached reads and restore passed
their assertions, but the single overall test FAILED at expiration: `active`
instead of `expired`, then new-Film permission incorrectly remained allowed.
Exact stdout: `storekit-ios26.2-expiry-failure.txt`; complete result bundle retained.
[Apple's expire API](https://developer.apple.com/documentation/storekittest/sktestsession/expiresubscription(productidentifier:))
forces expiry and disables renewal. The production adapter now checks the signed
expiration date and only honors a verified Apple grace-period expiration. The
affected assertions remained unchanged. The corrective execution also FAILED
(`active` instead of `expired`), in
`DerivedData/Immerse-StoreKit-ExpiryFix.xcresult`. Its command was the second
command above with only that result-bundle path changed. This contradicts the
hypothesis that a missing signed-date guard alone caused the failure. Firstmate
authorized bounded diagnosis after the repeat-obstacle stop; see
`storekit-expiry-diagnosis.md` for observations and counterfactuals.

The four local StoreKit scenarios passed in the six-test run above. The diagnosis
retains both failures and event-synchronized counterfactuals; assertions were not
weakened or excluded. Neither local fixtures nor compilation substitute for ARC-09
hardware offline proof. Exact successful command:

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=A5825795-2E74-49C8-BC64-A5CDCB27AF8B' -only-testing:ImmerseTests -derivedDataPath DerivedData/Immerse -resultBundlePath DerivedData/Immerse-StoreKit-Journal-Integration-1.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 90 CODE_SIGNING_ALLOWED=NO test
```

## Accessibility and Movie Corrections

`Immerse-Accessibility-1.xcresult` failed both UI tests (no skips): setup contrast,
partially unsupported Dynamic Type on Film title/Cancel/Done, and clipped Silent
capture text. Exported screenshots/descriptions are in
`DerivedData/Accessibility-1-Attachments`. Largest-type screenshot also showed
decorative Camera symbols overflowing their 36-point column. Corrected native
icon sizing, command icon labels, wrapping/header styles, accessibility-size
orientation menu, and higher-contrast adaptive accent. Audit assertions remain
unchanged. Run 2 failed compilation because adding an asset catalog made XcodeGen
assume an AppIcon existed; the project now explicitly leaves the unapproved app
icon unconfigured. It is a launch gap, not fabricated production artwork.

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -only-testing:ImmerseUITests -derivedDataPath DerivedData/Immerse -resultBundlePath DerivedData/Immerse-Accessibility-3.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 CODE_SIGNING_ALLOWED=NO test
```

Runs 1 and 2 used this command with their corresponding numbered result paths.
Run 3 **FAILED: 1 passed, 1 failed, 0 skipped**, 04:30 UTC. The largest Dynamic Type
catalog/landscape Settings test passed. Default setup still reports two contrast
issues and partially unsupported Dynamic Type around the Film title header at
`JournalFlowTests.swift:19`. This is a repeated obstacle after the targeted fix:
work stopped and was escalated under key `native-accessibility-header`, with no
assertion suppressed. PNGs, issue descriptions and attachment manifest are copied
to `accessibility-3/`; full event/video artifacts remain in the original result
bundle. Exact remaining cause is not established: the explicit primary-color,
headline header still fails, so another speculative style patch is not justified.
This is a software accessibility gap, not a request to waive QA-13.

Firstmate subsequently authorized bounded diagnosis. `accessibility-diagnosis.md`
retains each counterfactual and contradictory observation. Default setup now passes
all-category audit after explicit semantic heading color, ordinary form-label
placement and selection of the existing adaptive accent asset. Expanded scrolled
largest-type coverage found an independent picker-label sizing issue and contrast
under the navigation scroll edge. An initial label correction appeared to remove
sizing findings, but the fresh-build run contradicted that: Movie Orientation and
Silent capture again fail Dynamic Type. The new command-audit activity is observed
in that fresh run, with Load Film visible in its pre-audit tree; the audit then
revisits earlier rows. No required finding is waived. The repeated obstacle is
escalated with exact nodes and retained screenshots. Full QA-13 remains unaccepted.

Later, `qa13-measurement-049.md` and `qa13-audit-exceptions-052.md` resolved the
automated audits on the simulator: a real Movie Orientation layout defect was fixed;
the remaining Dynamic Type findings followed the Form rows and varied run to run
(which also fits the earlier Silent capture flags), so the Load-screen audits measure
text size directly instead; audited scroll positions are now deterministic, and one
exact, measured contrast exception remains. Device and assistive-technology QA-13 stays open.

The framework also reported a UIKitToolbar/UIHostingController
runtime warning on standard SwiftUI toolbar use; it is retained, not claimed fixed.
Launch arguments requesting dark appearance did not reliably produce dark output
in the first screenshot; no dark-mode acceptance is inferred from those arguments.

FR-05 inspection found the native renderer still used 16:9 dimensions and its old
test mirrored that mistake, despite the required 4:3/3:4 presentation. Changed
`NativeMovieRenderer` to the mandated ratio, retained fit/borders, and added decoded
dimension/border pixel tests for both Movie Cameras and portrait output. The initial
new regression terminated with signal 4 because its pixel probe indexed the expected
width after detecting the old smaller width; bounds are now checked before probing.
The targeted command was `swift test --package-path Packages/RenderCore --filter
NativeRenderTests/testBothMovieCamerasUsePortraitThreeByFourWithLetterboxedLandscape`.
`swift test --package-path Packages/RenderCore` then passed **9 tests, 0 failures**
at 04:28 UTC, including real decoded dimensions/border pixels, exact chronological
assembly frames and unchanged surviving decoded frames. Earlier 16:9 synthetic candidates are not migrated,
rerendered, or claimed compliant; no captain media was captured with this candidate.

`launch-readiness.md` supplies the QA-14 preparation and no-mistakes evidence handoff,
with required hardware scenarios, asset rights, Apple setup, recovery and remaining
human judgment. It is not release authorization or completed QA-14 acceptance.

## Recovery and Human Judgment

No release or real media exposure occurred. The branch, committed generated Xcode
project and package tests contain the candidate. Repository recovery drains privacy
jobs and clears derivable Work files, never sealed Staging captures. Current-app
deletion cannot remove external exports or copies in older backups. Data migration,
restore, low-storage and callback windows still need captain-directed device tests.

Remaining product judgment: DEC-01/02/03/04/05/11/12/13/14 and pending prototype
flows stay unresolved. The before-code hardware order is superseded by the
captain's implementation-first instruction; hardware acceptance is not waived.
Full v1 remains incomplete. No tracker implementation checkbox is changed.

This is a local checkpoint commit after `39894a5`, not a ready or accepted full-v1
candidate. `source.sha256` records the app/package/test/script sources at this
checkpoint. The package/build script passed and all six native unit scenarios were
rerun successfully; later setup-only changes still have failed accessibility and
need affected build/UI reruns before acceptance. `git diff --check`, traceability
coverage and the regenerated 25-entry ZIP/content comparison passed. Firstmate must
direct the next bounded diagnosis and any subsequent no-mistakes validation. No
pipeline, push, PR, physical action, real purchase or release occurred.
