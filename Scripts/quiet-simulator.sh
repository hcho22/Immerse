#!/bin/sh
# Boots the given simulator if needed, waits for it, and switches off two background jobs that tests never need:
#
# - Its photo-analysis service (mediaanalysisd), which otherwise analyzes the photos tests seed at several hundred
#   percent CPU for hours. Only the user/foreground domain stops it (the system/ form just restarts it), and the
#   disable lasts until the simulator is erased. photoanalysisd stayed idle on iOS 26.5, so it is left alone.
# - trustd's update of its certificate revocation database, a download and rebuild of one to four minutes that starts
#   soon after a new simulator boots; tests need no revocation data. The preference is written into the simulator's
#   own data before it boots, because trustd reads it before this script could reach a running simulator. trustd's
#   install of the trust data it downloads at first boot cannot be switched off; validation boots the billing
#   simulator early instead (Evidence/NativeApp/main-ci-flakes-066.md).
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
# EXPERIMENT B: the simulator's launchd keeps its disabled services in this file, read at boot; apsd's retry loop
# (3.1 million of 5.8 million log lines on CI) never starts if it is disabled before the first boot.
if [ -n "$data" ]; then
    python3 - "$udid" << 'PY' > /dev/null 2>&1 || echo "quiet-simulator: could not disable apsd before booting $udid"
import os, plistlib, sys
directory = "/var/tmp/com.apple.CoreSimulator.SimDevice." + sys.argv[1]
os.makedirs(directory, mode=0o700, exist_ok=True)
path = directory + "/disabled.plist"
disabled = plistlib.load(open(path, "rb")) if os.path.exists(path) else {}
disabled["com.apple.apsd"] = True
plistlib.dump(disabled, open(path, "wb"))
PY
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
