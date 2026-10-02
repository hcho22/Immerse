# Development Process Exit Probe

Nonshipping native synthetic process-exit checks through the already-approved
optional Development observer. No production source, checkpoint, persisted fault
state, receipt/Trial, permission or service is added. Source is shared directly
with the isolated ExportPrivacyHarness target only for boundary names and decoded
state evidence; this is not an app dependency or a general event framework.

```sh
swift test --package-path Probes/DevelopmentProcessExit
xcodegen generate --spec Probes/ExportPrivacyHarness/project.yml
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ExportPrivacyHarness/run-simulator.sh development-exit UNIQUE-LABEL
ruby Probes/DevelopmentProcessExit/inspect-native.rb Evidence/DevelopmentProcessExit/036/UNIQUE-LABEL
```

The macOS probe runs a separate executable over its new temporary synthetic Film
directory. At the exact selected observer boundary it decodes/hash-checks assets,
synchronizes `at-exit.json` and calls `_exit(81)`. Exit 82 means the boundary was
missed and fails the test. The parent verifies status/PID and state, runs production
repository recovery, explicitly resumes with a new default-observer-absent owner,
and compares treatment/retained asset/capacity/reveal/cleanup outcomes. It covers
six boundaries across all five Cameras, one mixed Instant pack and both Movie
Discard reassemblies. Histories remain in temporary `DevelopmentProcessExit/`;
retain newly printed directories and logs with the candidate before cleanup.

The iOS target's explicit `--development-run UUID --camera CAMERA --boundary STAGE`
branch supplies Prepare, Develop to exit, Recover, Resume and Repeat controls.
`--discard-first` selects the synthetic Movie reassembly case. Reopening requires
matching retained scenario configuration; preparation cannot overwrite it. There
is no automatic resume, export, Camera, Security or StoreKit operation. Tests cover
photo after-render, second-Instant before-reveal, Movie after-persistence and
Discard after-assignments. Every exit is an actual app process end, not a caught
error or cancellation. The independent Ruby inspector compares retained native
snapshots with exact UInt64 seed parsing and unordered Set normalization.

Run native selections sequentially on the named owned simulator, initially
Shutdown. The runner preserves preferences and restores Shutdown, retains only
new scenario histories and exports xcresult summaries/attachments. The separate
`ui` mode still selects only the two original export UI tests. Device compilation
and simulator execution do not prove phone interruption, low space, power loss,
full-roll performance, backup/restore, final render quality or physical acceptance.

`Evidence/DevelopmentProcessExit/036/README.md` owns actual outcomes, initial
failures, source/artifact bindings and remaining gaps. `Scripts/validate-local.sh`
includes the credential-independent macOS probe, not a claim that CI has run.
