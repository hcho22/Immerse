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

```sh
xcodegen generate --spec Probes/PopulatedJournalHarness/project.yml
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/PopulatedJournalHarness -resultBundlePath "DerivedData/Populated-$(date -u +%Y%m%dT%H%M%SZ).xcresult" -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

Use only a task-owned simulator. Fresh launch creates new private fixtures; do not
use it for persistence-across-launch claims or performance acceptance. These are
functional navigation tests, not replacements for all-category accessibility
audits or the hardware/manual matrix in `Evidence/NativeApp/launch-readiness.md`.
