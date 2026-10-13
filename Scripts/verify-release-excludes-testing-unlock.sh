#!/bin/sh
# The Debug-only testing unlock (App/Immerse/Sources/TestingUnlock.swift) must be absent from
# Release, the configuration TestFlight and the App Store ship. Builds the app for devices in
# Debug and Release and searches each whole bundle for the unlock's type name, defaults key and
# copy: Debug must contain them, which shows the search can find them, and Release must not.
# Release must still contain its sibling `SubscriptionController`, so its names are searchable.
# The same search holds the Debug-only free-space reading that screen tests set
# (`DebugFreeSpace` in App/Immerse/Sources/LowStorage.swift) to Debug.
set -eu
cd "$(dirname "$0")/.."
for configuration in Debug Release; do
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -configuration "$configuration" -destination 'generic/platform=iOS' \
        -derivedDataPath DerivedData/ValidationDevice CODE_SIGNING_ALLOWED=NO build
    bundle="DerivedData/ValidationDevice/Build/Products/$configuration-iphoneos/Immerse.app"
    test -d "$bundle"
    if ! grep -rqaF SubscriptionController "$bundle"; then
        echo "$configuration bundle lacks SubscriptionController; the search cannot be trusted" >&2; exit 1
    fi
    for marker in TestingUnlock ImmerseDebugTestingUnlock "Testing unlock" DebugFreeSpace ImmerseDebugFreeSpace; do
        if grep -rqaF "$marker" "$bundle"; then found=yes; else found=no; fi
        case "$configuration:$found" in
            Debug:no) echo "Debug bundle lacks \"$marker\"; the Release check cannot be trusted" >&2; exit 1 ;;
            Release:yes) echo "Release bundle contains Debug-only marker \"$marker\"" >&2; exit 1 ;;
        esac
    done
    echo "$configuration bundle: testing unlock and set free-space reading $( [ "$configuration" = Debug ] && echo present || echo absent )"
done
