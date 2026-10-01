# Approved Probe Attempt: 2026-10-01

Outcome: signed build passed; device execution remains untested because the approved iPhone was unreachable. This is partial preparation for `TRI-11`, not acceptance of Trial behavior.

## Authority and Candidate

The captain answered "Confirm device and approve probe-only test", relayed by Firstmate at `2026-10-01T02:18:01Z`. The approved target is the paired iPhone 13 Pro (`iPhone14,2`) on iOS 26.6.2. The scope permits selecting the existing development team, building/installing/launching only `com.immerse.TrialKeychainProbe`, writing/reading/consuming its synthetic marker, terminating/relaunching the probe, deleting only this probe app, and reinstalling the same candidate. The Keychain service remains `com.immerse.trial-keychain-probe`.

Source revision: `6e5c1742d344e0505b74176f60ac11c19a83e686`. Build checkout: `6ed3adb`, branch `fm/immerse-v1-implementation`. The following comparison exited 0 with no differences, including against the working tree:

```sh
git diff --exit-code 6e5c1742d344e0505b74176f60ac11c19a83e686 -- Probes/TrialKeychainProbe/Sources Probes/TrialKeychainProbe/project.yml Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj
```

This proves the approved probe source and project are unchanged; later commits changed documentation and unrelated packages only. No test automation code was added to the approved candidate.

## Build Evidence

Observed at `2026-10-01T02:19:26Z` through `02:19:38Z`, Xcode 26.5 (`17F42`), iPhoneOS SDK 26.5, target `arm64-apple-ios26.0`.

The build used the existing approved team as a command-line setting only. No account, certificate, profile, project signing setting or provisioning portal update was requested. The local result bundle retains the expanded command and signing identity; the command below substitutes `PROBE_DEVELOPMENT_TEAM` for the private team identifier.

```sh
xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS' -derivedDataPath DerivedData/TrialKeychainDeviceProbe -resultBundlePath DerivedData/TrialKeychainDeviceProbe-build.xcresult DEVELOPMENT_TEAM="$PROBE_DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic build
codesign --verify --deep --strict --verbose=2 DerivedData/TrialKeychainDeviceProbe/Build/Products/Debug-iphoneos/TrialKeychainProbe.app
```

Observed: `BUILD SUCCEEDED`, exit 0. Signature verification exited 0, reporting `valid on disk` and `satisfies its Designated Requirement`. This local signature check does not prove installation or execution on iOS.

- App: `DerivedData/TrialKeychainDeviceProbe/Build/Products/Debug-iphoneos/TrialKeychainProbe.app`
- Local build result: `DerivedData/TrialKeychainDeviceProbe-build.xcresult`
- Bundle identifier: `com.immerse.TrialKeychainProbe`
- Executable SHA-256: `690cead385ceed5c58b2d1abf49dc414be7d82f99002ee89bd644666e6d95ef1`
- Debug dylib SHA-256: `e69edafbce27c96503b9544250b89e47cb25fa309ac99acea41a9519a2807c58`
- Actual embedded signing certificate validity: 2026-09-17 through 2027-09-17. The certificate was extracted from the signed app; a certificate-name lookup alone also found an older certificate, so it is not the candidate's identity evidence.
- Embedded provisioning profile expiry: `2027-09-17T12:39:39Z`.

Keep this exact local app for the approved delete/reinstall comparison. Before install and reinstall, recheck both hashes and signature. A rebuild has a new artifact identity and must be recorded separately; never claim a newly built app is byte-identical without comparison. Signed artifacts and device identifiers are not committed.

## Device Observation

Read-only discovery before build:

```sh
xcrun devicectl list devices
xcrun devicectl device info details --device "$PROBE_DEVICE" --timeout 10
```

`PROBE_DEVICE` is the already-confirmed phone's CoreDevice identifier. Discovery reported the phone as `unavailable`. Details reported iPhone 13 Pro, iOS 26.6.2 (`23G90`), `pairingState: paired`, `developerModeStatus: enabled`, `tunnelState: unavailable`, and `ddiServicesAvailable: false`. Device details are cached metadata; they do not establish a current live connection. The observed last connection was `2026-09-30T21:45:00Z`.

Precise prerequisite: the confirmed phone must be reconnected/reachable through Xcode/CoreDevice before install/launch. No installation was attempted while unavailable. No unlock, pairing, trust, Developer Mode or other settings change was performed. If a later operation actually requests an additional setting or human unlock, report that specific prerequisite through Firstmate and stop that step.

## Behavioral Results

| Scenario | Expected observation | Result at this attempt |
| --- | --- | --- |
| Initial read | Marker absence or exact pre-existing synthetic marker recorded before changing it | Untested: no install/launch |
| Write/read | One marker UUID, timestamp and unconsumed state read from Keychain | Untested: no Keychain write |
| Relaunch/read | Same marker and unconsumed state | Untested: phone unavailable |
| Consume/relaunch/read | Same marker with consumed state | Untested: phone unavailable |
| Probe-only delete/reinstall/read | Same marker and consumed state using the same signed app | Untested: no app deleted or reinstalled |
| Two-phone restore | Device-bound marker omitted on destination; backed-up Films preserved | Untested: additional hardware and restore authority absent |
| First-save fault windows | No free capture or consumed Trial without the required successful save | Untested: production Trial remains gated by TRI-11/ARC-11 |

No app was installed, launched or removed in this attempt. No synthetic marker, Photos entry, purchase, user media, other app, phone setting or Apple account was changed. Only the approved local probe build/sign operation ran. There is no production exposure.

## Resume and Limits

Resume the already-approved single-phone procedure in `Probes/TrialKeychainProbe/PERSONAL_DEVICE_TEST_PLAN.md` when this phone is reachable; do not request duplicate approval for the same scope. Record marker UUID/state before and after each transition and the actual artifact hashes. Stop on an unexpected marker/read result and retain evidence before any retry.

Successful single-phone results would still leave two-phone restore, backup fidelity, the Trial first-save cross-store fault window, native Movie fidelity and iPhone 11 timing unproved. `TRI-11`, `ARC-08`, `ARC-10`, `ARC-11`, `ARC-12`, and `QA-15` remain open.
