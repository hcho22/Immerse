# Personal-Device Test Plan

This plan records the currently available hardware path for `TRI-11`.
Captain availability as of 2026-09-30: only personal iPhones are available.
That availability is not authorization to delete, erase, restore, change signing, change Apple account settings, buy anything, or alter real personal media.

## Unfilled Execution Fields

These fields must be filled for an exact reviewable candidate before Firstmate/captain is asked to approve any device action.

- Source branch: unfilled; expected `fm/immerse-v1-implementation`
- Source revision: unfilled; fill with `git rev-parse HEAD` for the tested candidate
- Probe bundle identifier: unfilled; expected `com.immerse.TrialKeychainProbe`
- Probe Keychain service: unfilled; expected `com.immerse.trial-keychain-probe`
- Probe scheme: unfilled; expected `TrialKeychainProbe`
- Build command: unfilled; expected `xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS' build`
- Xcode version: unfilled; fill with `xcodebuild -version`
- Device model and iOS version: unfilled; fill from Xcode Devices and Settings, Finder, or `xcrun devicectl list devices`
- Signing team/profile: unfilled; selected only by a human with authority

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
Do not install, sign, pair, trust, launch, delete, restore, erase or change settings on any personal iPhone until the unfilled execution fields above are reviewable and Firstmate/captain grants scoped approval for the exact action and device.

1. Build and install the probe on one named personal iPhone running iOS 26.
2. Tap `Write fresh this-device-only marker`.
3. Record the marker UUID, date, device model, iOS version and candidate revision.
4. Force quit and relaunch the probe.
5. Tap `Read marker`. Expected: same marker found.
6. Tap `Mark consumed`.
7. Force quit and relaunch the probe.
8. Tap `Read marker`. Expected: same marker found with consumed state.

## Steps Requiring Explicit Permission

These steps must not be performed merely because a personal iPhone exists.
Each needs separate concrete authority from Firstmate/captain for the named device, and destructive whole-phone steps need a suitable non-personal or approved resettable environment.

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
