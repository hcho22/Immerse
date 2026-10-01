# Remaining Engineering After Receipt Checkpoint 035

## Current Addendum (039)

The historical inventory below is retained. Priority 1 now has source-bound
native export/privacy evidence in `Evidence/ExportPrivacyHarness/036/README.md`;
priority 2 has the optional observer and package/hosted scenarios in
`Evidence/DevelopmentObserver/036/README.md`. Exact FIFO precedence within the
production receipt owner is proved in `Evidence/ReceiptFIFO/036/README.md`, not
capture-backend quiescence or physical interruptions. Those boundaries remain open.

Priority 4 now follows `Evidence/ReceiptFaultMatrix/039/README.md`. Instruction
039 explicitly distinguishes exact direct-update acknowledgment from existing-
grant recovery under authoritative same-item reads. Shipping behavior already
matches that scope; no marker/schema/state change was made. Current tests cover
direct identity/date mismatch rejection and repaired recovery, existing-grant
permutations, pending backups, legacy/foreign rights, paid isolation and replay.
23 runtime, six adapter, seven hosted-native and one nine-history process-exit
method pass. These injected results do not establish native Security behavior.

036/037 retain their historical failed stronger assertions and 038 the disproved
marker/arbitrary-false-read counterexamples. They are neither newly green nor
waived captain requirements. Broader fabricated-read tolerance is unsupported,
not a guarantee added by a test. Native Security remains deferred. Priority 5
populated-view coverage is independent under instruction 036. Full-v1 and original
physical/product/accessibility gaps remain open.

## Historical Inventory

Source inspection: production base `63c21ce0590bb6aefe7a36f38fb0229c9e715813`.
This inventory is preparation, not implementation or acceptance of the listed
work. The receipt harness does not change any production boundary. Firstmate
should review the dependent interface impacts below before that work begins.

## Next Native Scenarios

| Priority / existing case | Concrete implementation and verification | Boundary / remaining gap |
| --- | --- | --- |
| 1 / M16, M23, FR-08, FR-16/18, STO/PRV | Separate non-shipping hosted native tests using `FilmProcessor.export`, real repository/developed synthetic masters, `PhotoExportCoordinator` and a controlled `PhotoLibraryWriting` actor. Pause before private synthetic copy and before reply; explicitly release/fail/cancel, race Discard/Delete, inventory source/master/Work/tombstone state before and after reopening. Assert failed/no receipt never permits source cleanup; acknowledged original export permits cleanup only with verified masters; completed external copy cannot be recalled. | Existing public authorizer/writer protocols suffice. The writer must use its own test directory and label receipts as injected, never call PhotoKit or manufacture a real Photos identifier. Tests prove production response to injected outcomes, not actual PhotoKit write failure, permission prompts or daemon cancellation. No production hook needed for these bounds. |
| 2 / M11, M23, FR-06, DEV-04/06...08, ARC-06 | Add reviewed no-op-by-default Development checkpoints before `beginDevelopment`, after durable assignments, after native rendering but before asset persistence, after persisted master/clip, and before final reveal/cleanup. Non-shipping controller records/pause/releases each exact boundary. Run photo/Instant/Movie interruption/re-entry and delete races; compare assignment seed/version, existing output hashes, reveal state and no resurrection. | `DevelopmentWorker` is internal; `FilmProcessor` currently calls it without an observer. This changes production initializer/call plumbing and introduces async suspension points. Cancellation checks must follow observers before side effects; thrown/cancelled observation cannot acknowledge success or leave private jobs orphaned. Must be reviewed before implementation. A sleep or kill near rendering does not prove this case. |
| 3 / T07, M23, CAP-09, ARC-03/06 | Extend receipt race control only if exact FIFO precedence is required: observable operation kind/Film queue entry while current owner lease is held; hold save, enqueue delete then callback, confirm actual order, release, assert delete wins and callback cannot recreate staging/SQL. Add capture-backend quiescence/recovery races through actual `CaptureController` pending-save job ownership. | Public save checkpoints exist; `queuedOperationCount` is internal and count alone cannot identify which operation queued. A read-only queue observation interface or package-hosted test boundary needs review. Current 035 delete-request event is explicitly not queue entry. CaptureController boundary still requires focused design; no shipping flag or bypass is authorized. |
| 4 / T04, T08, T09 | Extend isolated scenarios to pending-file absence, conflicting identity/sequence/hash, mismatching/future/partial receipt readbacks, and legacy failure with independent paid-Film saving. Use new declared synthetic initial histories, preserve consumed records and failed fixtures, assert exact errors and no second Trial. | Current 035 covers corrupt pending media, unavailable readbacks (applied and not applied), lost reply with matching readback, and versionless outbox with retained/deleted Film. It does not cover this remaining matrix. Native receipt mutations/faults need their own scope; injected bytes are not Security corruption. |
| 5 / M01...M30, H-UX | Extend existing isolated populated-view target with real domain/repository/native renderer backing for individual Instant reveal, empty Film/last-clip placeholder, early waste confirmation/cancel, Darkroom exact Reset/reopen, explicit independent export choices, Archive/rename/Delete confirmation and stale Movie retirement. Assert semantic state plus real screenshots and file outcomes. | Preserve production view code and clearly label synthetic entry/capture/entitlement. Existing Journal tests and populated harness are not full native workflow coverage. Camera/PhotoKit/StoreKit device behavior remains a separate gate. |

## Non-Substitutable Acceptance

- Native Security in unsigned 035 simulator returned `-34018`; no native receipt
  was created and the capability test skipped. A device-capable compiled harness
  is now available, but physical signing/install/namespace/action scope remains
  deferred. Do not fix signing or reset Keychain to turn this into a pass.
- Actual power loss, uninstall/reinstall, first-unlock/lock/reboot, real media
  capture, actual Photos export, two-device Trial and backup/restore are untested.
  ARC-08 specifically needs iPhone 11/iOS 26 timing; ARC-10 native fidelity and
  ARC-11/12, TRI-11, QA-15 need their recorded hardware procedures and authority.
- The unchanged four-case accessibility matrix still has four failures/seven
  findings. Instruction 035 pauses more analyzer variants, not QA-13 or assistive
  acceptance. No finding is waived or established as a framework false positive.
- Production assets/rights, render quality/output choices, Darkroom/Instant and
  soundtrack policies, budgets/matrix, support/branding/launch judgment and live
  StoreKit configuration remain absent or undecided. DEC-02 prices remain deferred
  until the captain's milestone. Reversible defaults are not approvals.
- No CI-ready/no-mistakes result, PR, release or full-v1 completion is claimed.
  All original tracker/FR/ADR IDs and deferred v2 scope stay intact.

## Containment and Recovery

Changes proposed above remain isolated until separately reviewed. Current harness
media and consumed histories are synthetic and retained; no cleanup resets Trial.
Revert source only to recover an engineering change, not receipt consumption or
private deletion. Existing Photos copies and older backups cannot be recalled.
Every new run must bind source/artifact/runtime/configuration and retain failures;
missing hardware or unsupported phase control stays untested, not inferred.
