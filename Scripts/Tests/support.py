"""Shared by the scripts' tests: a copy of Scripts in a temporary tree, with stand-ins for Xcode's tools on PATH."""
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIXTURES = os.path.join(ROOT, "Scripts", "Tests", "Fixtures")

# Stands in for `xcrun xcresulttool get test-results ...`, `xcrun simctl spawn <udid> log show ...` and
# `log show --archive ...`, answering from one fixture directory, and for the other `xcrun simctl` calls
# validation makes, which it only records.
TOOL = "#!" + sys.executable + r'''
import json, os, sys
fixture, arguments = os.environ["STUB_FIXTURE"], sys.argv[1:]
with open(os.path.join(os.environ["STUB_STATE"], "tool-calls"), "a") as calls:
    calls.write(os.path.basename(sys.argv[0]) + " " + " ".join(arguments) + "\n")
if "xcresulttool" in arguments:
    if "tests" in arguments:
        sys.stdout.write(open(os.path.join(fixture, "tests.json")).read())
    else:
        details = json.load(open(os.path.join(fixture, "test-details.json")))
        json.dump(details[arguments[arguments.index("--test-id") + 1]], sys.stdout)
elif "show" in arguments:
    if os.environ.get("STUB_LOG_FAILS"):
        sys.exit("log: could not open the log")
    sys.stdout.write(open(os.path.join(fixture, "simulator-log.ndjson")).read())
elif arguments[:2] == ["simctl", "ui"] and len(arguments) == 4:
    print({"appearance": "light", "content_size": "medium"}[arguments[3]])
elif arguments[0] != "simctl":
    sys.exit("unexpected tool call: " + " ".join(arguments))
'''

# Stands in for xcodebuild: records its arguments and exits with the next code of STUB_XCODEBUILD_EXITS.
XCODEBUILD = r'''#!/bin/sh
echo "$*" >> "$STUB_STATE/xcodebuild-calls"
echo "xcodebuild $*" >> "$STUB_STATE/commands"
count=$(wc -l < "$STUB_STATE/xcodebuild-calls" | tr -d ' ')
code=$(echo "$STUB_XCODEBUILD_EXITS" | cut -d' ' -f"$count")
exit "${code:-0}"
'''

# Stands in for a command validation runs for its own result, such as swift or one of the verify scripts: it
# records its name and arguments in the order validation ran them.
RECORDER = r'''#!/bin/sh
echo "$(basename "$0") $*" >> "$STUB_STATE/commands"
'''


class Sandbox:
    """A temporary tree holding a copy of Scripts, where the scripts under test write their DerivedData."""

    def __init__(self, test):
        self.tree = tempfile.mkdtemp()
        test.addCleanup(shutil.rmtree, self.tree)
        shutil.copytree(os.path.join(ROOT, "Scripts"), os.path.join(self.tree, "Scripts"),
                        ignore=shutil.ignore_patterns("Tests", "__pycache__"))
        self.state = os.path.join(self.tree, "state")
        self.tools = os.path.join(self.tree, "tools")
        os.makedirs(self.state)
        os.makedirs(self.tools)
        for name, text in (("xcrun", TOOL), ("log", TOOL), ("xcodebuild", XCODEBUILD), ("swift", RECORDER)):
            self.install(os.path.join(self.tools, name), text)

    def install(self, path, text):
        with open(path, "w") as file:
            file.write(text)
        os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC)

    def record_instead(self, *scripts):
        """Replaces scripts of the copy with stand-ins that record that validation ran them."""
        for script in scripts:
            self.install(self.path("Scripts", script), RECORDER)

    def path(self, *parts):
        return os.path.join(self.tree, *parts)

    def run(self, command, fixture, xcodebuild_exits="0", log_fails=False, environment=None):
        # Validation runs these tests itself, so its own part and simulators must not reach the copy under test.
        inherited = {name: value for name, value in os.environ.items() if not name.startswith("IMMERSE_")}
        environment = dict(inherited, PATH=self.tools + os.pathsep + os.environ["PATH"], STUB_STATE=self.state,
                           STUB_FIXTURE=fixture, STUB_XCODEBUILD_EXITS=xcodebuild_exits, **(environment or {}))
        if log_fails:
            environment["STUB_LOG_FAILS"] = "1"
        return subprocess.run(command, cwd=self.tree, env=environment, capture_output=True, text=True)

    def calls(self, name):
        path = os.path.join(self.state, name)
        if not os.path.exists(path):
            return []
        with open(path) as file:
            return file.read().splitlines()

    def fixture_without(self, fixture, identifier):
        """A copy of a fixture in which one failed test passed, leaving the others."""
        copy = tempfile.mkdtemp(dir=self.tree)
        for name in ("test-details.json", "simulator-log.ndjson"):
            shutil.copy(os.path.join(fixture, name), copy)
        with open(os.path.join(fixture, "tests.json")) as file:
            tests = json.load(file)

        def visit(node):
            if node.get("nodeIdentifier") == identifier:
                node["result"] = "Passed"
            for child in node.get("children", []):
                visit(child)

        for node in tests["testNodes"]:
            visit(node)
        with open(os.path.join(copy, "tests.json"), "w") as file:
            json.dump(tests, file)
        return copy


def fixture(name):
    return os.path.join(FIXTURES, "dropped-touch", name)
