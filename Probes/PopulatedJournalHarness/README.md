# Private Populated Journal Harness

This separate, non-shipping target compiles the actual app views/model/modules
and seeds only its own temporary sandbox with generated native media. It does not
add fixture loading, Trial bypasses or imported media to the production app. It
does not prove native capture, entitlement, Photos writes or real-device behavior.
There are no Camera/Photos usage keys: tests must not invoke those permissions.

The initial Film uses synthetic preexisting subscription rights so edit/removal
workflows can run without configuring purchases. Tests exercise the real native
UI, Development, Darkroom, repository and Movie reassembly. No mocked successful
render path is installed. The separate package tests verify byte-exact Reset and
decoded output; screenshots alone cannot establish those properties.

The retained-scenario preparation additionally injects a read-only in-memory
`DeviceTrialStoring` instance into the existing JournalModel initializer. Any
unexpected ensure/consume call throws; no native Security dispatch occurs. It
requires absent StoreKit configuration, whose existing adapter returns without
calling transaction APIs. No shipping source, receipt namespace, signing setting,
permission usage key or fault flag is changed.

```sh
xcodegen generate --spec Probes/PopulatedJournalHarness/project.yml
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/PopulatedJournalHarness -resultBundlePath "DerivedData/Populated-$(date -u +%Y%m%dT%H%M%SZ).xcresult" -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

Use only a task-owned simulator. Ordinary legacy tests still create a new UUID
history each launch. Retained tests explicitly launch with `--workflow-run UUID`
and reopen that same history using `--reopen`; missing/reused seed histories fail
instead of reseeding. Histories remain under this harness's
`Documents/WorkflowHistories/UUID`, separate from the shipping app. `App/` is the
real private repository, `Fixtures/` holds native synthetic input and `Evidence/`
holds inspected state. Reopening is ordinary app process termination/relaunch,
not iOS backup, power loss or physical recovery.

An explicitly nonshipping inspection bar takes actual repository/development/
recipe snapshots, decodes and verifies retained asset hashes, and renders current
photo print bytes through the production processor. It adds an inset and explicit
rendering work, so its screenshots are contextual native workflow evidence, not
unmodified-app layout, accessibility, timing or render-quality acceptance. It does
not synthesize successful state or call exports. All inspection failures surface
as fixture failures; source/master/print and seed comparisons are separate from
UI assertions.

```sh
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/PopulatedJournalHarness/run-retained.sh UNIQUE-LABEL
ruby Probes/PopulatedJournalHarness/inspect-retained.rb Evidence/PopulatedJournal/037/UNIQUE-LABEL
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/PopulatedJournalHarness/run-retained.sh UNIQUE-LEGACY-LABEL legacy
```

The runner requires the explicitly selected owned simulator to be Shutdown,
preserves appearance/content size, records source/artifact/runtime and xcresult
attachments, copies only newly created histories and shuts down after execution.
The four retained tests cover empty-Film Delete confirmation, early cancellation
and separate Development/original choice, one Instant revealed while the next is
sealed, and saved per-photo edit/exact Reset across relaunch. They never tap Open
Camera, execute Photos export or purchase. The offline Ruby inspector compares
UInt64 seeds exactly and normalizes only the order of Swift's completed-sequence
Set. It is an additional required check, not inferred from a screenshot/test exit.

These are functional navigation tests, not replacements for all-category
accessibility audits or the hardware/manual matrix in
`Evidence/NativeApp/launch-readiness.md`. Production export/privacy races have
their separate injected writer harness. Read `Evidence/PopulatedJournal/037/`
for actual outcomes; prepared commands alone are not acceptance.

The optional `legacy` selection reruns the three unchanged original functional
tests against the new harness. Its initial snapshots alone do not establish the
retained tests' before/after comparisons; do not use the four-history inspector
on that three-scenario output.
