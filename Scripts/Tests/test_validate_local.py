"""Scripts/validate-local.sh: what each part runs, and that the four parts together run what the whole does."""
import os
import re
import sys
import unittest
from unittest import mock

from support import Sandbox, fixture

SIMULATORS = {"IMMERSE_WORKFLOW_SIMULATOR_UDID": "HARNESS-SIM", "IMMERSE_SIMULATOR_UDID": "APP-SIM",
              "IMMERSE_STOREKIT_SIMULATOR_UDID": "BILLING-SIM"}
APP = "-quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse"
ALLOWANCE = "-test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO"
SCREEN = APP + " -derivedDataPath DerivedData/ValidationSimulator -destination platform=iOS Simulator,id=APP-SIM"

MAC = [
    "python3 -B -m unittest discover -s Scripts/Tests",
    "verify-validation-parts.sh",
    "verify-requirement-map.sh",
    "swift test --package-path Packages/FilmDomain",
    "swift test --package-path Packages/MediaCatalog",
    "swift test --package-path Packages/RenderFixtures",
    "swift test --package-path Packages/RenderCore",
    "swift test --package-path Packages/FilmPersistence",
    "swift test --package-path Packages/NativeAdapters",
    "swift test --package-path Packages/EntitlementCore",
    "swift test --package-path Packages/FilmRuntime",
    "swift test --package-path Probes/TrialCommitStudy",
    "swift test --package-path Probes/DevelopmentProcessExit",
    "swift build --package-path Probes/AssetReviewGenerator",
    "verify-document-package.sh",
    "xcodebuild " + APP + " -destination generic/platform=iOS Simulator -derivedDataPath DerivedData/ValidationSimulator"
    " CODE_SIGNING_ALLOWED=NO build",
    "xcodebuild " + APP + " -destination generic/platform=iOS -derivedDataPath DerivedData/ValidationDevice"
    " CODE_SIGNING_ALLOWED=NO build",
    "verify-release-excludes-testing-unlock.sh",
]
HARNESS = [
    "quiet-simulator.sh HARNESS-SIM",
    "xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj"
    " -scheme PopulatedJournalHarness -derivedDataPath DerivedData/PopulatedJournalHarness"
    " -destination platform=iOS Simulator,id=HARNESS-SIM -resultBundlePath DerivedData/Populated-<time>.xcresult "
    + ALLOWANCE + " test",
]
PIN_APP = ["quiet-simulator.sh APP-SIM"]
RENDER = [
    "xcodebuild -quiet -scheme RenderCore -destination platform=iOS Simulator,id=APP-SIM"
    " -derivedDataPath ../../DerivedData/RenderCoreSimulator"
    " -resultBundlePath ../../DerivedData/RenderCore-<time>.xcresult -skip-testing:RenderCoreTests/LegacyLookTests"
    " -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 CODE_SIGNING_ALLOWED=NO test",
]


def light(selection):
    return ["xcodebuild " + SCREEN + " -resultBundlePath DerivedData/Validation-<time>.xcresult " + selection + " "
            + ALLOWANCE + " test"]


EVERY_SCREEN_SUITE = "-only-testing:ImmerseUITests"
TEXT_SIZES = "-only-testing:ImmerseUITests/ContentSizeTests"
OTHER_SUITES = "-only-testing:ImmerseUITests -skip-testing:ImmerseUITests/ContentSizeTests"
DARK = [
    "xcodebuild " + SCREEN + " -resultBundlePath DerivedData/ValidationDark-<time>.xcresult"
    " -only-testing:ImmerseUITests/JournalFlowTests -only-testing:ImmerseUITests/MovieCapacityUITests"
    " -only-testing:ImmerseUITests/FilmStockUITests -only-testing:ImmerseUITests/LowStorageUITests "
    + ALLOWANCE + " test-without-building",
]
# The billing simulator boots before the Mac tests, so its first-boot work is over when its tests run last.
BOOT_BILLING = ["quiet-simulator.sh BILLING-SIM"]
BILLING = [
    "xcodebuild " + APP + " -destination platform=iOS Simulator,id=BILLING-SIM"
    " -derivedDataPath DerivedData/ValidationSimulator -resultBundlePath DerivedData/StoreKit-<time>.xcresult"
    " -only-testing:ImmerseTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120"
    " CODE_SIGNING_ALLOWED=NO test",
]
VERSIONS = ["xcodebuild -version", "swift --version"]
WHOLE = VERSIONS + BOOT_BILLING + MAC + HARNESS + PIN_APP + RENDER + light(EVERY_SCREEN_SUITE) + DARK + BILLING
PARTS = {
    "packages": VERSIONS + BOOT_BILLING + MAC + PIN_APP + RENDER + BILLING,
    "harness": VERSIONS + HARNESS,
    "ui-text": VERSIONS + PIN_APP + light(TEXT_SIZES),
    "ui-flows": VERSIONS + PIN_APP + light(OTHER_SUITES) + DARK,
}


class ValidateLocalTests(unittest.TestCase):
    def validate(self, part=None, simulators=SIMULATORS, xcodebuild_exits="0", failures="harness-film-card-tap"):
        sandbox = Sandbox(self)
        sandbox.record_instead("verify-validation-parts.sh", "verify-requirement-map.sh", "verify-document-package.sh",
                               "verify-release-excludes-testing-unlock.sh", "quiet-simulator.sh")
        # The scripts' own tests are only recorded; the rerun check still runs for real.
        sandbox.install(os.path.join(sandbox.tools, "python3"), "#!/bin/sh\ncase \"$*\" in\n"
                        "    *unittest*) echo \"python3 $*\" >> \"$STUB_STATE/commands\" ;;\n"
                        "    *) exec \"%s\" \"$@\" ;;\nesac\n" % sys.executable)
        os.makedirs(sandbox.path("Packages", "RenderCore"))
        environment = dict(simulators)
        if part:
            environment["IMMERSE_VALIDATE_PART"] = part
        result = sandbox.run(["sh", "Scripts/validate-local.sh"], fixture(failures),
                             xcodebuild_exits=xcodebuild_exits, environment=environment)
        commands = [re.sub(r"\d{8}T\d{6}Z", "<time>", command).rstrip() for command in sandbox.calls("commands")]
        return result, commands

    def test_with_no_part_named_it_runs_everything_in_its_one_order(self):
        result, commands = self.validate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, WHOLE)

    def test_run_whole_on_one_simulator_it_pins_that_simulator_before_the_harness_and_before_the_app(self):
        # As the single job did, and as a run on a Mac with one simulator does.
        shared = dict(SIMULATORS, IMMERSE_WORKFLOW_SIMULATOR_UDID="APP-SIM")
        result, commands = self.validate(simulators=shared)
        self.assertEqual(result.returncode, 0, result.stderr)
        harness = [command.replace("HARNESS-SIM", "APP-SIM") for command in HARNESS]
        self.assertEqual(commands, VERSIONS + BOOT_BILLING + MAC + harness + PIN_APP + RENDER + light(EVERY_SCREEN_SUITE) + DARK + BILLING)

    def test_each_part_runs_its_own_share(self):
        for part, expected in PARTS.items():
            with self.subTest(part):
                result, commands = self.validate(part)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(commands, expected)

    def test_the_four_parts_together_run_what_the_whole_runs(self):
        setup = set(VERSIONS + PIN_APP)
        whole = [command for command in WHOLE if command not in setup]
        parts = [command for expected in PARTS.values() for command in expected if command not in setup]
        self.assertEqual(len(parts), len(set(parts)), "no test run belongs to two parts")
        # The whole runs the app's screen tests in one run; ui-text and ui-flows split that run by suite.
        self.assertEqual(set(whole) - set(parts), set(light(EVERY_SCREEN_SUITE)))
        self.assertEqual(set(parts) - set(whole), set(light(TEXT_SIZES) + light(OTHER_SUITES)))

    def test_run_whole_without_simulators_it_runs_the_mac_share_alone(self):
        result, commands = self.validate(simulators={})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, VERSIONS + MAC)

    def test_the_part_and_simulators_of_the_job_running_these_tests_do_not_reach_them(self):
        # The packages part runs these tests with its own part and simulators in the environment.
        job = {"IMMERSE_VALIDATE_PART": "packages", "IMMERSE_SIMULATOR_UDID": "JOB-SIM",
               "IMMERSE_STOREKIT_SIMULATOR_UDID": "JOB-BILLING-SIM"}
        with mock.patch.dict(os.environ, job):
            result, commands = self.validate(simulators={})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, VERSIONS + MAC)

    def test_a_named_part_refuses_to_run_without_its_simulator(self):
        for part, missing in (("packages", "IMMERSE_STOREKIT_SIMULATOR_UDID"), ("harness", "IMMERSE_WORKFLOW_SIMULATOR_UDID"),
                              ("ui-text", "IMMERSE_SIMULATOR_UDID"), ("ui-flows", "IMMERSE_SIMULATOR_UDID")):
            with self.subTest(part):
                simulators = {name: udid for name, udid in SIMULATORS.items() if name != missing}
                result, commands = self.validate(part, simulators=simulators)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("the %s part needs %s" % (part, missing), result.stderr)
                self.assertEqual(commands, [])

    def test_an_unknown_part_is_refused(self):
        result, commands = self.validate("ui")
        self.assertEqual(result.returncode, 2)
        self.assertIn('unknown IMMERSE_VALIDATE_PART "ui"', result.stderr)
        self.assertEqual(commands, [])

    def test_a_failure_no_record_excuses_stops_validation_there(self):
        # Run whole, the harness run is the fourth xcodebuild call, after the version and the two app builds.
        result, commands = self.validate(xcodebuild_exits="0 0 0 65", failures="app-start-a-film-tap-and-a-timeout")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Populated failed, and the simulator's log and the result bundle do not excuse every failed test", result.stderr)
        self.assertEqual(commands, VERSIONS + BOOT_BILLING + MAC + HARNESS)

    def test_a_run_that_passed_through_a_rerun_says_so_last(self):
        sandbox_result, commands = self.validate("harness", xcodebuild_exits="0 65 0")
        self.assertEqual(sandbox_result.returncode, 0, sandbox_result.stderr)
        self.assertEqual(len([command for command in commands if "Populated-" in command]), 2)
        said = sandbox_result.stdout.strip().splitlines()
        self.assertEqual(said[-3], "Validation notes:")
        self.assertIn("Populated passed only after a rerun", said[-2])
        self.assertIn("dropped touch: PopulatedWorkflowTests/testSixBySixBlackAndWhiteLookScreens()", said[-1])


if __name__ == "__main__":
    unittest.main()
