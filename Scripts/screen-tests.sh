#!/bin/sh
# Runs one set of screen tests on a simulator and keeps its result bundle, DerivedData/<name>-<time>.xcresult.
#
# The simulator's touch service now and then discards the rest of a synthesized touch after its finger-down. The
# app gets a cancelled touch, never a tap, and the test whose tap it was fails with nothing wrong in the app or the
# test (Evidence/NativeApp/dropped-touch-059.md). So a failed test is run once more, alone, into a second result
# bundle, only when this simulator's own log holds that discard inside the failed test's time window
# (Scripts/dropped-touch-tests.py). Every other failure fails, a failed rerun fails, and a set that passed through
# a rerun says so here and in DerivedData/validation-notes.txt, which Scripts/validate-local.sh prints as it ends.
# Xcode's own retry flags are not used: they would rerun any failure.
#
# Usage: sh Scripts/screen-tests.sh <udid> <name> <test|test-without-building> "<test selection flags>" <xcodebuild arguments>
set -eu
cd "$(dirname "$0")/.."
udid=$1 name=$2 action=$3 selection=$4
shift 4
mkdir -p DerivedData
stamp=$(date -u +%Y%m%dT%H%M%SZ)
bundle="DerivedData/$name-$stamp.xcresult"
# shellcheck disable=SC2086 # the selection is flags
if xcodebuild -quiet "$@" -destination "platform=iOS Simulator,id=$udid" -resultBundlePath "$bundle" \
    $selection -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
    CODE_SIGNING_ALLOWED=NO "$action"; then
    exit 0
fi
proof="DerivedData/$name-$stamp-dropped-touches.txt"
if ! dropped=$(python3 -B Scripts/dropped-touch-tests.py "$bundle" --simulator "$udid" 2> "$proof"); then
    cat "$proof" >&2
    echo "screen-tests: $name failed, and the simulator's log does not excuse every failed test" >&2
    exit 1
fi
cat "$proof" >&2
if [ -z "$dropped" ]; then
    echo "screen-tests: $name failed and no test was named for a rerun" >&2
    exit 1
fi
rerun="DerivedData/$name-rerun-$stamp.xcresult"
echo "screen-tests: running the tests whose touch the simulator dropped once more, into $rerun" >&2
# shellcheck disable=SC2086 # the tests to rerun are flags
if ! xcodebuild -quiet "$@" -destination "platform=iOS Simulator,id=$udid" -resultBundlePath "$rerun" \
    $dropped -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
    CODE_SIGNING_ALLOWED=NO test-without-building; then
    echo "screen-tests: the rerun failed too, so $name fails" >&2
    exit 1
fi
{
    echo "$name passed only after a rerun. Its first result is $bundle and the rerun is $rerun."
    cat "$proof"
} | tee -a DerivedData/validation-notes.txt >&2
