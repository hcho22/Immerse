#!/bin/sh
# Boots the given simulator if needed, waits for it, and switches off two background jobs that tests never need:
#
# - Its photo-analysis service (mediaanalysisd), which otherwise analyzes the photos tests seed at several hundred
#   percent CPU for hours. Only the user/foreground domain stops it (the system/ form just restarts it), and the
#   disable lasts until the simulator is erased. photoanalysisd stayed idle on iOS 26.5, so it is left alone.
# - trustd's update of its certificate revocation database, which starts seconds after a new simulator boots. On CI
#   it held every trust check in the simulator for two minutes, in which StoreKit's local test server could not sign
#   an approved purchase, so the update a test waited for came late (Evidence/NativeApp/main-ci-flakes-066.md). The
#   preference is written into the simulator's own data before it boots, because trustd reads it before this script
#   could reach a running simulator.
#
# Idempotent; never fails the caller.
# Usage: sh Scripts/quiet-simulator.sh <udid>
set -u
udid=${1:?usage: quiet-simulator.sh <udid>}
data=$(xcrun simctl list devices -j 2> /dev/null | python3 -c '
import json, sys
udid = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["udid"] == udid and device["state"] == "Shutdown":
            print(device["dataPath"])
' "$udid" 2> /dev/null)
# The file itself, since the Mac's `defaults write` to a path left nothing there before the boot.
if [ -n "$data" ]; then
    preferences="$data/Library/Preferences/com.apple.security.plist"
    { mkdir -p "$data/Library/Preferences" && { [ -f "$preferences" ] || plutil -create binary1 "$preferences"; } \
        && plutil -replace ValidUpdateEnabled -bool NO "$preferences"; } > /dev/null 2>&1 \
        || echo "quiet-simulator: could not switch off trustd's revocation update before booting $udid"
fi
if ! xcrun simctl bootstatus "$udid" -b > /dev/null 2>&1; then
    echo "quiet-simulator: $udid did not boot; photo analysis left as is"
    exit 0
fi
service=user/foreground/com.apple.mediaanalysisd
xcrun simctl spawn "$udid" launchctl disable "$service" > /dev/null 2>&1 \
    || echo "quiet-simulator: could not disable mediaanalysisd on $udid"
xcrun simctl spawn "$udid" launchctl bootout "$service" > /dev/null 2>&1 \
    || echo "quiet-simulator: mediaanalysisd already off or absent on $udid"
exit 0
