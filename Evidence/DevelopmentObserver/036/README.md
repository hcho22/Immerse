# Development Observer Checkpoint 036

Bounded software preparation following export/privacy checkpoint
`a6000b3ef48bc37bf3d03fa5ef2d5efe4b769084`. The candidate is that base plus the
source inventories and commit containing this report, not the base alone.
No full-v1, hardware, accessibility or product acceptance is claimed.

## Contract and Impact

Instruction 036 approves an optional, default-absent observer at five existing
Development phases. [The runtime contract](../../../Packages/FilmRuntime/README.md)
and `DevelopmentStage.swift` define those phases. FilmProcessor passes the
observer to actual Development, soundtrack regeneration and Discard reassembly.
The shipping app still constructs the processor without one. Every observer
await and post-suspension cancellation check is inside an optional branch; no
observer log, file write, job, shipping fault flag or persistent configuration.
Standalone export/source cleanup does not gain a new observer.

The before-reveal/cleanup phase distinguishes Instant sequence reveal, whole-Film
reveal and source cleanup. Persisted-master/clip means repository persistence,
not physical power-loss proof. Rendering/persistence callbacks skip already stored
masters/clips. Movie assembly has no extra checkpoint. Throw/cancel propagates
through the existing job/removal owner; it does not undo prior durable effects.

Risk remains high at this shared media boundary: an enabled suspension can expose
cancellation/re-entry races. Tests use new synthetic subscription-authorized Films
and actual native rendering, decode/hash verification, SQLite/files and production
owners. No native Photos, Camera, microphone, Security, StoreKit, network or
personal media operation. The hosted target uses the existing separate export
harness app; it does not introduce a production bypass or alter receipt protocol.

## Executed Checks

macOS 26.6.2, Xcode 26.5 (`17F42`), Swift 6.3.2; source inventories beside logs.
The iOS host uses the explicitly owned iPhone 17 Pro simulator, iOS 26.5
(`23F77`), UUID `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, unsigned builds.

| Check | Observed outcome | Evidence |
| --- | --- | --- |
| Initial package compile | Failed: new test referred to nonexistent DevelopmentRun.id. Corrected to filmID plus treatmentVersion/printProcess/assignments identity. | `package-1.log` |
| First executable package run | 4/6 passed; two methods failed during fixture setup because original-decline was attempted before non-Instant completion. The repository correctly rejected it with mediaNotRevealed. Fixture order corrected, production guard unchanged. | `package-2.log` |
| Corrected boundary package run | 6 passed, 0 failed; 43 independent histories. | `package-3.log`, `package-3-source.sha256` |
| Expanded affected package run | **16 passed, 0 failed**: 7 observer, 3 existing processor, 3 export, 3 soundtrack. Observer methods cover 49 new histories. | `package-4-affected.log`, `package-4-source.sha256` |
| iOS-hosted same seven boundary tests, 19:53:40...19:56:03 UTC | **7 passed, 0 failed/skipped**, 49 new native histories; owned simulator restored/shut down. | `native-1/summary.json`, test tree, source/binary inventories and snapshots/native files. |
| Shipping app generic simulator and physical-iOS builds | Both passed unsigned; no physical execution or installation. | `app-simulator-build.log`, `app-device-build.log` (quiet success). |
| Default-absent native export/privacy regression, 19:58:21...20:00:09 UTC | **9 passed, 0 failed/skipped**, 27 new export histories. No observer installed. | `../../ExportPrivacyHarness/036/observer-default-regression/`, exact nine existing tests; older copied histories are not new executions. |

## Behavioral Coverage

`DevelopmentObserverTests.swift` is shared verbatim between package and hosted
targets. Snapshots carry Film/capture identity, exact Codable UInt64 assignments,
actual native-decoded SHA values and remaining Work files. A callback gate is
strictly test-local, records observed visits and returns normally on cancellation
so the production post-suspension check, not the gate, must stop side effects.

| Scenario | Required/observed package behavior | Boundary |
| --- | --- | --- |
| Default and enabled completion, all five Cameras | Revealed media stays usable, assignments/retained hashes unchanged, no repeat render/persist callback for existing masters/clips. | No hardware capture/quality claim. |
| Pause/release at all six concrete photo positions | No early next side effect; release completes once, exactly one render/persist, verified cleanup after explicit declined originals. | Six positions implement five phases with reveal/cleanup distinct. |
| Throw at all six positions for photo, Instant and 16mm | Exact injected error, sources retained, Work removed; same-owner retry succeeds without replaying a failed job, assignments/persisted media unchanged. | 18 histories. Before cleanup, reveal may already be durable. |
| Cancellation at six photo plus two Movie/two Instant positions | Actual owned-task cancellation observed while gate held; suspend cannot return early. Normal gate release still yields CancellationError and no next side effect. Recover/new default observer-absent owner finishes. | 10 histories; repository reopen, not process death. |
| Delete at six photo plus Movie/Instant persistence/reveal positions | Delete waits for actual cancellation/release; after acknowledgment and recovery no Film, Media/Staging/Work files; stale develop rejects filmNotFound. | 8 histories; no external copy recall or crash-during-delete claim. |
| Instant Discard while second print waits for reveal | First print privately removed without refund; second stays sealed, then reveals with identical master/assignments after re-entry. | Individual reveal/privacy behavior, not view animation. |
| Movie Discard reassembly observer throw | Old private Movie retired before failure; retained clip/assignments/capacity preserved. Same owner retries successfully, assembly duration matches surviving clip. | No active player cache or licensed audio/hardware fidelity acceptance. |

## Commands and Evidence Limits

```sh
swift test --package-path Packages/FilmRuntime --filter 'DevelopmentObserverTests|FilmProcessorTests|FilmExportTests|SoundtrackTests'
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ExportPrivacyHarness/run-simulator.sh development UNIQUE-LABEL
ruby Probes/ExportPrivacyHarness/inspect-development-evidence.rb Evidence/DevelopmentObserver/036/native-1
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/ValidationSimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'generic/platform=iOS' -derivedDataPath DerivedData/ValidationDevice CODE_SIGNING_ALLOWED=NO build
```

The hosted runner retains exact result selection, runtime, source and binary
inventories, result summary/tree and Documents/DevelopmentScenarios. Existing
ExportScenarios copied alongside are retained prior histories, not new export
executions. No altered original accessibility suite, timeout increase, permission
workaround or unrelated full-suite rerun. Missing capabilities stay untested.
The independent retained-state inspector passed all 49 histories using lossless
Ruby JSON integers, comparing cancellation snapshots, preserved assignments and
master/clip hashes, final live bytes and observed deletion with absent private
files. It does not rerun native decoding or infer hardware behavior. The native
test assertions performed decoding. Read `native-1/observations.json` for IDs and
snapshots. Readable boot text normalizes terminal trailing whitespace; exact
original bytes remain in `boot.log.raw.gz`.
Xcode also reports runtime priority-inversion warnings (user-initiated waiting
on Utility, and user-interactive waiting on Default) in five hosted methods,
including the test snapshot decode site.
The unchanged test tree and cancellation activity export retain them. All seven
tests executed and passed, but this is not warning-free or hardware performance
acceptance; no QoS workaround, budget change or suppressed diagnostic was applied.

The source change is not a gate or user feature to toggle. Enabled-to-absent
recovery is tested by replacing the processor only after cancellation has joined
its owned job. An observer that deliberately never returns can prevent a waiting
owner from finishing; there is no production installation of such an observer.
Tests use bounded entry/cancellation waits and release every reached gate.

Code rollback cannot undo media cleanup or privacy deletion, and neither can
recall existing Photos exports or older backups. Current recovery observations
concern private synthetic repositories and ordinary runtime errors/cancellation.
Exact Development process-exit UI controls, physical power loss/restore, capture
job races and active cache behavior remain separate missing evidence. Receipt
FIFO/T04/T08/T09 preparation follows this checkpoint. Native Security -34018 and
the original four accessibility failures/seven findings remain unchanged.

No tracker acceptance checkbox, original ADR or product decision is changed.
No release, publication, PR, merge or no-mistakes execution occurred. This report
is a repository-owned handoff for the selected validation owner; scenario linkage
is reviewed by that owner, not machine-enforced by Firstmate.
