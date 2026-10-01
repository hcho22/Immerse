# Trial Keychain Probe

This probe exists only for `TRI-11` and architecture early check `S4`.
It is not the production Trial implementation and must not be used to accept production Trial behavior.

## What It Tests

The probe writes one generic-password Keychain item with:

- `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- `kSecAttrSynchronizable = false`
- service `com.immerse.trial-keychain-probe`
- account `trial-record`

The app can read the marker, write a fresh marker, mark it consumed, and delete only this probe marker.

## Build

Generate the project:

```sh
xcodegen generate --spec Probes/TrialKeychainProbe/project.yml
```

Simulator compile check:

```sh
xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Generic physical-iOS compile check without signing or installation:

```sh
xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Hardware execution requires a dedicated authorized iPhone running iOS 26 and a signing team selected by a human in Xcode.
Do not change signing, Apple account settings, device trust, or personal-device contents without explicit authority.

As of 2026-09-30, Firstmate recorded that only personal iPhones are available.
Use `PERSONAL_DEVICE_TEST_PLAN.md` for the proposed personal-device path.
That plan authorizes no install, signing, launch, deletion, restore, erase, OS update or settings change until the exact candidate, device and prerequisites are reviewable and the captain grants explicit scoped approval. Firstmate will relay any approved scope.
Whole-phone backup restore, erase, OS update and signing/account changes remain outstanding tests that need separate approval.

## Safe TRI-11 Procedure

Record candidate revision, Xcode version, device model, iOS version, date, and whether the device is dedicated test hardware.

1. Install the probe on iPhone A.
2. Tap `Write fresh this-device-only marker`.
3. Record the marker UUID and screenshot or typed transcript.
4. Force quit and relaunch the probe. Tap `Read marker`. Expected: same marker found.
5. Delete only the probe app from iPhone A, then reinstall the same bundle identifier. Tap `Read marker`. Expected: same marker found.
6. Back up iPhone A and restore that backup onto iPhone B only if Firstmate has authorized destructive restore activity for that dedicated device. Install/open the probe on iPhone B. Expected: no marker found.
7. If an iOS update is authorized for the test device, update and read again. Expected: marker persists.
8. If an erase test is explicitly approved by the captain for the test device, erase and set up the device, install/open the probe, and read. Expected: no marker found. This step is destructive and optional until explicitly approved.

If any expected result fails, do not proceed with production Trial implementation. Record the failure and raise a new decision as required by ADR 0012 and `TRI-11`.
