#!/bin/sh
# Regenerates the app icon's three appearances from tilted-spread.svg, the captain's chosen master.
# Needs rsvg-convert (Homebrew librsvg) and Xcode's swift.
# Usage: sh Evidence/NativeApp/app-icon-083/make-app-icon.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
iconset="$root/App/Immerse/Sources/Assets.xcassets/AppIcon.appiconset"
master="$here/tilted-spread.svg"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The master's paper palette: film #1B1A18, paper #F1EADB, gutter and lines #B9AE98.
grep -q '#1B1A18' "$master"
grep -q '#F1EADB' "$master"
grep -q '#B9AE98' "$master"

# Dark: the film is left transparent, so iOS draws its dark background behind the pages,
# and the paper and its lines are dimmed a step so the pages do not glare at night.
sed \
    -e 's|<rect x="0" y="0" width="1024" height="1024" fill="#1B1A18"></rect>||' \
    -e 's|<rect x="-300" y="-200" width="1624" height="1424" fill="#1B1A18"></rect>||' \
    -e 's|#F1EADB|#E2D9C6|g' \
    -e 's|#B9AE98|#A39883|g' \
    "$master" > "$here/tilted-spread-dark.svg"
if grep -q '#1B1A18' "$here/tilted-spread-dark.svg"; then
    echo "the dark appearance still draws the film" >&2
    exit 1
fi

# Tinted: grayscale on black, which iOS tints; the pages are white, the lines a mid gray.
sed \
    -e 's|#1B1A18|#000000|g' \
    -e 's|#F1EADB|#FFFFFF|g' \
    -e 's|#B9AE98|#A0A0A0|g' \
    "$master" > "$here/tilted-spread-tinted.svg"

rsvg-convert -w 1024 -h 1024 "$master" -o "$work/light.png"
rsvg-convert -w 1024 -h 1024 "$here/tilted-spread-dark.svg" -o "$iconset/AppIcon-Dark.png"
rsvg-convert -w 1024 -h 1024 "$here/tilted-spread-tinted.svg" -o "$work/tinted.png"

# The light and tinted icons are opaque, so they are written without an alpha channel.
xcrun swift "$here/flatten.swift" "$work/light.png" "$iconset/AppIcon.png"
xcrun swift "$here/flatten.swift" "$work/tinted.png" "$iconset/AppIcon-Tinted.png"

for name in AppIcon AppIcon-Dark AppIcon-Tinted; do
    sips -g pixelWidth -g pixelHeight -g hasAlpha "$iconset/$name.png" | tail -3
done
