# Capture Backend Quiescence Checkpoint 040

Continuation from recovered HEAD `9ce9a9417f3f20b46ec96eb4eff0302398a18a2a`.
This checkpoint covers a narrow software boundary in native capture staging and
backend privacy cancellation. It is not hardware capture, Camera permission,
Photos, Keychain, power-loss, backup/restore, accessibility or full-v1 acceptance.

## Source Change

- `CapturedMediaFiles.pendingRecords()` now treats a removed staging directory as
  an already-empty pending set. This keeps privacy cleanup/recovery idempotent
  when another app-owned deletion path has already removed the staging directory.
  An existing non-directory staging path still throws through the ordinary
  filesystem enumeration contract and is not presented as successful empty
  recovery. This evidence does not establish the broader case where inspection
  of a genuinely existing directory fails; keep that for the storage/permission
  slice if a safe temporary-directory case is feasible.
- `CapturedMediaFiles.removeCommittedFile(for:)` still rejects events outside the
  staging directory, but compares standardized parent paths instead of URL object
  equality. The previous URL equality check produced false `invalidMedia` cleanup
  failures in simulator staging paths.
- `CaptureBackendRecoveryTests` adds nonshipping hosted iOS tests using
  `AVFoundationCaptureBackend` public methods, synthetic staged media and an
  injected `CaptureSaveCommitting` actor. No camera session is started and no
  production diagnostic flag or runtime setting is added.

## Observed Behavior

| Case | Expected and observed result | Evidence |
| --- | --- | --- |
| Cancel before recovery | Staged photo, staged metadata and malformed partial movie are removed without calling the committer; backend phase is interrupted. | `CaptureBackendRecoveryTests.testPrivacyCancelBeforeRecoveryDeletesStagedFilesWithoutCommit` |
| Cancel during held recovery | A second recovery is rejected as `busy`; privacy cancellation does not return while the commit is held; after release the staged photo commits once, staged files are removed and retry recovery is empty. | `CaptureBackendRecoveryTests.testPrivacyCancelWaitsForInFlightRecoveryAndLeavesNoRetry` |
| Missing staging directory | Package-level staging recovery/removal treats an absent staging directory as empty rather than throwing during privacy cleanup. | `CapturedMediaFileTests.testMissingStagingDirectoryBehavesAsAlreadyEmptyDuringPrivacyCleanup` |
| Existing non-directory staging path | Replacing the staging directory with a regular file throws instead of returning an empty pending set after `fileExists` succeeds. This proves non-directory enumeration failure only, not a genuinely existing but uninspectable directory or a physical permission/storage-pressure result. | `CapturedMediaFileTests.testExistingUninspectableStagingPathStillThrowsInsteadOfPretendingEmpty` |
| Outside committed-file cleanup | A `.photoSaved` event outside the staging directory is rejected as `invalidMedia`; the outside file bytes remain untouched. | `CapturedMediaFileTests.testCommittedCleanupRejectsOutsideStagingFilesAndLeavesThemUntouched` |

## Executed Gates

Environment: macOS 26.6.2, Xcode 26.5, Swift 6.3.2. Hosted iOS execution used
the owned iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, iOS
26.5 / build 23F77. The simulator was observed Shutdown after the targeted run.

```sh
swift test --package-path Packages/NativeAdapters
```

Result after instruction-041 follow-up: 21 tests passed, zero failures.

```sh
xcodebuild -quiet -project Probes/ExportPrivacyHarness/ExportPrivacyHarness.xcodeproj \
  -scheme ExportPrivacyHarness \
  -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' \
  -derivedDataPath DerivedData/ExportPrivacy036 \
  -resultBundlePath DerivedData/Export036-capture-backend-040-targeted-5.xcresult \
  -only-testing:ExportPrivacyTests/CaptureBackendRecoveryTests \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 180 \
  CODE_SIGNING_ALLOWED=NO test
```

Result: two tests passed, zero failures/skips. `xcresulttool` summary extraction
reported `passedTests: 2`, `failedTests: 0`, device iPhone 17 Pro simulator iOS
26.5 / build 23F77.

```sh
swift test --package-path Packages/FilmRuntime --filter CaptureRecoveryIntegrationTests
```

Result: one test passed, zero failures.

```sh
sh Scripts/validate-local.sh
```

Result: exit 0 after the initial 040 changes and before the instruction-041
test-only additions. That run exercised the full package/build/document matrix
without duplicating after the review; the final focused NativeAdapters rerun above
covers the two additional 041 tests.

Initial attempted runs are retained in local DerivedData only: the first hosted
build failed on Swift 6 XCTest autoclosure use in the new test; later attempts
surfaced the missing-staging and URL-guard cleanup defects fixed here. Assertions
were not weakened to pass those failures.

Local hosted result bundle hashes, computed over sorted file hashes:

| Artifact | Outcome | Hash |
| --- | --- | --- |
| `DerivedData/Export036-capture-backend-040-targeted.xcresult` | build failed, initial async XCTest autoclosure errors | `8a09bb7ade3a8d05db08e92c816c4964068b4029f632b27dc94c3dd0f978331b` |
| `DerivedData/Export036-capture-backend-040-targeted-2.xcresult` | one hosted test failed: missing staging directory surfaced during cancel | `875ff43ae27c0e40949a9b223d1a5d7b6453b372c48b8e50a839f8539164494e` |
| `DerivedData/Export036-capture-backend-040-targeted-3.xcresult` | build failed: Swift type-checker limit before expression split | `03cb4387c7364711a2a0363607a0c403b0d4971951ba4d07110171ee0f3ff488` |
| `DerivedData/Export036-capture-backend-040-targeted-4.xcresult` | one hosted test failed: same-directory cleanup false `invalidMedia` | `3a4cd0fbd6185775c71c6687c9ffe4304851fdd3b66fded7978efbc8de3f18e8` |
| `DerivedData/Export036-capture-backend-040-targeted-5.xcresult` | final hosted pass, two tests passed | `d35d808ea6119ab559422c48e128620d0ce7b204c93521d70da5359d77a8eb67` |
 
Relevant source hashes after instruction-041 follow-up:

| Source | SHA-256 |
| --- | --- |
| `Packages/NativeAdapters/Sources/NativeAdapters/CapturedMediaFiles.swift` | `a2685908fc84d90f4ea33d507bc01c131a48be5633d12311cedfe1ae17183b06` |
| `Packages/NativeAdapters/Tests/NativeAdaptersTests/CapturedMediaFileTests.swift` | `923f53354f450a424e7ad9f5b4b5937b434d750dfa0cbe237ee420733bc47c38` |
| `Probes/ExportPrivacyHarness/Tests/CaptureBackendRecoveryTests.swift` | `fc9c9a5678c0026ed5c4d24ef79036506bbae6bf0f032c8ee20c7cca83772382` |
| `Probes/ExportPrivacyHarness/ExportPrivacyHarness.xcodeproj/project.pbxproj` | `c8b6eb92a9bcd1cefd13ce17ec0d8b6f9d12d8407b7b942f3f3b384315ab6219` |

## Limits

This proves bounded software behavior for synthetic staged files and an injected
committer. It does not prove real AVFoundation camera callbacks, physical device
interruptions, hardware storage pressure, actual app deletion races during a live
camera session, Keychain durability, PhotoKit writes or older-backup behavior.
The existing Trial FIFO evidence still owns receipt/delete ordering after a
capture reaches `TrialCoordinator`; this checkpoint covers the backend staging
side before and during recovery.
