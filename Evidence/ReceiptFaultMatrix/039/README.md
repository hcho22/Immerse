# Receipt Read Scope Reconciliation: 039

## Authority and Outcome

Instruction 039 explicitly corrected Firstmate's engineering assertion, not the
captain's product requirements: direct publication from unused eligibility still
requires exact post-write readback; recovery can use an authoritative successful,
correctly scoped same-item read of a valid existing consumed record together with
the persisted Film grant. That recovery does not claim acknowledgment of the
pending capture's write. Saved-only debit, no second new Trial Film/no refund,
restored-Film rights and independent destination entitlement are unchanged.

**No shipping source change was necessary or made.** No marker, receipt version,
schema, identity, access group, entitlement, accessibility, synchronization,
signing or migration changed. Only current tests, the nonshipping hosted target
and evidence/documentation changed. This is a source-bound software checkpoint,
not full-v1, CI-ready, physical acceptance or release readiness.

The 036 test
`testValidMismatchedReadbackRemainsUnacknowledgedDuringPendingRecovery` and 037
`testSamePendingOperationCounterfactualAndSameFilmRestoreCompatibility` remain
historical failures of the stronger assertion. Their reports/logs/histories are
untouched. Exact before-sources are also retained here as `*-before.swift.txt`.
The current tests have new names and explicit different scopes. Nothing turns
those failed observations green or waives a captain criterion. The 038 marker
counterexamples, including fabricated-read M/M5, remain unsupported-model evidence;
arbitrary fabricated but valid successful read tolerance is not an added guarantee.

## Reviewed Boundary

`SystemTrialKeychainCalls` queries generic-password class with service
`com.immerse.device-trial.v1`, account `device-trial`, synchronizable false,
one match and returned data. It casts the result to `Data`, not arbitrary JSON or
a success flag. The store rejects successful reads without data, unavailable
statuses, unsupported versions, unpaired consumption fields, invalid UUID/date
decoding and empty/nonconsumed capture receipts. Versionless and v2 records are
supported. After an attempted update, equality checks the whole expected record,
including device/Film/capture/date, before direct success. No reset is introduced.

Apple documents query-matching item return and data return types. These support
the ordinary same-item read contract, not power-loss ordering, stale-peer,
reinstall/backup retention or linearizable hardware durability.
[SecItemCopyMatching](https://developer.apple.com/documentation/security/secitemcopymatching(_:_:)),
[Item Return Result Keys](https://developer.apple.com/documentation/security/item-return-result-keys).

Source review found no extra access-group or signing-entitlement configuration in
the app, adapter or compile probe. Actual signed identity/capability is not proved
by this unsigned run. Default app construction uses the default store/service;
explicit service overrides in these tests are injected boundaries, not Security.
No actual Security call or retry of 035's -34018 capability was performed.

`TrialCoordinator` verifies the pending Film's Camera/grant, sequence, native decode
and SHA before receipt/projection. A same-origin unused item invokes exact consume;
a valid existing consumed item or foreign grant preserves accepted existing-Film
rights. SQL receipts validate identity/kind/hash for once-only replay. Its FIFO
lease spans awaits and Delete, and legacy outbox handling remains independent of
paid-Film capture. `JournalModel` launch/recover/refresh and `CaptureController`
open/quiesce use this owner; no alternate shipping resolver was found. This review
does not prove backend quiescence or physical interruption behavior.

## Candidate and Execution

Base `6118246430a0397caa85b7a5192d0149bd77be52` plus the two current test changes
and additive hosted-target/runner changes committed with this report. Concurrent
uncommitted PopulatedJournalHarness work was not an input to these tests.
`package-source.sha256`, hosted `source.sha256` and `app-files.sha256` bind inputs
and native artifact; `base-revision.txt`, `host.txt`, `xcode.txt`, native device
JSON and result summaries bind the environment. Observed October 1, 2026 at
13:50-13:52 PDT: macOS 26.6.2/25G83, Xcode 26.5/17F42, x86_64; hosted iPhone 17 Pro
iOS 26.5/23F77 simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60` only.

| Executed gate | Observed outcome | Evidence |
| --- | --- | --- |
| Affected runtime selection below | 23 methods passed, zero failures, 11.391s | `runtime-1.log`, `package-histories/` |
| DeviceTrialStoreTests | Six methods passed, zero failures | `adapter-1.log` |
| ProductionProcessExitTests | One method passed, nine actual child exits 77 at prepared/receiptResolved/projected across photo/Super 8/16mm | `process-1.log` |
| Hosted ReceiptScopeTests | Seven methods passed, zero failures/skips | `receipt-scope-039-1/summary.json`, `tests.json`, `execution.log` |

```sh
swift test --package-path Packages/FilmRuntime --filter 'ReceiptFaultMatrixTests|ReceiptCompatibilityTests|ProductionTrialReceiptTests|TrialIntegrationTests|CaptureRecoveryIntegrationTests'
swift test --package-path Packages/EntitlementCore --filter DeviceTrialStoreTests
swift test --package-path Probes/TrialCommitStudy --filter ProductionProcessExitTests
xcodegen generate --spec Probes/ExportPrivacyHarness/project.yml
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ExportPrivacyHarness/run-simulator.sh receipt-scope UNIQUE-LABEL
```

The hosted result bundle is retained locally at
`DerivedData/Export036-receipt-scope-039-1.xcresult`; exported summaries are committed.
The readable boot log omits trailing blank lines; `boot.log.raw.gz` retains the
exact original output.
The simulator began Shutdown; the runner restored preferences and shut it down.
The executed runner is retained as `run-simulator-executed.sh.txt`. After execution,
only its collection logic was narrowed to avoid copying unrelated older export,
Development and FIFO histories in receipt mode. Those redundant copies remain
locally in `DerivedData/Receipt039-unrelated-copied-histories`, not counted as new
results. `sh -n` passes for the final runner; this collection-only refinement was
not a second native execution. Package process-exit tests intentionally remove
their own synthetic temporary directories; their retained log contains all nine
exit/recovery/hash outcomes, not a claim of retained raw filesystem histories.

## Expected and Observed Cases

| Case | Expected and observed under current scope | Location |
| --- | --- | --- |
| Direct capture/Film/device/date mismatches | Each rejected with -25291; zero SQL captures and pending media. After explicitly restoring actual returned data, reopen twice yields one sealed capture, no pending, one total update/no add. | ReceiptFaultMatrixTests, 15 package/native matrix histories including four direct cases |
| Missing/future/partial data | Decode error blocks initial/recovery/new Trial; readable actual data recovers once without another update. | ReceiptFaultMatrixTests, adapter tests |
| Missing/foreign/conflicting pending media or metadata | Exact typed errors; no projection or reset, source retained. | Seven pending matrix cases |
| Authoritative existing consumed grant | All eight same/different Film/capture/date combinations recover once with actual == returned bytes, unchanged receipt and zero writes. | ReceiptCompatibilityTests, before/after JSON |
| Historical/versionless/foreign grant | No-capture v2, versionless, used foreign and unused foreign recover; destination receipt unchanged. These four plus eight combinations are declared valid item-state permutations, not twelve fabricated-read successes or twelve real restores. | `receipt-compatibility/` and package equivalent |
| Same-Film older empty backup | Original A consumes; restored empty Film saves different B once while A's receipt remains; retry/reconcile does not debit again. | ReceiptCompatibilityTests |
| Pending backup before/after receipt | Exact prepared and receiptResolved stops copied; repeated new-owner recovery projects one verified sealed source, one total update. | ReceiptCompatibilityTests |
| No effect/no successful observation; unknown applied/unreadable | Unresolved state preserves pending media/capacity. Exact readable observation resolves applied/no-effect branches without reset. | DeviceTrialStoreTests, ProductionTrialReceiptTests, TrialIntegrationTests |
| Legacy failure versus paid work | Unresolved legacy consumption remains; independent subscription Film saves. | ProductionTrialReceiptTests |
| SQL replay, delete and stale callback | Kind/hash conflicts rejected; exact FIFO 0/1/2/0, deletion wins and consumption unchanged. Actual process exits recover once without refund after synthetic app-storage loss. | Runtime selection, package FIFO snapshots, process log |

Package snapshots retain four compatibility roots, 15 matrix roots and one FIFO
root. Hosted snapshots retain four compatibility roots and 15 matrix roots. Each
contains real private synthetic SQLite/media, actual/returned receipt JSON and
state/count records; snapshots are not substitutes for the assertions/logs.

## Risk, Recovery and Remaining Judgment

Persistent Trial/media behavior remains high risk despite this test-only change.
Unknown/invalid authoritative state keeps pending data; safe observed recovery is
one sealed hash-verified source with correct capacity, cleared pending state and
unchanged consumed identity. No entitlement refund, forced cleanup or grant revoke.
Code rollback cannot undo consumption, removed media, independent exports or an
older backup. All destructive operations here affect synthetic fixture directories.

TRI-11, ARC-08/10/11/12, QA-15, physical capture/Photos/Keychain/backup and power-loss
checks remain untested/deferred. Full native capture-backend race coverage is still
preparable work. Original QA-13 four-case failures/seven findings are unchanged;
no further analyzer variant or waiver is implied. Product render/assets/rights,
pricing and launch decisions remain open. No publication, PR, merge or no-mistakes
run occurred. This report is repository-owned handoff to that eventual selected
owner; evidence linkage is reviewed, not machine-enforced scenario import.
