# Native Film Journal Candidate

Open `Immerse.xcodeproj` in Xcode 26.5. It is generated from `project.yml` with
`xcodegen generate --spec App/Immerse/project.yml` from the repository root.
All production dependencies are local Swift packages. No browser prototype code,
sample-library fixtures, review controls, imports or network backend are included.

The [physical validation handoff](../../Evidence/NativeApp/manual-validation.md)
pins the current candidate and provides future Xcode build/run steps for
HC_iPhone13 (iPhone 13 Pro, iOS 26.6.2), scenario evidence requirements, the full
receipt fault matrix and missing hardware/authority. Physical work is still
deferred; the app is not ready for v1 sign-off.

## Build and Test

From the repository root:

```sh
sh Scripts/validate-local.sh
IMMERSE_SIMULATOR_UDID=<task-owned-ios26.5-uuid> IMMERSE_STOREKIT_SIMULATOR_UDID=<task-owned-ios26.2-uuid> sh Scripts/validate-local.sh
```

The first command runs all package tests, compares the documents ZIP, and builds
the app for simulator and generic device without signing. The optional second
command also runs the native UI and local StoreKit tests on dedicated simulators.
Do not use a physical-device identifier. Tests never require Apple credentials,
real purchases, services, or a connected phone. XcodeGen is required only after
changing project configuration; the generated project is committed for CI.
The gate also verifies coverage of all 122 intake task IDs, 72 acceptance clauses
and nine invariants. Coverage is not acceptance. UI audits include the largest
Dynamic Type size and scroll to the title and Load Film command. Their only
accepted findings are the exact, measured entries in `UITests/AuditExceptions.swift`;
the Load Film screens' text sizing is measured by `ContentSizeTests` instead of the
Dynamic Type audit (`Evidence/NativeApp/qa13-audit-exceptions-052.md`). For separate
dark-appearance coverage, set `xcrun simctl ui <task-owned-uuid> appearance dark`
before the UI run, then restore its appearance. Do not infer dark coverage from
an `AppleInterfaceStyle` launch argument; it did not change the observed pixels.

## Product Configuration

Live product IDs and prices are intentionally unconfigured. Supply the Info.plist
keys `ImmerseMonthlyProductID` and `ImmerseYearlyProductID` only after approved
Apple setup and DEC-02 decisions. The adapter validates a monthly and yearly
auto-renewable subscription in one group. UI displays only StoreKit's localized
prices, verifies transactions, handles pending/cancelled/error states, observes
updates and restores only after the user requests it. Existing Film operations
never depend on a current subscription. No app-maintained paid Boolean is trusted.

The test target alone bundles `Tests/Fixtures/LocalSubscriptions.storekit`.
Its prices and product IDs are synthetic test data, never live recommendations.
The local StoreKit fixture failed to activate on iOS 26.5, matching an Apple-known
StoreKit Test issue. Billing execution uses iOS 26.2 separately from navigation;
fixture preflight prevents fallback to purchase or restore without test products.
This environment split does not skip the required billing assertions.

The unsigned simulator may reject Keychain queries. That does not prove anything
about iPhone Trial behavior: browsing remains available, activation fails closed,
and Settings reports the actual status. Do not add a simulator Trial bypass.
Physical-phone installation, Keychain probing, delete/reinstall and restore are
deferred to captain-directed manual testing; no device action is authorized here.

`TrialCoordinator` is the single capture/recovery/Trial-start/whole-Film-deletion
owner. Complete verified pending media precedes one Keychain receipt/readback and
idempotent SQL projection. Launch recovery finishes before presenting capacity;
unresolved saves remain visible as pending and can be retried or privately deleted.
Never replay native staging during an active recording. See
`Evidence/TrialKeychainProbe/2026-10-01-production-receipt-integration.md` for exact
fault/native-app gates, historical D3 migration and still-unaccepted hardware limits.

## Provisional Choices and Limits

SwiftUI, raw SQLite and local package boundaries are reversible baseline defaults,
not a newly approved DEC-03. Catalog sample rights, instrumental licenses, render
quality/output specs, Darkroom ranges, Instant originals timing, soundtrack
reselection, support/privacy URLs, budgets and launch approval remain open.
`Sources/Resources/MediaCatalog.json` configures rights-verified bundled Camera
samples and instrumentals. It is empty and its reselection policy is unresolved,
so no synthetic sample or unlicensed music is exposed. See `Packages/MediaCatalog`
and `Evidence/NativeApp/2026-10-01-media-workflows.md` for configuration, retained
audio/license recovery and tests. Chemical toning is supported only for an explicitly
saved silver-gelatin print process; all current provisional Camera presets remain
color. No fixture is displayed as a real Camera sample. Remaining acceptance gaps and
manual procedures live under `Evidence/` and the canonical requirement map.

The app requests Camera at explicit Load Film/Open Camera and Photos add-only at
explicit export. It never requests microphone, location or photo-library reading.
PhotoKit exports cannot be recalled. Older iOS backups can restore removed media.
The historical SQL-before-Keychain Trial window has a software correction in the
production receipt report above. Cross-store power-loss, device retention and
two-phone restore remain unaccepted; a software correction is not hardware proof.

For private synthetic populated UI testing, use the separate target and commands
in `Probes/PopulatedJournalHarness/README.md`. It compiles the production views but
is not shipped, does not test capture/Trial, and adds no production fixture hook.
Set `IMMERSE_WORKFLOW_SIMULATOR_UDID=<task-owned-uuid>` to include those tests in
the validation script. CI prepares all three simulator test selections; no CI
pass is claimed until the pipeline observes it.
