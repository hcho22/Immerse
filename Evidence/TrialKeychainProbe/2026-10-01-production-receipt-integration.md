# Production Receipt Integration

This continues `d233bb7` on `fm/immerse-v1-implementation`. The containing commit
and `receipt-integration-source.sha256` identify the candidate. It is not full-v1
acceptance. Observations below use Xcode 26.5 / Swift 6.3.2, macOS 26.6.2 x86_64,
and explicitly identified owned simulators on October 1, 2026 PDT. No real
Keychain item, phone, Apple account, signing configuration, purchase or publication
was changed. The existing first-save and restored-Film rules are unchanged.

Retained logs and result summaries named below are in `receipt-integration/`.

## Correction and Ownership

The D3 software counterexample is retained at `d233bb7`, in
`2026-10-01-software-integration.md`, `2026-10-01-protocol-review.md` and
`Trial-pending-replay-2.log`. That implementation committed SQLite capacity before
Keychain consumption; losing app storage in between reopened Trial eligibility.
The new regression asserts the corrected behavior, rather than continuing to
count an assertion of the old violation as a product pass.

`FilmRuntime/TrialCoordinator` now owns one FIFO lease across capture callbacks,
pending projection, Trial start, launch recovery and whole-Film deletion. The lease
persists across native decode awaits, not just synchronous actor execution.
`CaptureCommitJournal` records complete verified media, original capture ID/date,
Camera/access grant, expected sequence, kind/orientation/duration and SHA-256 in
backup-included staging. Files are synchronized before receipt publication.

For a current-iPhone Trial's first capture, `KeychainDeviceTrialStore` writes
consumption and the opaque capture receipt in **one existing Keychain item** and
requires matching readback before SQL projection. The item service, account,
existing device UUID, non-synchronizable flag and ThisDeviceOnly class are retained.
No media goes into Keychain. Versionless D3 records still decode; malformed,
partial and future-version values fail closed. The injected `TrialKeychainCalling`
boundary lets tests supply raw OSStatus and data without calling Security.

Every update status, including success, is followed by a same-item read. Matching
bytes resolve a lost reply. Missing, unreadable, malformed or mismatched values
cannot be acknowledged or classified as refundable failures. The production
adapter has **no known-no-effect rejection classifier**: unresolved calls leave
the operation pending. The isolated study's durable-abort branch remains a study
of a stronger interface, not a status-code assumption imported into production.
Validation failures before preparation do not publish a receipt.

SQL is an idempotent projection after the receipt's first-save commitment. A failed
projection keeps the complete pending capture; retry restores date, sealed state
and capacity once. Older or foreign-device restored Films continue under their
retained grants without replacing the destination's consumed marker. Already
committed D3 outbox rows reconcile without inventing an opaque historical capture
ID or refunding a saved Film, including when its Film was deleted before upgrade.
An unrelated failed legacy Trial obligation does not lock an existing subscription
Film's capture. New Trial eligibility still reconciles all obligations first.

The native app performs recovery before presenting the initial Journal. Refresh
reconciles only complete commit journals, never an active native writer's metadata.
Native staging replay is explicit at launch or after the backend has quiesced.
Pending saves show `Finishing save` instead of usable capacity and offer Resume
Save; early completion and Development wait. Delete Film stops capture, then the
same receipt owner quiesces processing and removes Film/staging via repository
privacy deletion. A queued stale callback cannot recreate it. Keychain unavailability
does not prevent whole-Film privacy removal or refund existing consumption.

## Behavioral Evidence

| Requirement / scenario | Observed software behavior | Evidence and limit |
| --- | --- | --- |
| TRI-03,04 / FR-04 A06 / FR-21 A06,A07 | Unresolved uncommitted write leaves SQL count zero and full nominal capacity unavailable behind pending state. Losing that app directory can permit replacement only because no receipt/save committed. Receipt committed before failed projection remains consumed after app-directory loss. | `TrialIntegrationTests`, `ProductionReceiptCoordinator-2.log` and subsequent runtime gate. Injected device-store survival, not physical uninstall. |
| ARC-05,11 / TRI-04 raw native outcomes | Six adapter tests plus six policy tests pass: eight statuses times applied/unapplied, lost add/update responses, unavailable reads, old records, missing/malformed/future records and six mismatched readbacks. No consume path initializes a missing item. | `ProductionReceiptAdapter-2.log`, 12/12 at 08:16 PDT. Security calls are injected; normal native API contract remains conditional as below. |
| FR-04,05,08 / durable once-only capacity | Actual native photo and both Movie formats replay all three repository projection failures. Nine source cases and eighteen copied destinations keep exactly one capture and zero destination writes. Both applied/unapplied lost replies block further Trial start until readback, then debit once. | `ProductionTrialReceiptTests`; source bytes are ImageIO/AVFoundation fixtures, not mock successful media. Copied directories are not iOS backups. |
| PRV / FR-18 / TRI-09 | Deletion queued after receipt commit waits for save; a following stale callback fails `filmNotFound`. Unknown saves and corrupt prepared media can be deleted without refund or projection. | Production owner concurrency/integrity tests. Current private files are removed; old backups and Photos cannot be recalled. |
| FR-21 A03,A05 / DEC-16 | Restored native-staging operations preserve original date/kind/orientation; empty and saved foreign Trial Films coexist with destination Trial. Same-device older empty Film remains usable even when the marker names a later Film. Zero-save deletion permits replacement. | Runtime native-media tests; no new restore-surviving identifier or deletion log. |
| ARC-03,11 / process death | Separate child process calls production owner and `_exit(77)` after complete preparation, after matching receipt and after SQL projection for Disposable, Super 8 and 16mm. Nine exits recover once, remain sealed, match source hashes, and retain consumption after subsequent app-storage loss. | `ProductionReceipt-Process-1.log`, one test with nine loop cases passed 08:15 PDT. Ordinary receipt file is outside disposable app storage; not Keychain, power loss, full disk or hardware. |
| CAP-08 / UX-03 / app integration | Native Journal tests verify launch pending state, Resume Save, no premature capacity/Development, original staging cleanup, off-main Security-boundary calls and whole-Film deletion with unreadable Keychain. Four unchanged local StoreKit scenarios and two earlier Journal workflows also pass. | `Receipt-Journal-1.xcresult` summary, 8 passed/0 failed/0 skipped, iPhone 17 Pro simulator iOS 26.2 (23C54), 08:16 PDT. Not real sensor/PhotoKit/Keychain or production purchases. |
| Existing-Film access / safe refresh | Eligibility refresh leaves active native writer metadata intact; explicit quiescent recovery cleans an empty abandoned operation. Existing subscription capture succeeds despite an unrelated unreadable legacy Trial obligation. | Runtime regression. No current subscription check is added to existing-Film operations. |

Exact commands (from repo root; all system Keychain writes in tests are injected):

```sh
swift test --package-path Packages/EntitlementCore
swift test --package-path Packages/FilmRuntime
swift test --package-path Probes/TrialCommitStudy
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=A5825795-2E74-49C8-BC64-A5CDCB27AF8B' -derivedDataPath DerivedData/ReceiptSimulatorTests -resultBundlePath DerivedData/Receipt-Journal-1.xcresult -only-testing:ImmerseTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 CODE_SIGNING_ALLOWED=NO test
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath DerivedData/PopulatedJournalFresh -resultBundlePath DerivedData/PopulatedJournal-Receipt-10.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
sh Scripts/validate-local.sh
```

Combined gate `Validation-receipt-integration-1.log` exited zero: **115 module
tests plus 17 study/production-exit tests**, 122 intake IDs/72 clauses/nine invariants,
matching 25-entry ZIP and both unsigned simulator/device app builds. Package/test
execution ran 08:20-08:22 PDT; the quiet build steps completed afterward. Counts:
Domain 13, MediaCatalog 4, RenderFixtures 2, RenderCore 11, Persistence 24,
NativeAdapters 18, CapturePipeline 6, EntitlementCore 12, Runtime 25; the study
package includes 12 isolated coordinator, four status and one production-exit test.
The additional cases inside looped tests are not separately counted tests.

Populated native workflow repetition `PopulatedJournal-Receipt-10.xcresult` passed
**3/3, zero failed/skipped**, 08:20 PDT, iOS 26.5 (23F77). Retained `populated-10/`
includes summaries, view trees and screenshots for photo/Instant/Movie scenarios.
Visual inspection confirms the last-clip Movie remains a two-placeholder Film
without player or export. The existing UIKitToolbar hierarchy diagnostic still
appears and is retained. This functional pass does not override the separately
failed light/dark accessibility audits. No simulator IDs were supplied to the
combined gate; native model and populated UI outcomes are separate runs above.

Source inventory verification passed before commit. The native model run preceded
the final unrelated-legacy filtering and indeterminate-progress presentation tweak;
the subsequent runtime, populated UI and unsigned build gates cover those changes.
The first production integration run retained old fake-byte/D3 assertions and
failed; they were replaced with decoded fixtures and the correct expected behavior,
not bypassed production validation. A test autoclosure initially contained an
unsupported async call; evaluating the verifier before the assertion corrected
compilation. Intermediate logs retain both failures.

## Platform Conditions and Remaining Acceptance

The earlier [API review](2026-10-01-receipt-study.md#public-adapter-review) remains
applicable. Apple documents synchronous matching-item update/read calls and their
blocking behavior. Sequential calls under the single owner are the engineering
basis for normal-call resolution. Neither injected OSStatus traces nor process
exits prove every daemon interruption's outcome, power-loss ordering across files
and Keychain, iOS backup consistency, or durable delete/reinstall retention.
ThisDeviceOnly must not be described as never backed up: it prevents migration
to a different physical device; same-device restoration has distinct semantics.

TRI-11, ARC-08/10/11/12 and QA-12/15 hardware gates remain unaccepted and deferred
to captain-directed manual testing. The pinned marker probe alone cannot validate
this production protocol. Required native capture/Photos errors and interruptions,
iPhone 11 timing, two-device fault/backup histories and actual large media remain
untested. The earlier light/dark accessibility failures remain failed, not waived.
No tracker acceptance checkbox follows from this correction.

Risk remains high: valuable private media, irreversible source removal and two
persistence systems. Containment is the isolated branch with no public exposure.
Pending media and deletion jobs support software recovery, not restoration of
intentionally removed media. An older backup may restore removed captures or Films;
there is no cross-backup removal log. Code rollback cannot undo a consumed Trial or
restore deleted sources. Production render/asset rights, prices, support/launch
choices and hardware judgment remain with their existing owners. The no-mistakes
handoff is `../NativeApp/launch-readiness.md`; report linkage is owner-reviewed,
not a machine-enforced acceptance import. No no-mistakes run or PR has started.
