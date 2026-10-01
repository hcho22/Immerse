# Personal-Device Test Plan

This plan records the currently available hardware path for `TRI-11`.
Captain availability as of 2026-09-30: one personal iPhone target is available for review planning only.
That availability is not authorization to delete, erase, restore, change signing, change Apple account settings, buy anything, install, launch, or alter real personal media.

## Candidate Identity For Review

- Source branch: `fm/immerse-v1-implementation`
- Probe source revision under test: `6e5c1742d344e0505b74176f60ac11c19a83e686`
- Probe bundle identifier: `com.immerse.TrialKeychainProbe`
- Probe Keychain service: `com.immerse.trial-keychain-probe`
- Probe scheme: `TrialKeychainProbe`
- Xcode version recorded before review: `Xcode 26.5`, build `17F42`
- Captain-reported target device: iPhone 13, iOS 26.6.2
- Read-only Xcode discovery on 2026-09-30 local time: `HC_iPhone13`, available and paired, iPhone 13 Pro (`iPhone14,2`)
- Device identity confirmation needed before future approval: the captain reported iPhone 13, while read-only Xcode discovery saw a paired iPhone 13 Pro label. Future device approval must name the exact intended device.
- Signing team/profile: Apple development team is available, but selection or signing changes require explicit captain approval, not yet given; Firstmate will relay the approved scope.
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

## Prepared Probe Steps Awaiting Scoped Approval

These proposed steps are limited to the probe app, but availability alone authorizes none of them.
Do not install, sign, pair, trust, launch, delete, restore, erase or change settings on any personal iPhone until the candidate identity and prerequisites above are reviewed and the captain grants explicit scoped approval for the exact action and device. That approval has not been given; Firstmate will relay the approved scope.

1. Human selects the approved Apple development team/profile for `com.immerse.TrialKeychainProbe` on the named target only.
2. Build and install the probe on the approved iPhone 13/iOS 26.6.2 target.
3. Launch the probe.
4. Tap `Write fresh this-device-only marker`.
5. Record the marker UUID, timestamp, device model, iOS version, bundle identifier, Keychain service, source revision and Xcode build.
6. Force quit and relaunch the probe.
7. Tap `Read marker`. Expected: same marker found.
8. Tap `Mark consumed`.
9. Force quit and relaunch the probe.
10. Tap `Read marker`. Expected: same marker found with consumed state.
11. If and only if explicitly approved by the captain for this personal phone, delete only the probe app.
12. Reinstall the same bundle identifier from the same source revision.
13. Tap `Read marker`. Expected: same marker found with consumed state after delete/reinstall.

## Expected Evidence Packet

- Terminal transcript for the exact build command and Xcode version, including the signing-disabled generic physical-iOS build result above.
- Built artifact path and bundle/build identity from the candidate identity section.
- Screenshot or typed transcript of each probe screen after write, relaunch/read, consumed/read and approved reinstall/read.
- Device model and iOS version from Settings, Finder, Xcode Devices or `xcrun devicectl`.
- Device identity confirmation resolving the reported iPhone 13 versus read-only paired iPhone 13 Pro mismatch before any future device action.
- Statement that no Photos entries, StoreKit purchase, network service, app media, real personal media, Account or analytics were touched.
- If any step fails, stop and record the observed failure before changing the production Trial design.

## What This One Phone Can And Cannot Prove

Can prove on the approved iPhone 13/iOS 26.6.2 target:

- A this-device-only, non-synchronizable Keychain marker can be written and read by the probe.
- The marker survives app relaunch.
- If explicitly approved by the captain, the marker survives deletion and reinstall of only the probe app with the same bundle identifier.

Cannot prove with this one phone:

- Backup restore onto a different iPhone omits the Trial marker while Film data travels (`TRI-11`, `ARC-11`, `ARC-12`, `QA-15`).
- A restored Trial Film coexists with the destination iPhone entitlement on a second physical iPhone (`TRI-02`, `TRI-03`, `QA-12`).
- iPhone 11/iOS 26 Development and Movie timing (`ARC-08`).
- Native Movie capture/render/export fidelity on hardware (`ARC-10`).
- OS update or erase behavior unless those destructive/device-changing actions are separately approved.

## Steps Requiring Explicit Permission

These steps must not be performed merely because a personal iPhone exists.
Each needs explicit captain approval, not yet given, for the named device; Firstmate will relay the approved scope. Destructive whole-phone steps need a suitable non-personal or approved resettable environment.

- Build/install/launch on a personal iPhone: needed for the prepared probe path, but not authorized until the exact candidate, device and signing prerequisites are reviewed.
- Delete/reinstall on a personal iPhone: required for `TRI-11`; touches only the probe app, but still needs permission because it deletes an installed app from a personal phone.
- Change signing team, Apple account, provisioning, trust settings or device pairing: needs permission.
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
