# Exact Development Process Exits

Continuation of instruction 036's approved optional observer and native recovery
preparation. **No shipping source, protocol, schema or new observer boundary
changed.** This adds a standalone macOS probe and an explicit diagnostic branch
inside the existing nonshipping ExportPrivacyHarness only. Production repository,
renderer, assignments, reveal and cleanup behavior are exercised with generated
private media and synthetic existing subscription Films. No Security, Camera,
Photos, microphone, StoreKit, network, personal data or physical device action.

## Candidate and Boundaries

Base `d1aa4947e0fa1a1606d25bdf1f335ebfe40c8a1a` plus code committed with this report.
`package-source.sha256`, `native-source.sha256`, hosted `source.sha256`, app file
hashes and `final-checks.sha256` bind tested inputs/artifacts. The package source
inventory predates later inspector refinements; those were not package-test inputs
and the final inspector hash is in final-checks. Empty `production-diff.txt` records
the shipping-source comparison. Host macOS 26.6.2/25G83, Swift 6.3.2, Xcode 26.5/
17F42, observed October 1, 2026. iOS execution uses only the owned x86_64 iPhone
17 Pro simulator, iOS 26.5/23F77, UUID `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`.

The existing observer runs before begin, after assignments, after rendering,
after persistence, before reveal and before source cleanup. At the selected
boundary the probe reads actual Film/Development state, decodes and hash-verifies
all referenced assets, synchronizes `at-exit.json`, then calls `_exit(81)` without
running Swift cleanup defers. The macOS parent checks actual exit reason/status
and a different child PID; missing boundary exits 82 and fails. iOS UI tests observe
the app end and relaunch with a different PID; its exact boundary snapshot and
source call establish the selected path, not an independently captured OS exit code.

Recovery uses `FilmRepository.recover()` before a new default-observer-absent
`FilmProcessor` explicitly resumes. No automatic Development/export occurs. The
same source/master/clip and treatment comparisons are performed on repeated
resume. Assembled Movie container byte equality is deliberately not asserted on
repeat: native reassembly may replace the container. Surviving clip bytes,
treatment, ordering, orientation, captured duration and decoded output remain the
behavioral requirements checked here, not a new container-byte guarantee.

## Executed Gates

| Gate | Observed outcome | Evidence |
| --- | --- | --- |
| First package build | Failed Swift 6 fixture isolation; zero tests ran | `package-1.log`, `tests-before-isolation.swift.txt` |
| First executable package run | Three methods, one pass/two failures: fixture chose originals before roll/Movie completion; correct `mediaNotRevealed` rejection | `package-2.log`, `tests-before-fixture-order.swift.txt`, three retained histories including two incomplete preparations |
| Corrected package run | Three methods pass, zero failures; 33 actual child exits, 48.207s | `package-3.log`, `completed-package-cases.txt`, 33 `package-3-histories/` directories |
| Unsigned simulator build-for-testing | Passed | `simulator-build-1.log` (quiet/empty success) |
| Unsigned generic iOS device build | Passed, compile only | `device-build-1.log`, `device-app-files.sha256` |
| Native Development UI run | Four pass, zero failure/skip; 309.000s result interval | `development-exit-036-1/summary.json`, tests/log, four histories, attachments |
| Independent native snapshot inspection | Four pass, 20 snapshots compared | `development-exit-036-1/inspection.log` |
| Original export UI regression | Two pass, zero failure/skip; four original export exits, 226.241s. Existing offline inspector passes. | `Evidence/ExportPrivacyHarness/036/development-default-ui-036-1/`, `default-ui-inspection.json` |

Only test fixture ownership and preparation order were corrected: mark its
repository-owning fixture MainActor, then complete roll/Movie before choosing
originals, as production requires. No product guard/assertion was weakened. Every
initial failure remains recorded. Native logs retain debugger-version metadata
warnings; source-bound local results are not a clean-diagnostics, CI or device claim.
Readable boot logs omit trailing blank lines; exact originals remain in adjacent
`boot.log.raw.gz` files.

The six-boundary package matrix covers all five Cameras with one captured source.
The extra Instant history exits before print 2 reveals while print 1 is already
revealed; two Movie histories exit during reassembly after Discard. These are
33 histories, not 33 XCTest methods. The hosted cases are independently executed:

| iOS case | Observed before exit/recover | Observed after explicit resume |
| --- | --- | --- |
| Disposable afterRendering | One sealed source, assignment fixed, no persisted master; recovery alone unchanged | One revealed verified master, declined source cleaned; repeat keeps master/treatment |
| Instant before print-2 reveal | First revealed/second sealed, both persisted masters; recovery does not reveal second | Both revealed, open pack/eight left; first master and assignments unchanged, declined sources cleaned |
| 16mm afterPersistence | One sealed source and verified clip; no Movie assembly/reveal | Clip unchanged, Movie assembled/revealed, locked orientation and spent duration retained |
| Super 8 Discard afterAssignments | Clip 1 and stale Movie retired, numbered discarded placeholder; clip 2 retained | Only clip 2 reassembled; no capacity refund or discarded clip resurrection |

All 33 package histories retain exact exit and resumed snapshots. Repository
recovery removes abandoned Work, never the referenced masters/clips. Sources
remain at pre-cleanup exits, then explicit resume removes declined sources only
after production native verification. BeforeBegin has no treatment yet; later
boundaries preserve exact persisted seeds/version/process. Original capture
sequence/timestamps/capacity and locked orientation survive. Movie Discard checks
also verify old private assembly path absence and one-surviving-clip duration.
This is synthetic short-media evidence, not full-roll timing or hardware fidelity.

The native inspector uses Ruby JSON integers to retain UInt64 precision and
normalizes only completedSequences Set order. It checks process changes, exact
recovery-only state, assignment/master/clip identity, spent capacity, individual
reveal, cleanup and no resurrection. Screenshots were visually inspected for
recovery-only sealed status (`0327903E-9BD0-4696-A0EF-9EEB4427D12F.png`) and resumed
Movie placeholder count (`48BE710F-912C-4A40-88FB-DA2E1923E77F.png`) under native
attachments. Diagnostic controls/status render without observed overlap; these
are not shipping UI, final render-quality or accessibility acceptance screenshots.

## Commands and Handoff

Exact commands and controller semantics are in
`Probes/DevelopmentProcessExit/README.md`. `Scripts/validate-local.sh` now includes
the new credential-independent macOS tests; its whole unrelated suite and CI were
not rerun here. Native execution used `run-simulator.sh development-exit
development-exit-036-1` followed by the independent inspector. Local result bundle:
`DerivedData/Export036-development-exit-036-1.xcresult`. Summaries/attachments and
only new histories are committed. Simulator began Shutdown, preferences restored
and Shutdown restored before the separately selected original export UI run.
The original UI run used `run-simulator.sh ui development-default-ui-036-1` and
the unchanged `inspect-evidence.mjs ... ui` gate. Its collector copied older
histories too; `default-ui-evidence-selection.json` identifies exactly the four
fresh executions by first-session time and records older redundant copies moved
to local `DerivedData/DevelopmentExit036-unrelated-copied-histories`. No historical
result was counted as a new execution or erased. That run also restored Shutdown.

Partial FR-06/16 and DEV-04/06/07/08, PRV-05/07, ARC-06, QA-03/11 evidence. Ordinary
process exits are not power loss, physical interruptions, actual restore or an
atomic filesystem guarantee. No physical ARC-08/10/11/12, TRI-11 or QA-15 acceptance.
Later checkpoints cover bounded capture-backend quiescence
(`../../NativeApp/capture-backend-quiescence-040.md`), active Movie/player state
(`../../NativeApp/movie-player-cache-042.md`,
`../../NativeApp/darkroom-player-observation-044.md`), full capacities
(`../../NativeApp/full-capacity-runtime-043.md`) and additional Darkroom control
reachability (`../../NativeApp/darkroom-player-observation-044.md`). Real
permission/storage failures, assistive technologies and hardware paths remain
separate preparable or hardware work. Original QA-13 failures and deferred product/asset/
price/support/launch choices remain open. No no-mistakes run, CI-ready claim, PR,
release/publication or merge.

Risk remains high for persistent media behavior, despite unchanged shipping code.
Containment is separate target/synthetic sandbox. Snapshot inspection adds time
and reads before exit, so it does not model unobserved sudden power loss. A code
rollback cannot undo consumption, removed media, independent exports or an older
backup. Failure histories remain available; no original/private data was reset.
This repository-owned report is evidence for the selected validation owner, not
machine-enforced scenario import or a replacement for human judgment.
