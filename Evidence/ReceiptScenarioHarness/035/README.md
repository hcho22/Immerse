# Receipt Harness Checkpoint 035

**Bounded engineering checkpoint, not implementation-ready or full-v1 acceptance.**
Base `63c21ce0590bb6aefe7a36f38fb0229c9e715813`, branch
`fm/immerse-v1-implementation`. Added source is bound by each run's `source.sha256`
and the commit containing this report; the base alone is not the tested candidate.
Production packages/app and original accessibility tests are byte-unchanged.
Instruction 035 pauses further accessibility variants and authorizes isolated
native preparation only. The four original matrix failures/seven findings remain.

## Delivered Surface

[ReceiptScenarioHarness](../../../Probes/ReceiptScenarioHarness/README.md) is a
separate non-shipping iOS application importing production `TrialCoordinator`,
`CaptureCommitJournal`, `FilmRepository`, native media verification, receipt
encoding and Keychain adapter. No shipping fault switch, Trial reset or product
semantics change. It supplies explicit pause/release/ordinary exit/re-entry at
prepared, receiptResolved and projected checkpoints, typed synthetic faults,
retained pending media, receipt/SQL/media inventories and timestamped event logs.

Default hosted/UI tests use `injectedFile`: an ordinary receipt file, never real
Security. The separate opt-in native capability scheme uses only a new recorded
service/account pair. Neither default test scheme nor CI calls native Security.
There is no reset/delete-marker command, broad Keychain query, Camera/Photos/
microphone/StoreKit/network request or production target dependency on the probe.

## Environment and Execution

All executed runs: Xcode 26.5 (`17F42`), macOS 26.6.2, owned x86_64 iPhone 17 Pro
simulator iOS 26.5 (`23F77`), UUID `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`.
`CODE_SIGNING_ALLOWED=NO`, light/large functional harness configuration.
Run scripts record prior appearance/category and restore them, then shut down.
No global preference, physical device, Apple account or signing repair occurred.

| Gate / UTC 2026-10-01 | Observed outcome | Evidence |
| --- | --- | --- |
| Unsigned generic simulator build-for-testing | Passed after three retained compile errors were corrected in the harness. | `receipt035-build*.log`, [preparation failures](preparation-failures.md). |
| Unsigned generic physical-iOS build | Passed; compilation only, no signing/install/phone action. Empty quiet log is retained; final artifact inventory is separate. | `device-build.log`, `device-artifact.sha256`. |
| `unit-1`, 19:04:31...19:05:52 | 8 passed, 0 failed/skipped; 19 separate synthetic histories. | `unit-1/summary.json`, test tree, observations, complete scenarios. |
| `security-1`, 19:08:12...19:08:35 | **0 passed, 1 skipped**. Actual Security read returned **-34018** before any add/update or Film creation. No native receipt success or injected fallback. | `security-1/summary.json`, capability activities, scenario events and namespace below. |
| `ui-1`, 19:09:07...19:15:04 | 3 passed, 0 failed/skipped: **nine** exact checkpoint ordinary exits and same-scenario relaunches across photo, Super 8 and 16mm. | `ui-1/summary.json`, activities, 18 screenshots, observations and complete scenarios. |
| `unit-2`, 19:16:29...19:17:40 | 8 passed, 0 failed/skipped after requiring the specific production rejection type/status, not any error. Nineteen additional independent histories; all 48 cumulative histories retained. No harness-app/production/UI source change. | `unit-2/summary.json`, source inventory and retained histories. |

The one real Security namespace is
`com.immerse.validation.receipt035.0D208F17-C6A7-457D-A1BD-399D3AAF8B52-disposable1990s-security-none-none`,
account `device-trial`, through the production AfterFirstUnlockThisDeviceOnly,
non-synchronizing adapter. Service/account pair is distinct from production and
the old marker probe. Actual reads were -34018, with no write dispatch. No retry
with altered signing, account, service semantics or old marker was attempted.

Each run's `observations.json` identifies newly opened versus previously retained
histories; copied prior scenarios are not counted as new tests. Per-case
`scenario.json` and `Evidence/events.jsonl` name backend, fault, UUID, namespace,
runtime, original media identity and process IDs. Inventory JSON preserves
Film/receipt identity, chronology, orientation, consumed count/duration, pending
and outbox state, stored-source decode/hash and repository file hashes.
Inventories are quiescent/explicitly paused observations, not cross-store atomic
snapshots. Process sequences are local to an evidence-writer instance; process ID
and event order distinguish relaunches, not sequence numbers alone.

## Scenario Outcomes and Limits

All passes below are **bounded simulator software** evidence, not physical-row
acceptance. Each case remains partial against the full manual runbook.

| Case / relevant behavior | Observed result | Still untested |
| --- | --- | --- |
| T02 / FR-04, TRI-03 | Invalid synthetic photo rejected as `PersistenceError.invalidMedia`; zero saved count/SQL receipt/consumption, 27 exposures left, no published Commit journal. | Camera denial, interrupted hardware write, actual storage exhaustion and prior-media preservation on a populated phone. |
| T03 / capacity, chronology | At prepared pause: original pending source SHA present, count 0, unused injected receipt. Exit/relaunch recovers one sealed capture with same timestamp/hash; one debit, no pending/outbox. | Physical power loss or real Security durability. |
| T04 / unknown outcome | Lost reply with actual applied/readable injected record succeeds. Applied-but-unreadable and not-applied-but-unreadable persist pending count 0; reopen/recovery/new load reject with -25308. Explicitly resolving the injection allows same capture to project once; repeated resume/callback does not debit twice. | Actual native daemon failure/lost reply, malformed/mismatching readback and physical fault windows. Fake returned statuses are separately logged from underlying file results. |
| T05 / receipt before SQL | At receiptResolved pause: consumed injected record, count 0, same pending source. Relaunch projects exactly one photo/Super 8/16mm capture. | Native receipt retention, uninstall/reinstall, media loss and backup cases. |
| T06 / move, projection and cleanup | Existing before-move, after-move, after-commit failure hooks reject at their named production boundary for all three media packages. Pending original hashes remain; repeated recovery and duplicate callback retain one sequence/debit. At projected UI pause count is already 1 with pending cleanup; relaunch retires pending without another capture. | Actual physical filesystem/database faults; full-capacity/last-frame native capture. |
| T07 / deletion precedence | Unknown-applied pending Film deletes without resolving the masked store; stale callback is `filmNotFound`, App Media/Staging absent, same consumed record retained after reopening. A separate 16mm save pauses at receiptResolved; delete request occurs before release, save/delete finish, stale callback rejects and no Film/staging returns. | **Actual FIFO queue-entry ordering is not observed**; request time is not proof of entry. No exact decode-await deletion or shipping CaptureController race yet. |
| T08 / corrupt pending | After prepared pause, overwrite only known synthetic pending source. Commit/recovery both reject `invalidMedia`; count 0/unused record/no SQL receipt, corrupt pending retained for inspection. | Missing payload, conflicting identity/sequence/hash, future/partial/native malformed record. |
| T09 / legacy | New versionless synthetic record plus real legacy outbox reconciles once for a retained Film and an already-deleted Film. Same device identity, consumed with no invented capture receipt, no outbox remaining, no refund. | Actual device upgrade/restored histories, unrelated legacy failure alongside paid-Film saving. |

UI relaunch evidence additionally checks saved sequence 1, original savedAt,
sealed state, decoded stored source and matching actual copied media SHA, one
receipt matching Film/capture/date, and Movie portrait lock plus landscape clip
metadata/duration. `inspect-evidence.mjs` checks all nine combinations and different
exit/recovery process IDs. 16mm/prepared, photo/receiptResolved and Super8/projected
before/after native screenshots were inspected: status/counters are legible and
match the retained inventories. This is not an accessibility audit or render
quality acceptance. Xcode emits repeated debugger-version snapshot warnings in
the UI execution log; they are retained, not called warning-free execution.

## Commands and Evidence Binding

The harness README owns the exact unsigned build/test commands. Executed labels:
`unit unit-1`, `security security-1`, `ui ui-1`, `unit unit-2`, supplied sequentially
to `run-simulator.sh` with the owned `SIMULATOR_ID` above. Labels are never reused.
Default scheme is `ReceiptScenarioHarness`; native opt-in is `ReceiptNativeSecurity`.
The runner uses `-only-testing`, disables parallel testing and sets maximum test
execution allowance 180 seconds. No timeouts or assertions were relaxed.

```sh
node Probes/ReceiptScenarioHarness/inspect-evidence.mjs Evidence/ReceiptScenarioHarness/035/unit-1 unit
node Probes/ReceiptScenarioHarness/inspect-evidence.mjs Evidence/ReceiptScenarioHarness/035/security-1 security
node Probes/ReceiptScenarioHarness/inspect-evidence.mjs Evidence/ReceiptScenarioHarness/035/ui-1 ui
node Probes/ReceiptScenarioHarness/inspect-evidence.mjs Evidence/ReceiptScenarioHarness/035/unit-2 unit
```

XCTest result bundles remain under `DerivedData/Receipt035-LABEL.xcresult` locally;
committed summaries/test trees/activities and raw scenario evidence support this
handoff without that ignored directory. UI attachments exported with
`xcrun xcresulttool export attachments --path DerivedData/Receipt035-ui-1.xcresult
--output-path Evidence/ReceiptScenarioHarness/035/ui-1/attachments`; its manifest
maps file UUIDs to named Camera/boundary/screenshots. Activities use
`xcresulttool get test-results activities --path RESULT --test-id TEST`.
Earlier compile/inspector errors and unavailable optional console export are
retained in preparation-failures; no fabricated stdout or rebuilt screenshot.

Per-run source/app-file hashes bind executed app and tests to the unchanged
production base. `source-final.sha256` and `device-artifact.sha256` bind the final
prepared surface. The final source check compares compiled harness Sources/UI/
native tests with ui-1/security-1 and exact-error tests with unit-2. Documentation
and offline inspection script additions are not relabeled as compiled evidence.
`verification.txt` records source/manifest checks, ZIP/content comparison, stable
122 intake IDs/72 clauses/nine invariants and owned simulator shutdown. Those are
traceability checks, not acceptance or CI.

## Impact, Recovery and Handoff

Risk remains high for eventual receipt/media fault work; current impact is
contained to a separate app and explicitly owned simulator synthetic directories.
App deletion assertions concern each scenario's `App/` repository, not the
deliberately retained Fixtures/Evidence copies outside it. No personal media or
entitlement was read, destroyed or reset. Consumed histories remain retained.
Source rollback cannot undo consumption/private deletion; older device backups
and external Photos copies remain beyond app deletion's reach.

Boundary discrepancy reported **before dependent changes**: public production
hooks expose prepared/receiptResolved/projected, not exact FIFO queue entry or
Development assignment/render/persistence phases. No such production change was
made. [Remaining engineering](remaining-engineering.md) gives the concrete next
deliverables, existing export injection interfaces and proposed checkpoint impact
for Firstmate review. These are code gaps, not waived by manual-device deferral.

Physical tests, original accessibility gates, assets/rights, budgets and required
product/Apple configuration remain unaccepted. No new product DEC, trial-success
definition, server or identity workaround. No no-mistakes/CI/PR/release/merge was
run or claimed here. QA-14 links this repository-owned report for the selected
validation owner; scenario linkage is reviewed, not machine-imported by Firstmate.
