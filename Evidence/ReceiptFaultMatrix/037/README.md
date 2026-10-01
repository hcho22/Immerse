# Receipt Recovery Compatibility: 037

**Dependent production correction blocked by an established ambiguity. Not a
green candidate, full-v1 completion, hardware result or release authorization.**
Base `89daf3a63b79e001c05169c4b668df42916d3d7b` plus the test source inventory in
this directory. Production code and the original 036 regression are unchanged.
Instruction 037 preserves both exact-readback recovery and restored-Film rights;
it requires a report before a new receipt protocol or persisted state is added.

## Diagnosis and Counterfactual

The initiating input is an injected, structurally valid conflicting readback
after the correct receipt update. The adapter rejects that first save with
`errSecNotAvailable` (-25291). On reopen, `TrialCoordinator.project` sees a consumed
marker, skips `consume`, reaches `receiptResolved`, saves one sealed capture and
removes pending media. This is the masking condition, distinct from the initial
readback fault and the visible saved/pending transition.

The new `ReceiptCompatibilityTests` prepares three histories with real native
synthetic photo bytes and production repository/owner code:

| History | Initial state and stimulus | Required recovery | Observed |
| --- | --- | --- | --- |
| R: legitimate restore | Copy empty Film F; save capture A on the original; retain consumed receipt A; reopen empty copy on the same device; prepare new capture B, stop at prepared checkpoint | Keep existing Film rights, project B without replacing receipt A | Once-only sealed B, zero additional receipt writes, no pending |
| M: mismatched readback | Same empty F; first save B writes receipt B but the injected adapter returns A; initial save rejects with -25291 | Conflict remains pending until resolved | **Incorrectly projects B**, removes pending, keeps returning A |
| E: exact control | Exact filesystem copy of M's rejected pending state and the same actual receipt B; expose B rather than A on read | Project B once, no second debit | Once-only sealed B, zero additional receipt writes, no pending |

R and M have byte-identical canonical recovery observations before reconcile:
Film, origin grant, complete pending operation (including date, sequence and
hash), decoded pending media hash, absent SQL capture receipt, and returned
receipt. In `counterfactual-2-history/`, both `RestoredEmptyBackup-before-observed.json`
and `RejectedReadback-before-observed.json` hash to:
`87ef2dcb0c8b7d5b2d5a69893a4338c7871a5b8ee1015118b4f7b0a32b753f93`.
They require different outcomes under the two accepted contracts.

Actual injected receipt bytes differ between R and M, but those are test-only
adapter internals, unavailable to production recovery. M's actual B and returned
A are both retained before/after. E changes only the returned receipt relative
to M's recovery-visible inputs, not its Film, pending operation or media. Test
adapter counters do not participate in the production protocol.

Disconfirmation sought: exact-readback recovery might fail, the conflicting
override might disappear on reopen, or an existing SQL receipt might explain
projection. None occurred. E recovered, A remained the returned value throughout
M, and all three branches had no SQL capture receipt before recovery. R also
disconfirms the proposed simple same-device/same-Film capture-ID tightening: it
would reject a legitimate restored empty Film.

The first run used fixed synthetic capture dates before Film creation; its source,
log and history remain retained. The second uses ordered dates after `loadedAt`
and additionally retains the untouched `PendingBeforeRecovery` SQLite/media tree.
It produces the same three failed M assertions. No clock, date or UUID ordering
guarantee is inferred. These are synthetic filesystem snapshots, not iOS backups
or evidence that Apple Security actually returns this fault.

## Compatibility Inventory

| Case | Evidence and scope |
| --- | --- |
| Same device/Film, exact capture/date receipt | E above passes repeated recovery, sealed source decodes/hash matches; old projection/lost-response tests also pass |
| Same device/Film, differing capture only | Original 036 regression remains failed; original evidence is unchanged |
| Same device/Film, differing capture and earlier date | R/M equal-input experiment fails the conflict criterion while preserving R's rights |
| Date-only or device-only mismatch | Six adapter tests pass, including rejection on initial update/readback; full coordinator recovery matrix is **not** claimed |
| Older same-device empty Film, different consumed Film | Existing production test passes without replacing consumption |
| Foreign restored pending/empty/captured Films, used and unused destination | Existing integration/projection tests pass with independent destination entitlement and once-only replay |
| Versionless historical consumed marker, legacy committed outbox, deleted Film | Adapter/integration checks pass without reset; legacy outbox does not invent a capture ID |
| V2 consumed marker with nil capture ID | Existing legacy-outbox path is exercised; exhaustive same-Film empty-backup permutations remain untested |
| Missing/future/partial readback, repaired exact readback, invalid pending input | 036 source-bound independent methods remain applicable and unchanged; not rerun or relabeled as new 037 observations |
| Failed legacy outbox with independent paid Film | Existing production integration test passes; paid save does not wait for unrelated Trial resolution |
| Committed SQL receipt replay, source validation, FIFO delete/stale callback | Existing affected tests pass; deletion still quiesces and does not refund/recreate |

`ProductionTrialReceiptTests` (7), `TrialIntegrationTests` (8) and
`CaptureRecoveryIntegrationTests` (1) passed: **16 methods, zero failures**.
`DeviceTrialStoreTests`: **6 methods, zero failures**. These are preservation
checks, not a fix or a green full suite. Some older tests delete their own
synthetic fixtures; their logs are retained. The FIFO test retains a separate
synthetic history in `compatibility-fifo-history/`.

## Affected Surface and History

- `TrialCoordinator.project` is reached from first/retried commit, `state`,
  `start`, `reconcile` and explicit native-staging recovery. Its consumed fallback
  appeared in `df5f3b1ba63bd973f5904f8403708eaede88f27d` with the explicit older
  same-iPhone empty-backup rationale. That rationale is real compatibility, not
  dead code. The FIFO owner and existing SQL-receipt shortcut are separate.
- `DeviceTrialStore.consume` compares the full record after update; already-
  consumed calls check Film/capture identity, not the date. Calling it blindly
  for every consumed marker would reject R and some historical/foreign grants.
- `PendingCaptureCommit` stores capture/Film/Camera/access/sequence/kind/date/hash,
  but not whether the first save began under unused eligibility or an already-
  consumed restored grant. Reopening loses that earlier observation.
- `JournalModel` performs launch, refresh and user recovery; `CaptureController`
  quiesces pending saves and reconciles on open. Both depend on this owner.
  Hosted receipt harnesses and `TrialCommitStudy` process-exit tests depend on it
  too. A protocol correction needs affected coordinator, adapter, native recovery
  and abrupt-exit checks; no unrelated accessibility variants are warranted.

## Exact Gates and Binding

macOS 26.6.2 (25G83), Xcode 26.5 (17F42), Swift 6.3.2, x86_64; local execution
2026-10-01. `environment.txt`, `base-revision.txt`, `source-counterfactual.sha256`
and `source-counterfactual-2.sha256` bind the runs. The first source is retained as
`source-counterfactual-1.swift.txt`; all existing production/test sources listed
in the second inventory were unchanged during preservation checks.

```sh
swift test --package-path Packages/FilmRuntime --filter ReceiptCompatibilityTests
swift test --package-path Packages/FilmRuntime --filter 'ProductionTrialReceiptTests|TrialIntegrationTests|CaptureRecoveryIntegrationTests'
swift test --package-path Packages/EntitlementCore --filter DeviceTrialStoreTests
```

First command: **failed**, one method/three assertions, in both `counterfactual.log`
and `counterfactual-2.log`. The other commands pass in `compatibility-existing.log`
and `adapter.log`. The Swift Testing trailer reporting zero tests is not the
XCTest result. No hosted-native recovery rerun or broader app build is claimed:
there is no production correction to validate yet, and a simulator cannot add
the missing persisted distinction. Security, physical devices, signing, real
Photos, StoreKit and external services were not used.

## Required Boundary Decision

**Key: `receipt-restore-provenance-037`.** An identity-only correction using the
current persisted inputs cannot distinguish the two demonstrated histories.
Treating all consumed records as acknowledgment preserves the observed bug;
rejecting all differing same-Film receipts rejects the demonstrated restore.
Special-casing a timestamp difference would not supply trustworthy provenance
and would leave other valid conflicting readbacks acknowledged.

Recommendation: authorize a bounded protocol/design study for a durable
pre-write distinction between a save requiring matching receipt acknowledgment
and a save using an already-existing restored Film grant. Before implementation,
the design must explicitly cover legacy pending journals and backups taken during
unresolved saves, not just the new empty-backup example. Adding that distinction
is new persisted protocol state, outside instruction 037's existing-fields-only
correction boundary. This is a recommendation for investigation, **not** a proven
solution or permission to add a marker. Alternatively narrowing one of the two
promises is a product/architecture decision, not an implementation workaround;
this worker does not recommend or adopt such a narrowing.

No dependent production edit, version/identity change, migration, entitlement
revoke or receipt reset was made. Preserve both failed regressions and all
synthetic histories. TRI-03/04/09, ARC-05/11/12, CAP-08, QA-12/15 and FR-04/21
remain incomplete. Independent native view preparation may continue under 036;
physical operations and further accessibility variants remain deferred. A code
revert cannot undo real consumption, deletion, exports or older backup contents.
No no-mistakes run, PR, merge, CI-ready assertion or public exposure occurred.
