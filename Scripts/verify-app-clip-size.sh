#!/bin/sh
# Holds the mini-app (the App Clip, v2 PRD V2-FR-19) under Apple's size limit, as open check OC-1 measured it.
#
# Apple caps a QR-opened App Clip on iOS 26 at 15 MB, counted as the uncompressed App Clip bundle of each thinned
# variant ("Choosing the right functionality for your App Clip"; App Store Connect Help, "Maximum build file sizes").
# This archives the app with the App Clip inside it (the ImmerseWithClip scheme) for devices in Release, thins the
# archive with ipatool, the App Store thinning tool that ships in Xcode and that Xcode's own export runs, and sums the
# files of the App Clip in every variant. It fails when any variant is over the budget below.
#
# The budget is 12,000,000 bytes, not the cap of 15,000,000: the archive is unsigned, because a signed App Clip needs an
# App ID and a provisioning profile nobody has made yet, and a signature and profile add under 0.1 MB; the rest of the
# margin is room to grow without meeting the cap by surprise. Before the first App Store submission the same figure is
# read from Xcode's App Thinning Size Report on a signed export (Evidence/NativeApp/manual-validation.md).
#
# It also holds what must not be in the shipped App Clip: the Debug-only stand-ins, and any sign-in SDK.
set -eu
cd "$(dirname "$0")/.."
cap=15000000
budget=${IMMERSE_APP_CLIP_BUDGET_BYTES:-12000000}
work=DerivedData/AppClipSize
developer=$(xcode-select -p)
rm -rf "${work:?}/Immerse.xcarchive" "${work:?}/ipa" "${work:?}/thinned" "${work:?}/thinning"
mkdir -p "$work/ipa/Payload"
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme ImmerseWithClip -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$work/DerivedData" \
    -archivePath "$work/Immerse.xcarchive" CODE_SIGNING_ALLOWED=NO archive
app=$(find "$work/Immerse.xcarchive/Products/Applications" -maxdepth 1 -name '*.app' | head -n 1)
clip="$app/AppClips/ImmerseClip.app"
if [ ! -d "$clip" ]; then
    echo "verify-app-clip-size: the archive holds no App Clip at AppClips/ImmerseClip.app" >&2; exit 1
fi
# The shipped App Clip carries none of the Debug-only stand-ins and no sign-in SDK. Its own Group Film code is there,
# which shows the search can find a name.
if ! grep -rqaF GroupFilmEventView "$clip"; then
    echo "verify-app-clip-size: the App Clip lacks GroupFilmEventView; the search cannot be trusted" >&2; exit 1
fi
for marker in DebugGroupFilms DebugEventBackend DebugHosting ImmerseDebugGroupFilm ImmerseDebugHosting \
    DevelopedPreviews TestingUnlock ClerkKit ClerkHostSignIn; do
    if grep -rqaF "$marker" "$clip"; then
        echo "verify-app-clip-size: the Release App Clip contains \"$marker\"" >&2; exit 1
    fi
done
cp -R "$app" "$work/ipa/Payload/"
(cd "$work/ipa" && zip -qry Immerse.ipa Payload)
"$developer/usr/bin/ipatool" "$work/ipa/Immerse.ipa" --create-thinned=all --output="$work/thinned" \
    --tmpdir="$work/thinning" --toolchain="$developer/Toolchains/XcodeDefault.xctoolchain/usr" \
    --platforms="$developer/Platforms" --json="$work/thinning.json" > "$work/ipatool.log" 2>&1 || {
    cat "$work/ipatool.log" >&2; echo "verify-app-clip-size: ipatool could not thin the archive" >&2; exit 1
}
largest=0
variants=0
# ipatool writes each thinned variant, and the universal one, as a folder holding its Payload.
for variant in "$work"/thinned/*/; do
    name=$(basename "$variant")
    thinned=$(find "$variant/Payload" -maxdepth 3 -type d -path '*/AppClips/ImmerseClip.app' | head -n 1)
    if [ -z "$thinned" ]; then
        echo "verify-app-clip-size: variant $name holds no App Clip" >&2; exit 1
    fi
    bytes=$(find "$thinned" -type f -exec stat -f %z {} + | awk '{ sum += $1 } END { print sum + 0 }')
    variants=$((variants + 1))
    [ "$bytes" -le "$largest" ] || largest=$bytes
    echo "App Clip, variant $name: $bytes bytes uncompressed"
done
if [ "$variants" -eq 0 ]; then
    echo "verify-app-clip-size: ipatool made no variant" >&2; exit 1
fi
echo "App Clip: largest of $variants thinned variants is $largest bytes; budget $budget, Apple's cap $cap ($((cap - largest)) bytes under the cap)"
if [ "$largest" -gt "$budget" ]; then
    echo "verify-app-clip-size: the App Clip is over its budget of $budget bytes (Apple's cap is $cap)" >&2; exit 1
fi
