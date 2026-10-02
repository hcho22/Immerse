# Receipt Recovery Conflict: 036

**Not ready for validation or full-v1 completion. A new required software check
fails.** Base `d664c970ba30876f7ec4ce58a114c7d9e756a0c5` plus the test inventories
and commit containing this report. Production source is unchanged. This matrix
uses injected memory receipts, native synthetic media and real repository/runtime
owners, never Security, a simulator/phone, signing, accounts or release actions.

## Reproduced Conflict

`ReceiptFaultMatrixTests.testValidMismatchedReadbackRemainsUnacknowledgedDuringPendingRecovery`
tests the recorded matching-readback-before-projection requirement. It does not
authorize changing restored Trial Film rights.

1. A new Trial Film prepares a native photo. The injected adapter stores the
   correct consumed v2 receipt but returns a structurally valid receipt for the
   same device/Film/date with capture ID `injected-different-capture`.
2. Initial commit correctly throws TrialKeychainError `-25291`
   (errSecNotAvailable). Repository inspection shows zero saved captures, one
   pending operation and one receipt update.
3. A new coordinator uses the same repository/adapter. The mismatched readback
   has not been resolved. `reconcile()` returns success, projects a sealed capture
   and removes the pending operation. The readback still mismatches; no second
   receipt write occurred.

Exact retained history:
`package-1-histories/52B08538-1102-41E2-AB26-57E4122B2EAF/`.
Before/after Film/count JSON and both returned and actual injected receipts
distinguish a bad readback from mutation of the underlying receipt. No second
Trial, lost media or hardware fault was observed or is claimed.

| Observation | Before reconcile | After reconcile |
| --- | --- | --- |
| Saved captures / pending | 0 / 1 | 1 sealed / 0 |
| Receipt updates / adds | 1 / 0 | 1 / 0 |
| Returned capture ID | injected-different-capture | injected-different-capture |
| Actual injected capture ID | synthetic-developed-photo.jpg | synthetic-developed-photo.jpg |
| Reconcile | Not yet called | Success, contrary to tested matching-readback requirement |

## Contract Intersection

`Packages/EntitlementCore/Sources/EntitlementCore/DeviceTrialStore.swift:104`
requires exact readback after an update. But
`Packages/FilmRuntime/Sources/FilmRuntime/TrialCoordinator.swift:165` consumes only
when the destination record is not yet consumed. A consumed record skips that
matching path and reaches receiptResolved/projection. Its line 167 comment
explicitly preserves older same-iPhone empty-Film backup rights.

`Evidence/TrialKeychainProbe/2026-10-01-production-receipt-integration.md` promises
both unresolved mismatches stay pending and older/foreign restored grants continue
independently of destination consumption. This recovery path does not establish
the former; an indiscriminate matching requirement could weaken the latter.

Recommendation: distinguish conflicting same-Film v2 capture receipts from
legitimate older/foreign/legacy restored grants, keep unresolved conflicts
recoverable, and add the compatibility matrix before changing the condition.
Firstmate must reconcile that exact fallback and dependent implementation scope.
Alternatively treating every valid consumed record as sufficient on recovery
would narrow the recorded matching-readback promise; this worker has not adopted
that interpretation. No server, new identifier, altered first-save rule, receipt
reset, entitlement revoke or signing workaround is proposed or implemented.

## Actual Gates

macOS 26.6.2, Xcode 26.5, Swift 6.3.2; package execution only.

| Gate | Outcome | Evidence |
| --- | --- | --- |
| `swift test --package-path Packages/FilmRuntime --filter ReceiptFaultMatrixTests` | **Failed**: 4 methods, 5 assertions. Three assertions reproduce the conflict. Two reflect an incorrect fixture expectation of Cocoa missing-file code 260 rather than FileHandle's observed code 4. | `package-1.log`, 12 histories, `source-1.sha256` |
| Three independent methods after fixing the Cocoa constant | **3 passed, 0 failed**, 11 new histories. The known mismatched-recovery method was deliberately not rerun and remains failed, not skipped/accepted. | `package-2-independent.log`, 11 histories, `source-2.sha256` |

Passing methods cover seven pending faults (missing media, foreign Film/capture
identity, unexpected sequence, mismatched hash, Camera or grant); missing/future/
partial readbacks blocking recovery/Trial start until readable, then once-only
projection without receipt rewrite; and conflicting committed callback kind/bytes
without another debit. Typed errors and unchanged media/consumption are asserted.
They do not accept the unexecuted remainder of T04/T08/T09 or the failing case.

```sh
swift test --package-path Packages/FilmRuntime --filter 'ReceiptFaultMatrixTests.testMissingAndConflictingPendingInputsNeverProjectOrResetEligibility|ReceiptFaultMatrixTests.testMissingFutureAndPartialReadbacksBlockRecoveryUntilReadableWithoutRewrite|ReceiptFaultMatrixTests.testCommittedCaptureIdentityRejectsConflictingCallbackWithoutAnotherDebit'
```

`source-test-1.swift.txt` reconstructs the initial test source by reversing only
the Cocoa constant correction and removal of a one-use source helper. Its SHA
matches the original source-1 inventory exactly. Recovery-test/production code
were unchanged. The first evidence-copy helper used filter_map unavailable in
system Ruby 2.6; map/compact then retained all 23 histories. Neither preparation
correction changes the failed behavior.

## Handoff and Recovery

TRI-03/04/09, ARC-05/11, CAP-08, QA-12 and FR-04 A06 / FR-21 first-save recovery
must not cite earlier green adapter/projection checks as complete coverage of this
path. Keep this failing regression visible. This is not a ready no-mistakes/CI
candidate; no shipping build or native matrix pass is claimed. Legacy-failure/
paid-Film isolation, other mismatch identities, native process exits and physical
Keychain/backup gates remain separate unfinished checks.

Current impact is test-only. The mismatch is injected, not evidence about real
Apple Security behavior. Retained media/receipts are synthetic. Preserve pending
failures; code rollback cannot undo real consumption, media deletion, exports or
older backup contents. Full-v1, original accessibility failures, asset/pricing
decisions and physical deferral remain open. No production correction, public
exposure, PR, merge or no-mistakes run occurred.
