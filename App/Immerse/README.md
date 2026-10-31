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
The gate also checks that every intake task ID has an evidence-map row and that
the acceptance companion's clause records and invariants are all present.
Coverage is not acceptance. UI audits include the largest
Dynamic Type size and scroll to the title and Load Film command, and every Camera's
Load screen at the smallest size, where the hit-region check once flagged the Film
title field as too small to tap. `ContentSizeTests` asserts that field's frame is at
least 44 points tall at all twelve sizes, which the audit alone does not enforce
(`Evidence/NativeApp/title-field-hit-area-056.md`). The audits' only accepted
findings are the exact, measured entries in `UITests/AuditExceptions.swift`.
Text sizing on every audited screen is measured by `ContentSizeTests` at all twelve
sizes instead of the Dynamic Type audit, which is not run
(`Evidence/NativeApp/qa13-audit-exceptions-052.md`). The script runs the
`JournalFlowTests` accessibility audits, `MovieCapacityUITests`, with its
populated Journal card contrast audit, `FilmStockUITests`, with its Film Stock
Load Film audit, and `LowStorageUITests`, with its low-storage warning audits,
a second time with the simulator set to dark appearance; for
other dark coverage, including `ContentSizeTests`, set
`xcrun simctl ui <task-owned-uuid> appearance dark` before the UI run, then restore
its appearance. Do not infer dark coverage from an `AppleInterfaceStyle` launch
argument or `XCUIDevice.shared.appearance`; neither changed the observed pixels.

## Product Configuration

Live product IDs and prices are intentionally unconfigured. Supply the Info.plist
keys `ImmerseMonthlyProductID` and `ImmerseYearlyProductID` only after approved
Apple setup and DEC-02 decisions. The adapter validates a monthly and yearly
auto-renewable subscription in one group. UI displays only StoreKit's localized
prices, verifies transactions, handles pending/cancelled/error states, observes
updates and restores only after the user requests it. Existing Film operations
never depend on a current subscription. No app-maintained paid Boolean is trusted.

Debug builds alone add the captain-requested testing unlock (`Sources/TestingUnlock.swift`, under `#if DEBUG`).
It starts on, loads every Camera as a subscription Film without touching the Trial record or StoreKit, and shows **Testing unlock - Debug build** on the Load Film and Subscription screens.
Settings > Debug testing turns it off for Trial and plan checks; the choice persists on the device.
It appears only when the scheme's Run action uses Debug.
`Scripts/verify-release-excludes-testing-unlock.sh`, run by the local validation script, fails if Release contains it.

Debug builds alone also preview each saved capture (`Sources/DevelopedPreviews.swift` and FilmRuntime's `PreviewDevelopment`, both under `#if DEBUG`), at the captain's request of 2026-10-21.
While **Develop at once - Debug build** is on in Settings (on by default; `-ImmerseDebugDevelopedPreview NO` turns it off for one launch), every photo of the 6×6 and the Disposable and every clip of the 16mm and the Super 8 shows developed on the shooting screen, marked **Debug preview**, as soon as it is saved.
Those four Cameras' shooting screens show **Develop at once** with a hammer beside **Done** for as long as the switch is on, so its state shows without opening Settings.
It renders through Development's own code with the treatment Development will assign, so a preview is the developed master or Developed Clip; a movie clip keeps its captured sound, while the Developed Movie can replace it with a Soundtrack.
Every capture develops, one at a time in the order it was saved, and each preview takes the card from the one before as it is ready.
The roll stays sealed and develops as before, the Instant is unchanged, and previews live only in the app's Caches folder, removed once nothing shows them, when the roll develops, when the Film is deleted, when the switch is turned off and at launch.
The same Release check fails if Release contains any of it.

The app warns before captures and Development while the iPhone has less than 2 GB free (`Sources/LowStorage.swift`), and stops nothing.
A Debug build launched with `-ImmerseDebugFreeSpace <bytes>` reads that many bytes free instead of the iPhone's own, and any other value, such as `unreadable`, is a reading that fails; screen tests and screenshots use it, and the same script fails if Release contains it.
`Sources/PrivacyInfo.xcprivacy` declares the free-space reading, as Apple requires.

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
not a newly approved DEC-03.
The captain decided the Darkroom's ranges, the export sizes and formats, the Instant's question about each print's original and that a soundtrack can be changed later on 2026-10-13 (`Evidence/NativeApp/darkroom-export-decisions-060.md`).
His phone feedback of 2026-10-26 (`2026-09-29-film-camera-experience-v1/2026-10-26-film-camera-experience-v1-prd-phone-feedback.md`) moved that question to once after the Instant pack's last print, gave new Super 8 and 16mm Films recorded sound, and changed the Darkroom: Dodge/Burn removed, Crop renamed Adjust with quarter turns and straightening, and Saturation and Vignette added within new limits.
The same day, after a study of preserved 1970s prints, he chose the Instant's contrast, which a Film loaded since develops with as treatment version 4 (`film-look-4`), its print-to-print variation unchanged, and each toner's range, from the untoned print to a strength of 1 (`Evidence/NativeApp/instant-study-and-toning-061.md`).
His own sample shots, instrumental licenses, support/privacy wording, measured budgets and launch approval remain open.
`Sources/Resources/MediaCatalog.json` configures rights-verified bundled Camera
samples and instrumentals. It is empty until he supplies his shots and a license
allows a soundtrack inside exported Movies, so no synthetic sample or unlicensed
music is exposed. See `Packages/MediaCatalog`
and `Evidence/NativeApp/2026-10-01-media-workflows.md` for configuration, retained
audio/license recovery and tests. Chemical toning is offered only on black-and-white
6×6 prints, whose Film Stock makes their print process silver gelatin
(`Evidence/NativeApp/prd-2-slice-3-film-stock.md`). No fixture is displayed as a real
Camera sample. Remaining acceptance gaps and manual procedures live under
`Evidence/` and the canonical requirement map.

The app requests Camera at explicit Load Film/Open Camera, microphone access the
first time a new Super 8 or 16mm Film opens its shooting screen, and Photos
add-only at explicit export. The microphone records sound only during movie
clips on new movie Films; older stored movie Films stay silent and never prompt.
It never requests location or photo-library reading.
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
