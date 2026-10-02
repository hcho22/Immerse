# Receipt Scenario Harness

Non-shipping iOS 26 application for manual runbook T02...T09. It imports the
production TrialCoordinator, CaptureCommitJournal (through that coordinator),
FilmRepository, native media verification and DeviceTrialRecord encoding. It
does not import the shipping UI or alter any production package. No Camera,
microphone, Photos, StoreKit or network request is made by the harness.

## Isolation and Limits

- App identifier: `com.immerse.validation.ReceiptScenarioHarness035`.
- Native Security service: `com.immerse.validation.receipt035.<scenario name>`;
  account `device-trial`, AfterFirstUnlockThisDeviceOnly, synchronizable false,
  through the existing SystemTrialKeychainCalls. The **service/account pair** is
  distinct from production and the earlier marker probe. No broad Keychain query,
  SecItemDelete, reset, migration to a fresh identity or automatic fallback.
- Each scenario has a run UUID, Camera, explicit backend/fault and boundary.
  Its complete identity/namespace and material settings are saved in `scenario.json`
  before work. Re-enter the exact same values to recover; an already-prepared
  scenario cannot prepare again. New scenarios are distinct synthetic histories,
  never a refund. Existing consumed markers/data are retained indefinitely.
- `security` is the actual adapter. `injectedFile` is explicitly a durable ordinary
  file standing in for Security, not a Keychain test. Fault injection logs the
  underlying result separately from the returned fake reply/read status. Resolving
  an injection changes only harness fault state, never its receipt contents.
- Default test scheme uses only injectedFile. The separate `ReceiptNativeSecurity`
  scheme is opt-in. If the unsigned runtime cannot use Security, the one capability
  check records its actual status and skips; a skipped test is **not** acceptance.
  No signing/account/provisioning repair or injected fallback is performed.
- Physical operations remain deferred. An unsigned physical build establishes
  compilation only. Simulator process exits are not power loss, delete/reinstall,
  backup, two-device migration or retention evidence. Do not install on a phone
  or request connection under this preparation authority.

## Build and Execute

From the repository root:

```sh
xcodegen generate --spec Probes/ReceiptScenarioHarness/project.yml
xcodebuild -quiet -project Probes/ReceiptScenarioHarness/ReceiptScenarioHarness.xcodeproj -scheme ReceiptScenarioHarness -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/ReceiptScenario035 CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -quiet -project Probes/ReceiptScenarioHarness/ReceiptScenarioHarness.xcodeproj -scheme ReceiptScenarioHarness -destination 'generic/platform=iOS' -derivedDataPath DerivedData/ReceiptScenario035Device CODE_SIGNING_ALLOWED=NO build
```

Only an explicitly authorized, initially stopped simulator may be selected. The
035 worktree owns `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60` (iPhone 17 Pro, iOS 26.5).
No script assumes every available simulator belongs to this task.

```sh
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ReceiptScenarioHarness/run-simulator.sh unit unit-1
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ReceiptScenarioHarness/run-simulator.sh security security-1
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ReceiptScenarioHarness/run-simulator.sh ui ui-1
```

Labels must be new; results are never overwritten. Run these sequentially, inspect
each result before continuing, and keep any failures. The script pins owned
simulator light/large for this functional harness, restores its earlier settings
and shuts it down. It captures source hashes, base revision, app files, selected
scheme, runtime, raw XCTest summary/exit and all scenario histories. This does
not execute or modify the original failed accessibility matrix.

For CI use only the default scheme/unit/UI selections with an explicitly supplied
CI simulator. Do not add the native Security opt-in to credential/service-independent
CI gates. All test media are tiny synthetic ImageIO/AVFoundation fixtures.

## Controls and Evidence

The harness screen opens one scenario per process. Inputs can also be supplied
as `--receipt-run UUID --camera disposable1990s --backend injectedFile --fault none
--boundary prepared`. These arguments are exclusive to this target.

1. **Prepare** creates a new initial history, synthetic capture metadata and media.
   No success counter is simulated. The source timestamp/hash is saved durably.
2. **Commit** calls the production receiver. At the selected prepared,
   receiptResolved or projected checkpoint it suspends while retaining the save
   owner's lease. **Inspect** records actual SQL state, receipt status, pending
   file hashes and decoded persisted source identity at this stable boundary.
3. **Resume boundary** releases that invocation. **End process** writes/synchronizes
   its evidence then calls `_exit(77)` only while paused. Relaunch with the same
   arguments and **Recover** to replay through the real production owner.
4. **Recover** removes only the harness projection-failure injection and disables
   further pause on that instance; it uses actual repository/native staging
   recovery after the harness writer has quiesced. Unknown receipt injection
   remains until **Resolve injected fault**. Recover is repeatable, not a reset.
5. **Delete synthetic Film** uses the production coordinator. It can be requested
   during a paused save, but request time does not prove entry into its private
   FIFO. **Repeat saved callback** uses the retained receiver on the same process.
   This supports explicit pending deletion/stale-callback assertions without
   exposing a shipping fault switch. A true queue-entry barrier would require
   a reviewed production boundary change; none is made here.

`Documents/ReceiptScenarios/<name>/Evidence/` contains append-only events and
immutable numbered-by-UUID inventories. Each event identifies process and UTC;
adapter events distinguish backend, actual OSStatus and injected result. Inventory
includes full synthetic Film/receipt identity, sequence/date/orientation/count,
outbox, pending state, all repository file SHA-256s and stored-source decode/hash
agreement. Inventory is not a cross-store atomic snapshot; use quiescent or paused
boundaries. No personal Keychain or media is read. Failed/corrupt/pending fixtures
remain available; app deletion or script cleanup is not part of these commands.

## Scenario Coverage

| Runbook | Executable control/check | Limit |
| --- | --- | --- |
| T02 | invalidMedia, production reject before Commit journal publication; zero debit/consumption | Does not simulate native Camera permission or real disk exhaustion. |
| T03/T05 | none + each checkpoint, `_exit(77)` and same-scenario recovery; photo, Super 8, 16mm | Default UI tests use injectedFile. No physical power loss or uninstall/reinstall. |
| T04 | lostReply (applied/readable), unknownApplied and unknownNotApplied; persistent masked read, blocked second load, resolve/re-entry | Errors/replies are deliberately injected, not a native Security daemon fault. |
| T06 | beforeMove, afterMove, afterCommit through existing production save-failure hooks; repeated recovery/duplicate callback | Models named boundary failures, not actual device filesystem failure. |
| T07 | unknown-applied pending deletion and stale callback; delete request during receiptResolved pause | Request-before-release/completion is observable; private queue entry is not. |
| T08 | corruptPending at prepared pause, retain invalid source and reject recovery | Missing files, mismatching identity/sequence, future/malformed native items require additional scenarios. |
| T09 | NEW versionless fixture + real legacy outbox; Film retained or already deleted, consumption reconciliation | Not an upgrade of captain data; other historical/restored cases remain untested. |

Read `Evidence/ReceiptScenarioHarness/035/README.md` for actual outcomes and gaps.
These controls prepare device-capable scenarios; they do not accept any physical
runbook row, clear QA-13, settle product decisions or establish full-v1 readiness.

Offline evidence inspection (does not operate a simulator or Keychain):

```sh
node Probes/ReceiptScenarioHarness/inspect-evidence.mjs Evidence/ReceiptScenarioHarness/035/ui-1 ui
```

Select `unit` or `security` for their run directories. The inspector checks actual
test counts, separates copied historical scenarios from newly opened ones, and
for UI runs requires all nine checkpoint/media combinations, distinct exit/re-entry
processes, pending source hash at the paused boundary and once-only recovered
metadata/source bytes. Native capability skips remain skips. It does not rerun
native decoding or infer missing physical acceptance from a summary.
