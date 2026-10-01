# Personal-Device Test Plan

This plan records the currently available hardware path for `TRI-11`.
Captain approval relayed on 2026-10-01: "Confirm device and approve probe-only test".
This confirms `HC_iPhone13`, the paired iPhone 13 Pro on iOS 26.6.2, and authorizes the exact probe-only sequence below using the existing development team. No duplicate approval is needed for these actions. Whole-phone restore/erase, Apple account or device settings changes, other apps, purchases, personal media and public exposure remain outside this approval.

Current execution record: [2026-10-01 device attempt](../../Evidence/TrialKeychainProbe/2026-10-01-device-attempt.md). Signed build passed; the phone's CoreDevice tunnel was unavailable, so install/launch/marker/reinstall checks remain untested.

Later captain instruction: **"implement prd first. i'll test is manually when v1 is ready"**.
The approval and pinned sequence below remain intact, but physical execution and
reconnection requests are deferred. This marker probe does not validate the new
production receipt protocol. See the [full physical handoff](../../Evidence/NativeApp/manual-validation.md)
for future app build steps, full-protocol cases and their separate authority and
hardware requirements; v1 is not ready for manual sign-off.

## Candidate Identity For Review

- Source branch: `fm/immerse-v1-implementation`
- Probe source revision under test: `6e5c1742d344e0505b74176f60ac11c19a83e686`
- Probe bundle identifier: `com.immerse.TrialKeychainProbe`
- Probe Keychain service: `com.immerse.trial-keychain-probe`
- Probe scheme: `TrialKeychainProbe`
- Xcode version recorded before review: `Xcode 26.5`, build `17F42`
- Captain-reported target device: iPhone 13, iOS 26.6.2
- Read-only Xcode discovery on 2026-09-30 local time: `HC_iPhone13`, available and paired, iPhone 13 Pro (`iPhone14,2`)
- Device identity: captain confirmed the paired iPhone 13 Pro as the intended target through the probe-only approval, resolving the earlier iPhone 13 label mismatch.
- Signing team/profile: selection of the existing development team for this probe is approved. The signed build used a command-line team setting and existing provisioning, without account or portal changes.
- Generic physical-iOS build command prepared for review:

```sh
xcodegen generate --spec Probes/TrialKeychainProbe/project.yml
xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

- Generic physical-iOS build result: passed with signing disabled; no install or launch performed.
- Generic physical-iOS artifact path: `/Users/hcho/Library/Developer/Xcode/DerivedData/TrialKeychainProbe-fbfzhiholludheevzyfcstyvxevx/Build/Products/Debug-iphoneos/TrialKeychainProbe.app`
- Bundle/build identity for the review packet: bundle identifier `com.immerse.TrialKeychainProbe`, source revision `6e5c1742d344e0505b74176f60ac11c19a83e686`, Xcode `17F42`, iPhoneOS SDK `26.5`, target `arm64-apple-ios26.0`.

## Data Touched

- The probe writes only one generic-password Keychain item:
  - service: `com.immerse.trial-keychain-probe`
  - account: `trial-record`
  - accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
  - synchronizable: `false`
- The probe creates no user media, no Photos entries, no network traffic, no StoreKit purchase and no analytics.
- Optional synthetic app/media tests must use freshly created synthetic captures only, never the captain's real personal media.

## Approved Probe Steps

The captain approved these steps for this candidate and this phone. Preserve the exact source and signed artifact identity throughout. Stop the affected step and report through Firstmate if an additional device setting or human unlock is required; continue unaffected work.

1. Select the existing approved Apple development team/profile for `com.immerse.TrialKeychainProbe` only. Local signed build passed; see the execution record for artifact hashes.
2. Verify the approved iPhone 13 Pro/iOS 26.6.2 target is reachable, then install the signed probe. Reconnection is the current missing prerequisite.
3. Launch the probe.
4. Tap `Write fresh this-device-only marker`.
5. Record the marker UUID, timestamp, device model, iOS version, bundle identifier, Keychain service, source revision and Xcode build.
6. Force quit and relaunch the probe.
7. Tap `Read marker`. Expected: same marker found.
8. Tap `Mark consumed`.
9. Force quit and relaunch the probe.
10. Tap `Read marker`. Expected: same marker found with consumed state.
11. Delete only the probe app, as included in the captain's scoped approval. Do not tap `Delete probe marker`.
12. Reinstall the exact same signed app and bundle identifier from the same source revision; compare artifact hashes before reinstall.
13. Tap `Read marker`. Expected: same marker found with consumed state after delete/reinstall.

## Expected Evidence Packet

- Terminal transcript for the exact build command and Xcode version, including the signing-disabled generic physical-iOS build result above.
- Built artifact path and bundle/build identity from the candidate identity section.
- Screenshot or typed transcript of each probe screen after write, relaunch/read, consumed/read and approved reinstall/read.
- Device model and iOS version from Settings, Finder, Xcode Devices or `xcrun devicectl`.
- Captain confirmation of the paired iPhone 13 Pro target, recorded above, and live device identity before installation.
- Statement that no Photos entries, StoreKit purchase, network service, app media, real personal media, Account or analytics were touched.
- If any step fails, stop and record the observed failure before changing the production Trial design.

## What This One Phone Can And Cannot Prove

Can prove on the approved iPhone 13 Pro/iOS 26.6.2 target:

- A this-device-only, non-synchronizable Keychain marker can be written and read by the probe.
- The marker survives app relaunch.
- The marker survives the approved deletion and reinstall of only the probe app with the same bundle identifier.

Cannot prove with this one phone:

- Backup restore onto a different iPhone omits the Trial marker while Film data travels (`TRI-11`, `ARC-11`, `ARC-12`, `QA-15`).
- A restored Trial Film coexists with the destination iPhone entitlement on a second physical iPhone (`TRI-02`, `TRI-03`, `QA-12`).
- iPhone 11/iOS 26 Development and Movie timing (`ARC-08`).
- Native Movie capture/render/export fidelity on hardware (`ARC-10`).
- OS update or erase behavior unless those destructive/device-changing actions are separately approved.

## Actions Outside This Approval

These actions still need separate explicit captain approval through Firstmate. Destructive whole-phone steps need a suitable non-personal or approved resettable environment.

- Install/launch/delete any app other than the approved probe, or run this procedure on another device.
- Change Apple account, certificates, provisioning, trust settings or device pairing, or use a different signing team. Selecting the existing team for the approved probe is already permitted.
- Back up iPhone A and restore onto iPhone B: outstanding for `ARC-11`, `ARC-12` and `QA-15`; destructive for the destination phone unless explicitly prepared.
- Erase all content and settings: outstanding for Keychain erase behavior; destructive and not authorized for a personal phone by availability alone.
- iOS update: needs permission because it changes a personal device.
- Any StoreKit sandbox/TestFlight/App Store exposure: not authorized by this plan.

## Outstanding Hardware Evidence

- `TRI-11`: not accepted until delete/reinstall and backup/restore expectations are observed on authorized iOS 26 hardware.
- `ARC-08`: not accepted until iPhone 11/iOS 26 timing is measured with the native app.
- `ARC-10`: not accepted until native Movie capture/render/export fidelity is observed on hardware.
- `ARC-11`: not accepted until the Trial first-save/reinstall/restore fault window is tested.
- `ARC-12` and `QA-15`: not accepted until real backup/restore behavior is tested in an authorized environment.
