# Export and Privacy Harness

Non-shipping iOS 26 target for manual M16/M23 and FR-08/16/18 source cleanup,
export interruption and privacy cases. Imports real FilmProcessor, repository,
PhotoExportCoordinator and native ImageIO/AVFoundation fixture/render/verification
paths. It does not use native PhotoKit, Camera, microphone, StoreKit, Security,
network or personal data. Synthetic Films have explicit fixture subscription
grants; no production entitlement bypass is added.

App identifier: `com.immerse.validation.ExportPrivacyHarness036`. Test histories
live under its `Documents/ExportScenarios/<UUID>`, never the shipping container.
`App/` is the actual private repository. `ExternalCopies/` is a test-only directory
representing an independently completed external copy. `Fixtures/` and `Evidence/`
retain synthetic inputs/failures. Private removal assertions apply to App, not
these deliberately retained test copies. This is not an actual Photos export.

## Build and Run

From the repository root, without signing/account changes:

```sh
xcodegen generate --spec Probes/ExportPrivacyHarness/project.yml
xcodebuild -quiet -project Probes/ExportPrivacyHarness/ExportPrivacyHarness.xcodeproj -scheme ExportPrivacyHarness -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/ExportPrivacy036 CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -quiet -project Probes/ExportPrivacyHarness/ExportPrivacyHarness.xcodeproj -scheme ExportPrivacyHarness -destination 'generic/platform=iOS' -derivedDataPath DerivedData/ExportPrivacy036Device CODE_SIGNING_ALLOWED=NO build
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ExportPrivacyHarness/run-simulator.sh unit NEW-UNIT-LABEL
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ExportPrivacyHarness/run-simulator.sh ui NEW-UI-LABEL
```

Use unique evidence labels and run sequentially, inspecting each outcome. Only
the named task-owned iPhone 17 Pro/iOS 26.5 simulator is authorized here, initially
Shutdown. The script records selection/source/artifact/runtime/results, retains
all histories, restores previous owned appearance/content size and shuts down.
No other simulator, global preference or physical device is selected implicitly.
CI may select its own explicitly authorized simulator; all dependencies are local,
authorizations/writer outcomes injected and independent of accounts/services.

The Xcode project reuses only the receipt probe's local `ScenarioEvidence.swift`
JSONL/hash/file helper. It does not import its app or any native Keychain probe.
Both source paths are hashed by the runner. No production package was changed to
create this first export checkpoint. Native Security -34018 from 035 is preserved
and not retried. Physical execution still requires its separate future authority.

## Controls and Provenance

The hosted tests supply a `ControlledExportWriter` through the production public
writer protocol. Plans and each writer UUID are persisted in Evidence before use.
Its allowlisted input is this case's App/Work subtree, with symlinks resolved;
outputs are only ExternalCopies. It decodes actual input, copies bytes, synchronizes
the copy and verifies SHA before recording completion. Receipt identifiers start
with `injected-private-export036:` and are never real PhotoKit local identifiers.

Writer plans provide beforeCopy/beforeReply suspension, failed-before-copy,
unknown-after-copy, missing receipt, cancelled reply, partial batch failure and
late acknowledgment despite cancellation. Cancellation is observed from the real
FilmProcessor-owned job. Suspension/removal tests wait for that event while the
writer is still held, then release it; a request timestamp alone is insufficient.
Recorded errors distinguish harness-injected responses from actual decode/storage
errors. A completed external synthetic copy is never deleted to manufacture a
privacy or retry pass.

The separate UI process tests use strict launch arguments:

```text
--export-run UUID --camera disposable1990s --boundary beforeReply
```

Camera can be `cinema16mm`; boundaries are beforeCopy/beforeReply. Manual controls
also select from the five existing Camera packages. Prepare creates native media,
saves via the real repository and develops with the actual processor. Start export
suspends the writer. Inspect captures state at that boundary; End process logs and
calls `_exit(79)`. Relaunch with identical arguments, Recover, then explicitly Retry
export. Recover performs private repository recovery only, never automatic export.
Prepare cannot overwrite a retained history. No marker or Film reset is exposed.

## Required Outcomes

- Failed, unknown, missing or cancelled writer replies preserve original sources
  and usable masters; native decodes and recorded SHA agree after reopening.
- A known acknowledged original has a durable receipt. Batch retry skips that
  write, then cleans only after independent usable-master verification. A deliberately
  corrupted master prevents cleanup even after an acknowledged external copy.
- Developed-photo export uses the actual Darkroom print without changing original
  disposition or deleting its source. Preparation/recovery never writes externally.
- Suspend/Delete/Discard wait for the held production job. Late callbacks cannot
  recreate removed private media. Completed external copies remain outside removal.
- Movie Discard retires the old private assembly, preserves the retained clip and
  treatment assignments, reassembles only that clip and does not refund duration.
  Last-clip Discard retains numbered placeholders with no playback/export.
- Process exit before copy or reply retains source/master identities. Explicit
  retry after an unknown completed copy can create another external copy: there
  is no acknowledged identifier to deduplicate. Record both, not an exactly-once
  external-write claim. Known acknowledged retries must not copy again.

Read `Evidence/ExportPrivacyHarness/036/README.md` for observed results and limits.
Offline inspection uses `node inspect-evidence.mjs RUN-DIRECTORY unit|ui` from this
directory (or the full script path from repository root). It uses macOS's built-in
`/usr/bin/ruby` JSON parser for exact UInt64 seed comparison; no dependency download.
Ordinary process exit is not power loss, test writer errors are not PhotoKit daemon
errors, and repository reopen is not backup/restore. Accessibility failures and
physical/product gates remain open. Exact Development observer work is a subsequent
checkpoint, not part of the first delivered export boundary controls at `a6000b3`.
The added `DevelopmentObserverTests` hosted target reuses the production package's
test source without adding a shipping fault setting or changing the export UI.
Run `run-simulator.sh development UNIQUE-LABEL` with the explicit simulator
selection above. Its snapshots/native media are retained separately in
`Evidence/DevelopmentObserver/036/`; read `Packages/FilmRuntime/README.md` for
the precise five-phase observer contract. This mode is not accepted by the
export-only offline inspector, whose nine/two test counts remain unchanged.
