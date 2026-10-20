#!/bin/sh
# Runs one set of screen tests on a simulator and keeps its result bundle, DerivedData/<name>-<time>.xcresult.
#
# Two failures that are nothing wrong in the app or the test are run once more, into a second result bundle
# (Scripts/rerun-tests.py, which holds the two records and their conditions; neither is widened and no third is
# added without the captain's word):
# - A dropped touch (the captain, 2026-10-13). The simulator's touch service now and then discards the rest of a
#   synthesized touch after its finger-down. The app gets a cancelled touch, never a tap, and the test whose tap it
#   was fails (Evidence/NativeApp/dropped-touch-059.md). The record is this simulator's own log holding that
#   discard inside the failed test's time window.
# - An animation stall (the captain, 2026-10-20). XCTest's wait for the app to stop animating never ends and the
#   test runs out of its allowance with the app idle (Evidence/NativeApp/main-ci-flakes-074.md). The record is the
#   result bundle's XCTest activity and the app's own log, both inside the failed test's time window.
# Only when every failed test has one of the two records are they all run, together and once, in one pass. Every
# other failure fails, a failed rerun fails, and a set that passed through a rerun says so here and in
# DerivedData/validation-notes.txt, naming each test and the record that excused it; Scripts/validate-local.sh
# prints that as it ends. Xcode's own retry flags are not used: they would rerun any failure.
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
proof="DerivedData/$name-$stamp-rerun-proof.txt"
if ! excused=$(python3 -B Scripts/rerun-tests.py "$bundle" --simulator "$udid" 2> "$proof"); then
    cat "$proof" >&2
    echo "screen-tests: $name failed, and the simulator's log and the result bundle do not excuse every failed test" >&2
    exit 1
fi
cat "$proof" >&2
if [ -z "$excused" ]; then
    echo "screen-tests: $name failed and no test was named for a rerun" >&2
    exit 1
fi
rerun="DerivedData/$name-rerun-$stamp.xcresult"
echo "screen-tests: running the excused tests once more, into $rerun" >&2
# shellcheck disable=SC2086 # the tests to rerun are flags
if ! xcodebuild -quiet "$@" -destination "platform=iOS Simulator,id=$udid" -resultBundlePath "$rerun" \
    $excused -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
    CODE_SIGNING_ALLOWED=NO test-without-building; then
    echo "screen-tests: the rerun failed too, so $name fails" >&2
    exit 1
fi
{
    echo "$name passed only after a rerun. Its first result is $bundle and the rerun is $rerun."
    cat "$proof"
} | tee -a DerivedData/validation-notes.txt >&2
