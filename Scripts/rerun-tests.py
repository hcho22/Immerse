#!/usr/bin/env python3
"""Names the failed screen tests of a result bundle that Scripts/screen-tests.sh may run once more.

Two records excuse a failed test, and nothing else does (the captain, 2026-10-13 for the first, 2026-10-20 for the
second); neither is widened, and no third is added, without his word.

- A dropped touch (Scripts/dropped-touch-tests.py, Evidence/NativeApp/dropped-touch-059.md): the simulator's log holds
  one of backboardd's discards of a touch event inside the failed test's own time window.
- An animation stall (Evidence/NativeApp/main-ci-flakes-074.md, after 069 and 073): XCTest's wait for the app to stop
  animating never ended, so the test ran out of its allowance with the app idle. All three must hold for the one test:
  its failure is only XCTest's "Test exceeded execution time allowance"; XCTest's activity "App animations complete
  notification not received, will attempt to continue." lies inside the test's window; and the app's own log for
  that launch (the result bundle's exported diagnostics) holds a "Received request to notify when animations are
  idle", inside the window, with no "Sending animations idle reply" after it. Half of that excuses nothing.

usage: rerun-tests.py <result.xcresult> (--simulator <udid> | --archive <system.logarchive>)

Says on standard error what it found for each failed test. When every failed test has one of the two records, prints
an -only-testing flag for each on standard output and exits 0, which is Scripts/screen-tests.sh's leave to run those
tests once more, together. Exits 1 when a failed test has neither, when nothing failed, or when the bundle cannot be
read: without proof there is no rerun.
"""
import datetime
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

STALL_WAIT = "App animations complete notification not received, will attempt to continue."
ALLOWANCE = "Test exceeded execution time allowance"
APP_LOG_HEADER = "Standard output and standard error from "
REQUEST = "Received request to notify when animations are idle"
REPLY = "Sending animations idle reply"
# The app's threads now and then write a line into the middle of another's, so a line can begin with a piece of
# another's timestamp, or with none.
STAMP = re.compile(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+[+-]\d{4}) \S+\[\d+:\w+\] ")


def sibling(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), os.path.join(os.path.dirname(__file__), name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


dropped = sibling("dropped-touch-tests")


def failure_messages(bundle, identifier):
    """What each failure of the test says: the name of each of its failed Test Case Run nodes."""
    messages = []

    def visit(node):
        if node.get("nodeType") == "Test Case Run" and node.get("result") == "Failed":
            messages.append(node.get("name", ""))
        for child in node.get("children", []):
            visit(child)

    details = dropped.result_bundle(bundle, "test-details", "--test-id", identifier)
    for run in details.get("testRuns", []):
        visit(run)
    return messages


def stalled_waits(bundle, identifier):
    """When XCTest gave up waiting for the app's animations, from the test's activities."""
    moments = []

    def visit(activity):
        if activity.get("title") == STALL_WAIT:
            moments.append(float(activity["startTime"]))
        for child in activity.get("childActivities", []):
            visit(child)

    activities = dropped.result_bundle(bundle, "activities", "--test-id", identifier)
    for run in activities.get("testRuns", []):
        for activity in run.get("activities", []):
            visit(activity)
    return moments


def unanswered_requests(path):
    """When the app was asked whether its animations were idle and never said so afterwards, in one app log.

    The log holds one section per launch of the app. A reply ends every request before it in its section, since
    the app sends one only when its animation count comes back to zero.
    """
    moments = []
    pending = []
    with open(path, errors="replace") as log:
        for line in log:
            if line.startswith(APP_LOG_HEADER):
                moments += pending
                pending = []
            elif REQUEST in line:
                # A request whose line lost its timestamp cannot be placed in any test's window, so it proves nothing.
                stamp = STAMP.search(line)
                if stamp:
                    pending.append(datetime.datetime.strptime(stamp.group(1), "%Y-%m-%d %H:%M:%S.%f%z").timestamp())
            elif REPLY in line:
                pending = []
    return moments + pending


class AppLogs:
    """The unanswered animation requests of the bundle's apps, read from its exported diagnostics once, when asked."""

    def __init__(self, bundle):
        self.bundle = bundle
        self.moments = None

    def unanswered(self):
        if self.moments is None:
            with tempfile.TemporaryDirectory() as directory:
                command = ["xcrun", "xcresulttool", "export", "diagnostics", "--path", self.bundle, "--output-path", directory]
                subprocess.run(command, capture_output=True, text=True, check=True)
                self.moments = []
                for folder, _, names in os.walk(directory):
                    for name in names:
                        # The runner's own log has no bundle identifier in its name.
                        if name.startswith("StandardOutputAndStandardError-") and name.endswith(".txt"):
                            self.moments += unanswered_requests(os.path.join(folder, name))
        return self.moments


def stall(test, bundle, app_logs):
    """(message, True) for a test the animation stall failed, else (the reason it was not, False)."""
    identifier = test["identifier"]
    first, last = test["start"] - dropped.CLOCK_SLACK, test["end"] + dropped.CLOCK_SLACK
    window = "the test's run from %s to %s" % (dropped.clock(test["start"]), dropped.clock(test["end"]))
    messages = failure_messages(bundle, identifier)
    if not messages or not all(message.startswith(ALLOWANCE) for message in messages):
        return "its failure is not only the time allowance", False
    waits = [moment for moment in stalled_waits(bundle, identifier) if first <= moment <= last]
    if not waits:
        return "XCTest recorded no unanswered wait for the app's animations inside %s" % window, False
    requests = [moment for moment in app_logs.unanswered() if first <= moment <= last]
    if not requests:
        return "the app's log holds no animation-idle request without a reply inside %s" % window, False
    return ("animation stall: %s. The test ended at its time allowance. XCTest gave up waiting for the app's animations "
            "at %s and the app never replied to its request at %s, inside %s."
            % (identifier, dropped.clock(waits[0]), dropped.clock(requests[0]), window)), True


def main(arguments):
    if len(arguments) != 3 or arguments[1] not in ("--simulator", "--archive"):
        sys.exit(__doc__)
    bundle, source, path = arguments
    try:
        failed = dropped.failed_tests(bundle)
    except (subprocess.CalledProcessError, OSError, ValueError, KeyError, IndexError) as error:
        print("no rerun: could not read %s (%s)" % (bundle, error), file=sys.stderr)
        return 1
    if not failed:
        print("no rerun: %s holds no failed test, so its failure is not a test's" % bundle, file=sys.stderr)
        return 1
    try:
        discarded = dropped.discards(source, path, min(test["start"] for test in failed))
        unreadable = None
    except (subprocess.CalledProcessError, OSError, ValueError, KeyError, IndexError) as error:
        discarded, unreadable = [], error
    app_logs = AppLogs(bundle)
    proven = True
    for test in failed:
        message = dropped.excuse(test, discarded)
        if message:
            print(message, file=sys.stderr)
            continue
        if unreadable:
            refusal = "no dropped touch: %s. Could not read the simulator's log (%s)." % (test["identifier"], unreadable)
        else:
            refusal = dropped.refusal(test)
        try:
            message, excused = stall(test, bundle, app_logs)
        except (subprocess.CalledProcessError, OSError, ValueError, KeyError, IndexError) as error:
            message, excused = "could not read the bundle's diagnostics (%s)" % error, False
        if excused:
            print(message, file=sys.stderr)
        else:
            proven = False
            print(refusal, file=sys.stderr)
            print("no animation stall: %s. %s, so its failure stands." % (test["identifier"], message), file=sys.stderr)
    if not proven:
        return 1
    for test in failed:
        print("-only-testing:" + test["selection"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
