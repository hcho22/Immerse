# Export/Privacy Checkpoint 036

**Bounded first export/privacy checkpoint; not full-v1 readiness.** Base
`0cd6344e0c1b73e0d9116810722c6c9e44fc055e`, plus source inventories and the commit
containing this report. The base alone is not the tested candidate. Production
packages/app, receipt 035 sources/evidence and original accessibility tests are
unchanged. Their physical/product gaps and four original failures/seven findings
remain open. Instruction 036 authorizes this existing-protocol checkpoint first;
the approved subsequent Development observer work is not delivered by this target.

## Surface and Containment

[ExportPrivacyHarness](../../../Probes/ExportPrivacyHarness/README.md) is a separate
non-shipping app, bundle `com.immerse.validation.ExportPrivacyHarness036`. It uses
real production FilmProcessor, PhotoExportCoordinator, SQLite/repository, native
rendering, decoded media verification and deletion/reassembly paths. Only the
authorizer and external writer are injected through already-public protocols.
No production hook, fault setting, altered entitlement or success rule.

Each independently identified synthetic history has its own UUID and manifest
under this app's Documents/ExportScenarios. App is the private repository;
ExternalCopies represents already-completed external output using test-only
copies and `injected-private-export036:` receipts, never real Photos identifiers.
Fixtures/Evidence retain synthetic inputs and snapshots. No external copy is
removed to manufacture privacy or exactly-once success. Synthetic subscription
grants are fixture setup, not production billing or Trial bypass.

The only borrowed helper is 035's ScenarioEvidence JSONL/hash utility; its source
is included in every binding. No Camera, microphone, PhotoKit, StoreKit, Security,
network, personal media or phone operation. Native Security -34018 from 035 stays
a capability skip; it was not retried or replaced. No signing/account changes.

## Execution

Xcode 26.5 (`17F42`), macOS 26.6.2, x86_64 iPhone 17 Pro simulator iOS 26.5
(`23F77`), task-owned UUID `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`.
Unsigned builds (`CODE_SIGNING_ALLOWED=NO`), functional light/large configuration.
Scripts restore previous owned appearance/category and shut down after each run.
No accessibility variant, original test rewrite, timeout increase or unrelated
full-suite run. All current outcomes remain bounded simulator evidence.

| Gate / UTC 2026-10-01 | Observed outcome | Evidence |
| --- | --- | --- |
| Generic iOS Simulator build-for-testing | Passed first build; no compile error. | `build-1.log` (quiet success). |
| Hosted `unit-1`, 19:32:33...19:34:36 | **9 passed, 0 failed/skipped**, 27 separate synthetic histories. | `unit-1/summary.json`, tests, observations, complete scenarios. |
| UI `ui-1`, 19:35:27...19:39:36 | **2 passed, 0 failed/skipped**: four ordinary-exit/re-entry cases, all 31 cumulative histories retained. | `ui-1/summary.json`, activities, 12 native screenshots, observations/scenarios. |
| Generic physical-iOS build | Passed unsigned; no phone/signing/install action. | `device-build.log`, `device-artifact.sha256`; compile only. |

## Hosted Outcomes

The nine methods are in `Tests/ExportPrivacyTests.swift`. Every case records its
manifest, writer plan UUID, event order, actual private/external files and hashes,
native decode results, Film state, original disposition and Development assignments.
`unit-1/observations.json` identifies all 27 exact case UUIDs/configurations;
`removal-order.json` extracts request/cancellation/release/export/removal ordering.

| Scenario / requirement | Observed behavior | Limit |
| --- | --- | --- |
| All five Cameras: no auto-export / FR-08 | Actual native preparation/Development and repository recovery preserve one usable source and its master/clip; no original choice and zero external copy, unchanged assignments/hash. | Synthetic capture inputs; not Camera hardware or full Journal launch flow. |
| Denied/restricted/undetermined and sealed export / M16, STO-06 | Specific permission/needsPermission or mediaNotRevealed rejection; zero writer calls. Revealed sources/masters stay usable; sealed source stays sealed with no disposition. | Authorizer statuses injected. No permission prompt or actual Photos denial. |
| Failed-before-copy, unknown-after-copy, missing receipt, cancelled reply / FR-08 | Exact expected errors; originals and usable masters preserved through reopen, disposition exportRequested, no residual Work. External count 0 for before-copy and 1 for the other three; completed copy retained despite failed acknowledgment. | Faults injected, not PhotoKit/storage failures. Unknown completion is not proof of no external copy. |
| Partial original batch and acknowledged retry / STO-05...07 | First write acknowledged, second fails. Both sources remain; reopen/retry dispatches only second write then verifies/cleans sources, preserving masters. Repeated acknowledged export calls writer zero times. | Exactly-once is established only for these durably acknowledged injected receipts, not unknown external outcomes. |
| Acknowledged copy with corrupted master / STO-07 | Before reply, known synthetic master is changed to invalid bytes or another decodable image. Original receipt persists but cleanup rejects invalidMedia or masterChecksumMismatch; source remains. Restore the exact prior synthetic master, reopen/retry: no new write, verified cleanup succeeds, master hash unchanged. | Deliberate fixture corruption/repair, not actual disk failure or a treatment reroll. |
| Edited developed photo / STO-05 | External bytes match the actual Darkroom-edited print; original disposition remains absent and source/master remain usable. | Native rendering with provisional settings; no approved visual quality or PhotoKit output. |
| Suspend at beforeCopy/beforeReply / M16/M23 | Real owned job cancellation observed while writer held; suspend has not returned. Release yields expected cancellation error; reopen retains same sources/masters and pending original choice, Work removed. Existing external copy remains. | Cooperative injected writer, not native daemon cancellation. |
| Delete at both phases, cooperative and late acknowledgment / FR-18, M23 | Cancellation precedes release; no removal return while writer held. After release, delete completes, private Film/assets/Work/Staging absent after reopen. Late export is filmNotFound without writer dispatch. Completed copies remain, including an in-flight late-ack copy completed before removal returned. | No actual Photos recall claim; no process death while removal is still waiting or physical cleanup failure. |
| Super 8 and 16mm Discard at both phases / FR-16, PRV-05...08 | Old private Movie path removed. Retained clip bytes/treatment assignments/orientation/spent duration unchanged; native reassembly duration matches sole surviving clip. Before-copy cancellation writes nothing; completed stale external Movie stays unchanged. Last-clip Discard retains [1,2] placeholders, no playable/exportable Movie, no private assets or refund. | Silent tiny synthetic media; no active player/cache, licensed soundtrack, camera/HDR or hardware fidelity acceptance. |

Removal ordering is observed through the actual processor cancelling the one
held writer job. No new public queue API or count approximation is used. No
removal acknowledgment coexists with the tested stale private assets; completed
external output is intentionally outside private deletion. This does not prove
every removal/capture/development failure boundary or physical system behavior.

## Re-entry and Retry Limits

The UI tests prepare real native media, start an explicit original export, hold
beforeCopy or beforeReply, inventory and call `_exit(79)`. They relaunch the same
UUID/configuration in a new process, run repository recovery without export, then
explicitly retry. Photo uses one capture; 16mm uses two and exports only original
sequence 1, keeping the other original untouched. All four cases passed. Offline
inspection confirms new process IDs, identical Film/capture chronology, exact
UInt64 treatment seeds, completed-sequence set equality and native source/master/
clip/Movie hashes after recovery, with no automatic export. After explicit retry,
only original sequence 1 is cleaned; usable developed assets remain unchanged.

An unknown copy already completed before process exit has no acknowledged receipt
in the repository. Explicit retry can therefore create a second external copy of
the same source. This is retained and named, not relabeled exactly-once or removed
from evidence. Known acknowledged batch retries are separately proved to skip
previous writes. No new product guarantee, add-only permission expansion or
PhotoKit read/deduplication workaround is introduced.

The photo/beforeReply and 16mm/beforeCopy screenshots were inspected at all three
poses (before exit, recovered and explicit retry). The injected backend and counts
are legible and match inventories. Twelve originals are retained. This is not an
accessibility audit or Camera-quality acceptance. Initial offline Set-order and
integer-precision errors, plus Xcode debugger warnings, are recorded in
[preparation observations](preparation-observations.md); no native result was edited.

## Evidence and Reproduction

Use the [harness README](../../../Probes/ExportPrivacyHarness/README.md) for exact
unsigned build and test commands. Actual labels are `unit unit-1` and `ui ui-1`.
The runner selects the exact hosted/UI bundle, no parallel testing, with maximum
execution allowance 180 seconds. Logs, result summary/test tree, source and app
artifact inventories, selected runtime and all scenario directories are retained.
Copied earlier histories are identified as retained, not newly executed cases.

```sh
node Probes/ExportPrivacyHarness/inspect-evidence.mjs Evidence/ExportPrivacyHarness/036/unit-1 unit
node Probes/ExportPrivacyHarness/inspect-evidence.mjs Evidence/ExportPrivacyHarness/036/ui-1 ui
```

The offline inspector checks test counts and each completed external copy's actual
bytes. UI checks additionally require distinct process IDs, unchanged Film/media/
assignment identity across recovery, no automatic copy, verified cleanup only
after explicit retry and retained unknown-copy duplication. It does not rerun
native decode or infer any hardware result. Native decoder outcomes are recorded
by the production verifier in each inventory. The final checker uses macOS Ruby's
standard JSON parser for lossless UInt64 seed handling and normalizes only the
Swift completedSequences Set for comparison, not captured chronology.

XCTest bundles remain locally at DerivedData/Export036-LABEL.xcresult; committed
summary/tree/activities/scenarios/screenshots support the handoff without that
ignored directory. Final source/artifact/hash/ZIP/link checks are recorded in
`verification.txt`. Exact source identity, not an old green test, controls reuse.

## Risk, Recovery and Remaining Work

Eventual export/privacy work is high risk. Current impact is contained to a new
non-shipping app and explicitly owned simulator synthetic resources. Source
rollback cannot undo consumption/deletion or recall external copies. Failed and
pending histories remain; restoring the deliberately corrupted synthetic master
uses its retained original bytes, not a rerender. Older real backups/Photos copies
remain outside private deletion under the unchanged PRD.

Instruction 036 has approved a subsequent minimal default-absent Development
observer at five existing phases, with zero observer await/log/work when disabled,
cancellation checks after enabled suspension, and no false success/orphan jobs.
That code/verification is still required after this checkpoint. Receipt FIFO
ordering should use existing package-internal count with only one possible new
queued operation, not a new public queue API. Remaining T04/T08/T09 injected fault
cases, native view coverage, capture job races, active-player/cache behavior,
removal process-death/cleanup faults and actual PhotoKit still need evidence.

Physical iPhone/backup/restore/Keychain/fidelity/performance, original QA-13 gates,
assets/rights, prices and other product/Apple configuration stay deferred/open.
No tracker acceptance box, ADR text or requirement was changed. No no-mistakes/CI,
PR, release or merge was performed. QA-14 links this repository-owned report for
reviewed evidence handoff, not a structured scenario import or readiness claim.
