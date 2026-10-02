# Pending-Backup Provenance Study: 038

**Proposed marker disproved. No shipping change or accepted protocol.** Source
base `d5c1824b8bd39d1161c4a207367c175e87ceafc5`, plus
`Probes/TrialCommitStudy/RestoreProvenanceStudy.swift` as bound by
`source-final.sha256`. The independent populated-view harness is being prepared
separately and is not input to this study. Both 036/037 production regressions
remain failed and unchanged.

## Contracts and Assumptions

The captain's PRD FR-04/05/21 and section 11 require saved-only debit, no second
Film from the same consumed device entitlement around termination, no refund,
offline operation and no server/Account. FR-08/18/21, DEC-16/17 and ADR0012 require
restored Film rights, destination entitlement independence and disclosure that
older backups can restore removed data. These are product requirements.

The stronger engineering claim under test is in
`Evidence/TrialKeychainProbe/2026-10-01-production-receipt-integration.md`,
"Correction and Ownership": missing/unreadable/malformed/mismatched readback
cannot acknowledge a write; unresolved calls stay pending before SQL projection.
Instruction 037 explicitly preserved that claim on recovery as well as older
same-iPhone empty-Film rights. Neither a test name nor this model adds a captain
requirement. The original receipt study grants authoritative same-item reads;
the later conflicting-readback adapter can instead return valid data unequal to
its actual item. That distinction is material, not resolved by the OSStatus name.

The test model assumes atomic complete snapshots, serialized transitions, usable
pending media and source-device receipt survival. These are deliberately stronger
than proved native capabilities. Actual receipt contents and the timeline are
oracles used to judge the study, never inputs to the proposed resolver. A restore
is an action in the test history, not a flag the recovered app can observe.

## Smallest Proposed Mechanism

Add a per-pending pre-write value: `requiresMatchingReceipt` for an unused origin
device, or `existingFilmGrant` for a save begun with an already-consumed/restored
grant. Store it before the receipt attempt, in the backup-included pending journal.
Exact record matching covers Film/capture/date; foreign destination grants remain
independent. Legacy missing markers are conservatively modeled as requiring a
match. This is an isolated hypothesis, **not** a production field or migration.

It distinguishes the original empty-backup R from fresh mismatch M, and E's exact
readback recovers. But a backup can itself contain `requiresMatchingReceipt`.

## Decisive Histories

`History` executes guarded prepare/snapshot/restore/publish transitions for R,
M, R2, R3, R4 and M5. Restore copies only the app image; it never rewrites the
actual receipt. Each legitimate consumed history asserts exactly one receipt
write; preparation requires no pending or projected capture. This checks
reachability rather than only placing prose labels on hand-selected endpoints.

| Witness | Executed/constructed history | Result |
| --- | --- | --- |
| R2 versus M | Snapshot empty F; prepare B; snapshot pending B before write; restore empty F while still unused; save A once in F; restore pending B. Compare fresh B whose update stores B but returns A. | Identical recovery inputs including marker, different required outcomes. Strict matching blocks restored B. |
| R3 versus M | Prepare B; unresolved attempt actually has no effect; snapshot pending; restore older empty F, save A once, restore pending B. | Same ambiguity survives the unresolved-write backup window. |
| R4 versus M4 | Snapshot pending B in F; delete current zero-save F; save C in new G using still-unused eligibility; restore pending F. Compare fresh B with conflicting readback C. | Different-Film receipt exception cannot distinguish legitimate restore from conflicting readback. |
| Legacy R versus M | Erase proposed field to represent old journals in the equal-input pair. | Default-to-match blocks rights; default-to-grant admits the mismatch. No inference from missing field solves both. |
| M5 versus R2 | B's write has no effect, but injected successful read returns consumed A; actual record remains unused. | Same visible inputs. An unconditional valid-consumed fallback would project without actual consumption under this stronger arbitrary-read-corruption model. |

M5 is **not observed Apple behavior**. It demonstrates why simply blessing the
existing consumed bypass is not a proof under an arbitrary fabricated-success
fault model. The original 036/037 package witnesses had an actually consumed B,
not M5's unused record; preserve that difference.

The marker candidate fails five of the 22 specified model rows. Five equal-input
pairs demonstrate the ambiguity. Other rows construct exact receipt recovery
after preparation/unknown-applied/readable-before-SQL, unused same-device pending
publication, used/unused foreign destinations, historical no-capture markers,
unavailable/future/malformed reads, deletion and paid-Film isolation. Those rows
are bounded logical compatibility checks, not newly executed native scenarios.
Repeated already-projected recovery is a no-op; wait preserves pending media and
the model never resets consumption. They do not prove physical durability.

For the same visible input, any resolver based only on those fields must choose
the same outcome. It cannot both project R2 under restored rights and retain M
under the strict mismatch rule. This is a scoped information ambiguity for this
fault/snapshot model, not a claim that all conceivable protocols are impossible.
Adding another copied phase/attempt marker alone does not provide an independent
observation. No trusted restore detector or new external ledger was assumed.

## Execution and Limits

```sh
swift Probes/TrialCommitStudy/RestoreProvenanceStudy.swift
```

Exit **0** means the counterexample consistency assertions held. It is not a
passing Trial acceptance gate: `candidateSatisfiesBothContracts` is **false**.
Final output is `study-final.json`, with empty `study-final.stderr`; source/output
SHA are in `source-final.sha256`. macOS 26.6.2/Swift 6.3.2, October 1, 2026;
`environment.txt` records the environment. `construction-1.json` and its retained
source were an endpoint-construction draft. `study.json`/`source.sha256` preceded
the extra M5 trust-boundary challenge; only final output is the delivered model.

No native API, simulator, receipt file, app store, migration, network or device
operation was executed by this script. It emits JSON to stdout only. The hash is
an opaque reference to 037's native synthetic source, not a fresh decode result.
037's SQLite/native-media R/M/E witnesses remain the separate production evidence.
No hosted/process-exit rerun could resolve the missing information; none is
claimed. Native Security -34018 and the physical deferral remain unchanged.

## Decision and Consequences

**Key: `receipt-read-contract-038`.** Do not implement the disproved marker.
Firstmate must reconcile the engineering read/fault contract before dependent
shipping edits. Concrete alternatives:

1. **Preserve strict mismatch rejection under arbitrary valid-but-false reads.**
   With current observations this holds affected legitimate pending-backup and
   legacy Films unresolved. Accepting that outcome narrows restored/recovery
   rights; rejecting it requires additional independent trustworthy information,
   not the proposed backed-up marker. No such mechanism is demonstrated here.
2. **Use an authoritative successful same-item read as the platform contract,
   and distinguish recovery under an existing consumed Film grant from
   acknowledgment of the attempted capture receipt.** Keep exact readback for
   publication from unused eligibility, fail closed on unavailable/malformed/
   future state, keep sources pending on unresolved writes, and never reset the
   device marker. A recovered valid consumed record may then support existing
   Film rights even if its capture differs. This explicitly narrows the stronger
   engineering promise that every such recovery must match the attempted receipt;
   it cannot claim tolerance of M5's fabricated successful read. It does not
   authorize changing the captain's saved-only/no-second-Trial rule.

Recommendation: review option 2 against the original v1 intent and the already
conditional native adapter contract rather than add nonworking persistent state
or silently revoke restored Films. This is a recommendation for a **scoped
specification decision**, not acceptance of the present bypass. State exactly
which read outcomes are authoritative and which fault cases remain unsupported;
require affected production/adapter/restore tests and later hardware checks.
If arbitrary valid-but-false read resilience is a required product guarantee,
option 2 must be declined and the unresolved trustworthy-observation requirement
escalated. Do not relabel existing failed tests as passed without that decision.

Future implementation impact includes `TrialCoordinator` launch/refresh/start/
commit/recovery, `DeviceTrialStore`, native Journal/CaptureController callers,
legacy outboxes and affected harnesses. A marker approach would additionally
require a pending schema/version, missing-field migration and rollback policy,
backup/restore behavior and privacy cleanup. None was added. Captures must not be
discarded or eligibility reset to resolve legacy ambiguity; any extra device-only
state would be a separate security/storage change. Code rollback cannot undo
consumption, deletion or external exports.

TRI-03/04/09/11, ARC-05/11/12, CAP-08, QA-12/15 and FR-04/21 remain incomplete.
Independent native-view preparation continues under 036, not this study's gate.
No shipping correction, full-v1/CI-ready assertion, no-mistakes run, release or
merge is claimed. Original accessibility failures remain unwaived.
