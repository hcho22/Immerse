# Pending Replay Follow-up

**Current conclusion:** the first review's immediate historical-count assumption
was too strong. Allowing a restored Film to finish the same unresolved, verified
operation closes the demonstrated **modeled** new-device backup distinction.
This does not fix production D3, prove receipt durability, or accept TRI-04.
No production first-save protocol, Keychain item, device or signing was changed.

Source: the containing commit, `media-workflows-source.sha256` in `Evidence/NativeApp`.
Observed 2026-10-01 06:30 PDT, Xcode 26.5 / Swift 6.3.2, macOS 26.6.2 x86_64.
`Trial-pending-replay-2.log` is retained alongside this report; seven Trial tests
passed, including the separate test that **confirms D3's invariant violation**.
The first attempt did not compile because the test referenced a private root
property; it now uses its own explicit destination URL, without changing visibility.

## Requirements, Not a New Product Rule

These are engineering interpretations of the unchanged PRD, not captain approvals:

- FR-04 acceptance prohibits debit before durable save. A pending attempt has no
  debit yet; later successful recovery can debit once. The PRD does not require
  every interrupted or retryable attempt to become a permanent rejection.
- FR-05 and story 17 require preservation of recoverable interrupted footage,
  without automatically resuming recording. Replaying already recorded bytes
  does not turn on the camera or create additional footage.
- FR-08 explicitly retains unfinished captures and includes Film data in device
  backup. The current `CapturedMediaFiles` marks staging backup-included, sorts
  operations by their original date, validates decodable media and emits recoverable
  events. `CaptureController.open` replays them before permitting new capture.
- FR-21 / DEC-16 preserve the capture rights of both empty and captured restored
  Trial Films independently of the destination entitlement. Completing a pending
  operation within that Film can use those rights, just as a subsequent capture can.
- Section 11 requires bounded capacity, idempotent retries, chronology and privacy
  precedence. FR-16/18 prohibit resurrection after **current-store** removal;
  DEC-17 separately permits an older backup to restore earlier removed content or
  Films. No external or restore-surviving deletion log is allowed.

Therefore, identical prepared backups may both restore the same **pending**
operation and commit it later after validation. One source history had already
committed its receipt; the other had not. Neither requires the destination to
invent the source's Keychain state or consume the destination entitlement. The
earlier proof's requirement of immediately restoring different saved counts was
not established by those clauses. It is withdrawn as a proof against this design.

This reasoning does **not** permit reclassifying a definitively rejected capture
as pending. A terminal rejection requires a durable abort state before reporting
completion of that rejection. An unknown receipt outcome must remain unresolved
until read/retry or a serialized privacy deletion handles it. The current native
adapter distinguishes retryable persistence failure in messages, but has no durable
abort phase in `PendingCaptureRecord`; it is not already a receipt protocol.

## Observed Executable Checks

| Check | Expected and observed | Boundary |
| --- | --- | --- |
| `swift Probes/TrialCommitStudy/PendingReplay.swift` | 35 prefix histories around preparation, rejected/acknowledged/unknown receipt outcomes, projection, abort, cleanup and deletion. Two replays produce one capture for valid pending data, none for preparing/rejected/deleted data, and never consume destination Trial. | Idealized model with atomic durable actions and serial execution, not native proof. JSON retained in `2026-10-01-pending-replay-histories.json`. |
| Identical pre/post-receipt backup images | Both recover to the same one-capture Film under restored rights; source receipt differences are irrelevant to destination Trial. | Closes this particular modeled ambiguity, not all backup failures. |
| Rejection omitted from persistent state | Valid pending bytes replay after a supposed final rejection. The model explicitly detects the forbidden saved capture. | Disconfirms a receipt design relying on only an in-memory failure flag; durable abort/recovery must be implemented and tested. |
| Current delete versus older snapshot | Current deleted Film has no replayable operation; older prepared image restores the Film and can complete its operation. | Matches the current-store/older-backup distinction, not an actual iOS backup test. |
| `testRestoredPendingPhotoAndMovieReplayOnceWithoutConsumingDestinationTrial` | Four native file cases: photo/Movie, with source injected receipt unused/consumed. Each copy restores valid staged media, commits through actual production recovery/coordinator, repeats delivery without duplicate debit, retains original date/sequence/sealed state and Movie duration/orientations. Destination can start its own Trial and it remains unused by replay. Whole-Film deletion removes source/staging. | Real ImageIO/AVFoundation decoding and SQLite/files; memory device store and closed-store directory copies, not physical backup or native Keychain. Source marker models the proposed receipt's state, not production D3's write order. |

Run the native check with:

```sh
swift test --package-path Packages/FilmRuntime --filter TrialIntegrationTests
```

No invariant is tested by searching source text. Model assertions only establish
their explicitly granted assumptions. Native tests establish the existing replay
behavior, not an unimplemented receipt protocol. There is still no software-v1-ready
claim or hardware acceptance.

## Smallest Next Implementation Study

An isolated non-shipping receipt coordinator can now be studied without changing
the product contract. It should use actual native files and SQLite, an injected
receipt-store interface, and the existing Film/capture IDs (no added device identity).
It must have one serialized authority across first save, abort and privacy removal:

1. Persist and verify the complete recovery operation, including source hash,
   original timestamp, Movie duration/orientation, Film grant and expected sequence.
   Film creation, operation metadata and media must be recoverable without an
   undeclared cache or foreign device secret. Reject mismatched/missing/corrupt media.
2. Publish consumption and an opaque receipt in one Keychain-item update only after
   the operation is recoverable. Treat the receipt as the first-save commit authority;
   projection must reconstruct capacity before any subsequent capture or Trial start.
3. Inject rejection, success-with-lost-response and read-unavailable outcomes.
   Resolve using the same operation receipt. Never equate an unknown response with
   either a refundable failure or a new capture. Prove duplicate callbacks debit once.
4. Project through repository receipts, then retire staging. Terminate at every
   write boundary, including disk full and failed projection; reopen and compare
   media hashes, capture chronology, budgets and entitlement.
5. Persist terminal abort before acknowledging a definitive rejection. Restart
   between abort and cleanup. After receipt commit, use ordinary whole-Film deletion
   for sealed media, not an abort that refunds a saved Trial. Test unknown-outcome
   deletion with in-flight writes quiesced and no stale writer resurrection.
6. Repeat closed-store backup-copy replay at each prefix, including abort/cleanup
   and prior/later deletion images. Check both source states and the destination's
   own Trial concurrently; add capacity-full and already-projected receipts.
7. Exercise both Movie budgets and privacy deletion while retry/project tasks are
   queued; retain manifests, result states and injected-fault identities. Do not
   substitute synthetic timings for the iPhone 11 requirement.

Remaining platform conditions are separate: documented receipt-write/read/unknown
OSStatus behavior, durability and ordering of file/manifest preparation relative
to Keychain, actual backup consistency, protected-data failures, Keychain retention
across reinstall, and same-device older-backup effects. The official API boundaries
in `2026-10-01-protocol-review.md` still apply. A successful native study with an
injected receipt store cannot grant undocumented platform guarantees or satisfy
TRI-11/ARC-11/ARC-12 hardware tests.

No contract change is proposed by pending recovery itself. Waiving reinstall
atomicity, consuming before recoverable save, replaying a persisted final rejection,
adding media to Keychain, relaxing deletion or adding a service would be concrete
contract changes and remain unauthorized. Receipt authority is a promising
engineering alternative requiring this implementation study, not an approved or
completed replacement based only on the model.
