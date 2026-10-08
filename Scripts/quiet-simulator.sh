#!/bin/sh
# Boots the given simulator if needed, waits for it, and switches off its photo-analysis
# service (mediaanalysisd), which otherwise analyzes the photos tests seed at several hundred
# percent CPU for hours. Only the user/foreground domain stops it (the system/ form just
# restarts it), and the disable lasts until the simulator is erased. photoanalysisd stayed
# idle on iOS 26.5, so it is left alone. Idempotent; never fails the caller.
# Usage: sh Scripts/quiet-simulator.sh <udid>
set -u
udid=${1:?usage: quiet-simulator.sh <udid>}
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
