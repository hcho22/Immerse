#!/usr/bin/env python3
"""Names the failed screen tests of a result bundle that the simulator failed by dropping a touch.

XCTest sends each synthesized touch through a virtual touchscreen it attaches for that one gesture. The
simulator's touch service, backboardd, now and then takes the touchscreen's first event before it has registered
the touchscreen. It then records the finger-down in one place, looks for it in another, and discards the events
that follow, the finger-up among them: "didn't see a previous touch down or range-in event for pathIndex:2;
skipping event". The app gets a cancelled touch, never a tap, and the test whose tap it was fails
(Evidence/NativeApp/dropped-touch-059.md).

usage: dropped-touch-tests.py <result.xcresult> (--simulator <udid> | --archive <system.logarchive>)

Says on standard error what it found for each failed test. When every failed test has one of backboardd's
discards inside its own time window, prints an -only-testing flag for each on standard output and exits 0, which
is Scripts/screen-tests.sh's leave to run those tests once more. Exits 1 when a failed test has no discard, when
nothing failed, or when the bundle or the log cannot be read: without proof there is no rerun.
"""
import datetime
import json
import math
import subprocess
import sys
import time

DISCARD = "didn't see a previous touch down or range-in event"
PREDICATE = ('process == "backboardd" AND subsystem == "com.apple.BackBoard" AND category == "TouchEvents" '
             'AND (eventMessage CONTAINS "skipping event" OR eventMessage CONTAINS "unknown digitizer")')
# The result bundle stamps a test's start a moment after the log stamps the same instant.
CLOCK_SLACK = 1.0


def result_bundle(bundle, *query):
    """One `xcresulttool get test-results` answer about the bundle."""
    command = ["xcrun", "xcresulttool", "get", "test-results", *query, "--path", bundle]
    return json.loads(subprocess.run(command, capture_output=True, text=True, check=True).stdout)


def failed_tests(bundle):
    """Each failed test's identifier, -only-testing name and time window."""
    identifiers = []

    def visit(node):
        if node.get("nodeType") == "Test Case" and node.get("result") == "Failed":
            identifiers.append(node["nodeIdentifier"])
        for child in node.get("children", []):
            visit(child)

    for node in result_bundle(bundle, "tests")["testNodes"]:
        visit(node)
    tests = []
    for identifier in identifiers:
        details = result_bundle(bundle, "test-details", "--test-id", identifier)
        # test://com.apple.xcode/<project>/<target>/<suite>/<test>
        target_suite_test = details["testIdentifierURL"].split("/", 4)[4]
        start = float(details["startTime"])
        tests.append({"identifier": identifier, "selection": target_suite_test,
                      "start": start, "end": start + float(details["durationInSeconds"])})
    return tests


def discards(source, path, earliest):
    """When backboardd discarded a touch event, from a booted simulator's log or a collected log archive."""
    if source == "--simulator":
        minutes = max(2, math.ceil((time.time() - earliest) / 60) + 1)
        command = ["xcrun", "simctl", "spawn", path, "log", "show", "--last", "%dm" % minutes]
    else:
        command = ["log", "show", "--archive", path]
    command += ["--style", "ndjson", "--predicate", PREDICATE]
    output = subprocess.run(command, capture_output=True, text=True, check=True).stdout
    times = []
    for line in output.splitlines():
        if not line.startswith("{"):
            continue
        entry = json.loads(line)
        if DISCARD in entry.get("eventMessage", ""):
            stamp = datetime.datetime.strptime(entry["timestamp"], "%Y-%m-%d %H:%M:%S.%f%z")
            times.append(stamp.timestamp())
    return times


def clock(moment):
    return datetime.datetime.fromtimestamp(moment, datetime.timezone.utc).strftime("%H:%M:%S UTC")


def main(arguments):
    if len(arguments) != 3 or arguments[1] not in ("--simulator", "--archive"):
        sys.exit(__doc__)
    bundle, source, path = arguments
    try:
        failed = failed_tests(bundle)
        if not failed:
            print("no dropped touch: %s holds no failed test, so its failure is not a test's" % bundle, file=sys.stderr)
            return 1
        discarded = discards(source, path, min(test["start"] for test in failed))
    except (subprocess.CalledProcessError, OSError, ValueError, KeyError, IndexError) as error:
        print("no dropped touch: could not read %s or the simulator's log (%s)" % (bundle, error), file=sys.stderr)
        return 1
    proven = True
    for test in failed:
        inside = [moment for moment in discarded if test["start"] - CLOCK_SLACK <= moment <= test["end"] + CLOCK_SLACK]
        if inside:
            print("dropped touch: %s. The simulator discarded %d touch event%s at %s, inside the test's run from %s to %s."
                  % (test["identifier"], len(inside), "" if len(inside) == 1 else "s", clock(inside[0]),
                     clock(test["start"]), clock(test["end"])), file=sys.stderr)
        else:
            proven = False
            print("no dropped touch: %s. The simulator's log holds no discarded touch event in the test's run from %s to %s, so its failure stands."
                  % (test["identifier"], clock(test["start"]), clock(test["end"])), file=sys.stderr)
    if not proven:
        return 1
    for test in failed:
        print("-only-testing:" + test["selection"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
