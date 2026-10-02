# Final Software Candidate Gate 050

Candidate: `71391e483a80f3df38d995f5320c8a77c17cef61` on `fm/immerse-v1-implementation`.
App sources last changed at `bd9594a`; `71391e4` changes only the line-16 assertion in `JournalFlowTests`.
The gate started at `fd645f8` with a clean tree (`final-candidate-050/head.txt`, `status.txt`).
Its package, probe, requirement-map, ZIP, unsigned-build and populated-harness stages ran on that source, which is identical to the candidate except for the one UI test line.
The line-16 change was committed while the harness stage ran, so the UI and iOS 26.2 hosted stages compiled the candidate itself; the shifted audit-helper line number (129) in their results confirms it.
Environment: macOS 26.6.2 (25G83), Xcode 26.5, Swift 6.3.2; owned iPhone 17 Pro simulators on iOS 26.5 (23F77) `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60` and iOS 26.2 (23C54) `A5825795-2E74-49C8-BC64-A5CDCB27AF8B`.

This is a software gate on simulators and macOS.
It is not physical capture, PhotoKit, Keychain, StoreKit sandbox, backup/restore, iPhone 11 timing, assistive-technology or release acceptance; those remain in `manual-validation.md`.

## Commands

```sh
IMMERSE_WORKFLOW_SIMULATOR_UDID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 IMMERSE_SIMULATOR_UDID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Scripts/validate-local.sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
  -destination 'platform=iOS Simulator,id=A5825795-2E74-49C8-BC64-A5CDCB27AF8B' \
  -derivedDataPath DerivedData/ValidationSimulator -resultBundlePath DerivedData/StoreKit-final-20261002T050640Z.xcresult \
  -only-testing:ImmerseTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 CODE_SIGNING_ALLOWED=NO test
```

The validation script stops after a failing UI stage, so its StoreKit stage was run separately with the same command it uses.

## Outcomes

| Stage | Outcome |
| --- | --- |
| Requirement map | 122 intake IDs, 72 clauses, 9 invariants. |
| Package tests | All passed: FilmDomain 13, MediaCatalog 4, RenderFixtures 2, RenderCore 11, FilmPersistence 25, NativeAdapters 24, CapturePipeline 6, EntitlementCore 12, FilmRuntime 43 (140). |
| Study and process-exit probes | TrialCommitStudy 17 and DevelopmentProcessExit 3 passed; AssetReviewGenerator built. |
| Documents ZIP | 25 entries, content comparison passed. |
| Unsigned app builds | Generic simulator and generic device builds passed. |
| Populated harness (`Populated-20261002T045259Z.xcresult`) | 12 of 12 passed. |
| Production UI (`Validation-20261002T050114Z.xcresult`) | 4 tests: the Movie Orientation scaling and declined-Camera tests passed; both corrected capacity checks passed; the two original audit tests failed only on retained QA-13 findings (Dynamic Type on Movie Orientation, Portrait and Landscape; two 16mm contrast findings). Script exit 65 from this stage. |
| iOS 26.2 hosted (`StoreKit-final-20261002T050640Z.xcresult`) | 16 of 16 passed: 6 CaptureController, 6 Journal and 4 local StoreKit tests. |

QA-13 remains failed, by Firstmate's decision, with the evidence in `qa13-measurement-049.md`.
CI configuration is unchanged and will report the same UI-stage failure; no CI run has been observed.

| Artifact | Hash |
| --- | --- |
| `Validation-20261002T050114Z.xcresult` | `342063dc04f5a50bc487324146de2be1d815fb04abfb6fbfa8bc2933396816ce` |
| `Populated-20261002T045259Z.xcresult` | `2bda07245b78d46bda39820b8e3e66de0d26df5ea04f7a668f8e2f373c72f29a` |
| `StoreKit-final-20261002T050640Z.xcresult` | `02765e2a4d4f3da7c8343653392ab7cf2d0505842019c6ccc39c4c2ac5ee9699` |

Hashes are the SHA-256 of sorted per-file SHA-256 lines inside each bundle.
