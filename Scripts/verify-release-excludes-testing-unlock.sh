#!/bin/sh
# The Debug-only testing unlock (App/Immerse/Sources/TestingUnlock.swift) must be absent from
# Release, the configuration TestFlight and the App Store ship. Builds the app for devices in
# Debug and Release and searches each whole bundle for the unlock's type name, defaults key and
# copy: Debug must contain them, which shows the search can find them, and Release must not.
# Release must still contain its sibling `SubscriptionController`, so its names are searchable.
# The same search holds the Debug-only free-space reading that screen tests set
# (`DebugFreeSpace` in App/Immerse/Sources/LowStorage.swift) and the Debug-only preview of each
# saved capture (`DevelopedPreviews` in App/Immerse/Sources/DevelopedPreviews.swift, with its renderer
# `PreviewDevelopment` in Packages/FilmRuntime and the shooting screen's notice that it is on) and the
# photo view's hosted-test probe (`PhotoViewProbe` in App/Immerse/Sources/PhotoView.swift) and v2 Stage 1's stand-in
# server and Server checks (`DebugHosting.swift`, `ServerChecksView.swift`) and v2 Stage 2's stand-in for the event
# functions (`DebugGroupFilms.swift`) to Debug.
# The app alone also carries no App Clip in either configuration (v2 Stage 3): the mini-app is embedded only by the
# ImmerseWithClip scheme, whose own check is Scripts/verify-app-clip-size.sh.
set -eu
cd "$(dirname "$0")/.."
for configuration in Debug Release; do
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -configuration "$configuration" -destination 'generic/platform=iOS' \
        -derivedDataPath DerivedData/ValidationDevice CODE_SIGNING_ALLOWED=NO build
    bundle="DerivedData/ValidationDevice/Build/Products/$configuration-iphoneos/Immerse.app"
    test -d "$bundle"
    if [ -e "$bundle/AppClips" ]; then
        echo "$configuration bundle of the app alone carries an App Clip" >&2; exit 1
    fi
    if ! grep -rqaF SubscriptionController "$bundle"; then
        echo "$configuration bundle lacks SubscriptionController; the search cannot be trusted" >&2; exit 1
    fi
    for marker in TestingUnlock ImmerseDebugTestingUnlock "Testing unlock" DebugFreeSpace ImmerseDebugFreeSpace \
        DevelopedPreviews PreviewDevelopment ImmerseDebugDevelopedPreview "Develop at once" "Debug preview" \
        develop-at-once-notice PhotoViewProbe DebugHosting ImmerseDebugHosting ServerChecksView "Server checks" \
        DebugGroupFilms DebugEventBackend ImmerseDebugGroupFilm ImmerseDebugJoinLink; do
        if grep -rqaF "$marker" "$bundle"; then found=yes; else found=no; fi
        case "$configuration:$found" in
            Debug:no) echo "Debug bundle lacks \"$marker\"; the Release check cannot be trusted" >&2; exit 1 ;;
            Release:yes) echo "Release bundle contains Debug-only marker \"$marker\"" >&2; exit 1 ;;
        esac
    done
    echo "$configuration bundle: testing unlock, set free-space reading and capture previews $( [ "$configuration" = Debug ] && echo present || echo absent )"
done
