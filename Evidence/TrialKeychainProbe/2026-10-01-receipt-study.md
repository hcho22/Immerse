# Native File and SQLite Receipt Study

**Not production integration or Trial acceptance.** The in-scope engineering
study was authorized after the pending-replay follow-up; it changes no product
rule. Production `FilmRuntime/TrialCoordinator` still uses D3 and its retained
crash-then-uninstall counterexample still fails the required product invariant.
No phone, real Keychain item, new identity scheme, server, signing account,
purchase, release or restore-surviving deletion log was used or changed.

Candidate: containing commit, exact source inventory
`../NativeApp/media-workflows-source.sha256`. Observed October 1, 2026,
06:45-06:47 PDT, macOS 26.6.2 x86_64, Xcode 26.5 / Swift 6.3.2.
Command: `swift test --package-path Probes/TrialCommitStudy`.
Retained result: `receipt-study/ReceiptStudy-5.log`, **11 tests, zero failures**.
Prepared CI runs the same deterministic gate, with no credentials or services.
An actual CI run has not occurred.

## Implementation

`Probes/TrialCommitStudy/Sources/TrialReceiptStudy/ReceiptCoordinator.swift`
owns one FIFO lease across all async decoding, save, abort and privacy deletion.
An actor without this lease would allow reentrant deletion during native decoding.
Complete operations include the existing Film/capture IDs, original timestamp,
source SHA-256, Camera, locked Movie orientation, per-clip duration/orientation,
expected sequence and Film access grant. Media is copied, synchronized, decoded
and hash-checked before a pending manifest can authorize receipt publication.
Both operation files and SQLite stay inside ordinary backup-included Film storage.

For the source device's first Trial capture only, one opaque receipt publishes
consumption. It contains Film/capture IDs and date, **no media**. SQLite projection
then uses the existing durable idempotent capture receipt, reconstructing capacity
before any next save/Trial start. Restored Films project under their retained rights
without publishing to the destination receipt store. Existing outbox rows are
retired only after projection. Unknown store outcomes remain pending; unavailable
reads stop reconciliation, capture and Trial start. Definitive rejection requires
a persistent abort before acknowledgment, not a volatile failure flag.

The study's ordinary-file and memory receipt stores grant atomic single-value
updates, authoritative reads and no writes continuing after return. These are
**injected interface conditions**, not observations of Security.framework.
`ReceiptCrashWorker` is a separate non-shipping process that exits with `_exit(77)`
at named boundaries, without Swift defers or error unwinding. Its ordinary receipt
file is outside its private test app directory solely to simulate store survival.

## Observations

| Requirement / scenario | Expected and observed | Limit |
| --- | --- | --- |
| TRI-04 / ARC-11 / QA-12, source storage loss | At ten save prefixes, removal of only the synthetic app directory permits replacement before a receipt and denies it after receipt commit. | Injected perfect receipt survival, not actual uninstall/Keychain proof. |
| FR-04,05,08 / invariant: debit once | Thirty prefixes: Disposable, Super 8 and 16mm, from preparing metadata through each cleanup step. Reopen/replay yields zero saves without source bytes, otherwise one decodable sealed capture with original date/kind, exact capacity and matching SHA-256. Repeated delivery adds no debit. | Exceptions injected at logical write boundaries, not every internal filesystem instruction. |
| Process termination / recovery | Thirty independent child processes exit at the same ten boundaries. Actual SQLite/WAL and files reopen without language cleanup; repeated reconciliation preserves the same once-only results and receipts. | Process exit is not power loss, OS backup, full disk or protected-data denial. |
| FR-21 / DEC-16, destination rights | Sixty directory-copy restores: every prefix with unused and already-consumed destination stores. Restore performs zero destination receipt publications; unused destination can start its own Trial. Current whole-Film deletion removes projected/staged media. | Copies are quiescent local snapshots, not iOS backup/restore. |
| Lost response / unavailable read | Both committed and uncommitted lost replies leave SQL at zero and pending media intact. Unknown reads reject reconciliation, next capture and Trial start. Authoritative read/retry projects once with unchanged capture ID. | The store supplies the specified outcomes; raw native OSStatus classification remains separate. |
| Persistent rejection / abort | Interrupt after durable abort and after media removal; reopen and restored copies retain zero captures, reject duplicate delivery, and allow zero-save replacement after whole-Film deletion. A failed abort write stays pending and can later save. Abort cannot refund a committed receipt. | Injected known-no-effect rejection must not be inferred from an arbitrary native error. |
| Projection failures | Real repository faults before durable move, after move/before debit, and after database commit/before acknowledgment keep receipt/media recoverable and never publish a second receipt. | Simulated write failures, not an actual full-volume experiment. |
| PRV / FR-18, serialized deletion | A save is suspended after receipt publication. Delete and a stale save are queued. Save finishes, deletion removes the Film/staging, and the stale save fails `filmNotFound`; consumption remains. Unknown outcome deletion also quiesces the writer, never refunds, and creates no external tombstone. | In-process scheduling plus the injected synchronous-store contract; actual native daemon failure timing untested. |
| DEC-17, old backup | After unknown-outcome whole-Film deletion, the current store has no Film; the earlier pending image alone can restore and finish it, without using destination entitlement. | Required disclosure remains; no attempt to recall older backups. |
| Media integrity and both Movie budgets | Corrupt prepared clips cannot project/consume, but can be privately deleted. A claimed duration unlike decoded media is rejected. Actual 200-second Super 8 and 165-second 16mm synthetic silent files fill capacity exactly; another capture is refused. | 160x96, 1 fps generated fixtures exercise durations only, not approved cadence/fidelity/performance. |

`RECEIPT_PREFIX`, `RECEIPT_PROCESS_EXIT` and `RECEIPT_STORAGE_LOSS` log lines bind
the histories to fault names, generated operation IDs, hashes and observed counts.
The 30 source reopen / 60 restore / 30 child-exit cases are loop cases within
eleven tests, not eleven plus 120 separately counted tests.

Earlier build attempts found missing test-source layout, throwing-expression/
internal-checksum references and a CameraID/String mismatch. Initial runtime
study `ReceiptStudy-3.log` failed on equivalent URL representations and a generic
Movie suffix rejected by AVFoundation. The queued test then waited for a boundary
never reached; that owned test process was interrupted. Canonical path comparison,
native Movie suffix and bounded entry waits corrected the study. `ReceiptStudy-4`
passed ten tests; `ReceiptStudy-5` added abrupt exits and the intermediate cleanup
boundary and passed eleven. These old failures are retained, not recast as passes.

## Public Adapter Review

Apple documents that [SecItemUpdate](https://developer.apple.com/documentation/security/secitemupdate(_:_:))
updates matching items, returns OSStatus and blocks its calling thread. A future
adapter can encode receipt and consumption in the same item value, call it off the
main thread and reread the same item, rather than exposing two separate writes.
[SecItemCopyMatching](https://developer.apple.com/documentation/security/secitemcopymatching(_:_:))
returns matching data and also blocks. **Engineering inference:** sequential calls
under one owner fit the study's normal-call sequencing. These pages do not specify
the outcome of every process/daemon interruption, a filesystem/Keychain power-loss
barrier, or an iOS backup consistency contract. The study does not prove those.

[FileHandle.synchronize](https://developer.apple.com/documentation/foundation/filehandle/synchronize())
documents flushing file data/attributes before return. The study uses it for media
and manifests. Directory-entry persistence, atomic replacement/flush boundaries,
Keychain ordering and device power-loss behavior have not been measured. Apple's
[disk-write guidance](https://developer.apple.com/documentation/xcode/reducing-disk-writes)
also distinguishes buffering/barriers and best-effort full synchronization; do not
claim that process-exit checks prove absolute power-loss durability.

The prior report retains the documented ThisDeviceOnly migration boundary and
Apple DTS's unsupported delete/reinstall-retention guarantee. Same-device older
backups, protected-data failures, two-device restore and iPhone 11 timing are still
deferred hardware checks, not resolved by this code.

## Integration Boundary

No production switch is made from the study alone. Remaining software work is to
map a native single-item adapter conservatively: success followed by matching read
can resolve the receipt; non-success/unreadable/mismatched responses cannot become
refundable failures or unused Trial. A known-no-effect terminal rejection needs
specific support or must remain pending. Test raw status/read traces with an
injected Security-call boundary without mutating system Keychain, including missing
and malformed items and interrupted update/read combinations. This is engineering
work under the existing authorization, not a new product decision request.

Before integration, the app also needs one owner for controller callbacks, launch
recovery, every Trial start and whole-Film privacy deletion; migration from D3's
already-committed outbox must not consume twice or interpret old saves as abortable.
Projection must finish before displaying usable capacity or opening capture.
Repeat persistence/runtime/controller/native integration and unsigned build gates.
Native sensor, Keychain retention, physical backups and performance remain untested.

The existing D3 violation is a **software gap**, not relabeled as missing hardware.
The study removes demonstrated logical failure histories under stated adapter
conditions; it does not prove universal platform guarantees or authorize changing
the first-save rule. No waived criterion or full-v1-ready claim follows. Current
containment is the isolated branch with no exposure. Code rollback cannot restore
private media removed by an actual accepted deletion.
