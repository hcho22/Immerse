"""Scripts/screen-tests.sh: a failed screen test is run once more only on the simulator's proof of a dropped touch."""
import os
import unittest

from support import Sandbox, fixture

HARNESS = ["sh", "Scripts/screen-tests.sh", "FAKE-UDID", "Populated", "test", "",
           "-project", "Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj",
           "-scheme", "PopulatedJournalHarness", "-derivedDataPath", "DerivedData/PopulatedJournalHarness"]
FLOWS = ["sh", "Scripts/screen-tests.sh", "FAKE-UDID", "Validation", "test",
         "-only-testing:ImmerseUITests -skip-testing:ImmerseUITests/ContentSizeTests",
         "-project", "App/Immerse/Immerse.xcodeproj", "-scheme", "Immerse",
         "-derivedDataPath", "DerivedData/ValidationSimulator"]
FILM_CARD = "-only-testing:PopulatedJournalHarnessTests/PopulatedWorkflowTests/testSixBySixBlackAndWhiteLookScreens"


class ScreenTestsTests(unittest.TestCase):
    def setUp(self):
        self.sandbox = Sandbox(self)

    def notes(self):
        path = self.sandbox.path("DerivedData", "validation-notes.txt")
        if not os.path.exists(path):
            return ""
        with open(path) as file:
            return file.read()

    def test_tests_that_pass_run_once_with_the_allowance_and_leave_no_note(self):
        result = self.sandbox.run(FLOWS, fixture("harness-film-card-tap"), xcodebuild_exits="0")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.sandbox.calls("xcodebuild-calls")
        self.assertEqual(len(calls), 1)
        self.assertRegex(calls[0], r"^-quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse "
                                   r"-derivedDataPath DerivedData/ValidationSimulator "
                                   r"-destination platform=iOS Simulator,id=FAKE-UDID "
                                   r"-resultBundlePath DerivedData/Validation-\d{8}T\d{6}Z.xcresult "
                                   r"-only-testing:ImmerseUITests -skip-testing:ImmerseUITests/ContentSizeTests "
                                   r"-test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 "
                                   r"CODE_SIGNING_ALLOWED=NO test$")
        self.assertEqual(self.sandbox.calls("tool-calls"), [], "a passing run reads no log")
        self.assertEqual(self.notes(), "")

    def test_a_test_whose_touch_the_simulator_dropped_is_run_once_more_alone_and_the_run_says_so(self):
        result = self.sandbox.run(HARNESS, fixture("harness-film-card-tap"), xcodebuild_exits="65 0")
        self.assertEqual(result.returncode, 0, result.stderr)
        first, rerun = self.sandbox.calls("xcodebuild-calls")
        self.assertRegex(first, r"-resultBundlePath DerivedData/Populated-\d{8}T\d{6}Z.xcresult .* test$")
        self.assertNotIn("-only-testing", first)
        self.assertRegex(rerun, r"-resultBundlePath DerivedData/Populated-rerun-\d{8}T\d{6}Z.xcresult " + FILM_CARD
                         + r" -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 "
                           r"CODE_SIGNING_ALLOWED=NO test-without-building$")
        self.assertNotIn("retry-tests-on-failure", first + rerun)
        self.assertNotIn("test-iterations", first + rerun)
        for said in (result.stderr, self.notes()):
            self.assertIn("Populated passed only after a rerun", said)
            self.assertRegex(said, r"first result is DerivedData/Populated-\d{8}T\d{6}Z.xcresult "
                                   r"and the rerun is DerivedData/Populated-rerun-\d{8}T\d{6}Z.xcresult")
            self.assertIn("dropped touch: PopulatedWorkflowTests/testSixBySixBlackAndWhiteLookScreens(). "
                          "The simulator discarded 7 touch events at 14:59:08 UTC", said)

    def test_the_rerun_replaces_the_first_selection_with_the_one_test(self):
        tap = self.sandbox.fixture_without(fixture("app-back-button-tap-and-clipped-text"),
                                           "JournalFlowTests/testLargestDynamicTypeCatalogAndLandscapeSettings()")
        result = self.sandbox.run(FLOWS, tap, xcodebuild_exits="65 0")
        self.assertEqual(result.returncode, 0, result.stderr)
        rerun = self.sandbox.calls("xcodebuild-calls")[1]
        self.assertIn("-only-testing:ImmerseUITests/ContentSizeTests/testLandscapeSettingsTopTextAtLarge ", rerun)
        self.assertNotIn("-skip-testing", rerun)
        self.assertNotIn("-only-testing:ImmerseUITests ", rerun)

    def test_a_rerun_that_fails_fails_the_run(self):
        result = self.sandbox.run(HARNESS, fixture("harness-film-card-tap"), xcodebuild_exits="65 65")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.sandbox.calls("xcodebuild-calls")), 2, "one rerun, never a second")
        self.assertIn("the rerun failed too, so Populated fails", result.stderr)
        self.assertEqual(self.notes(), "")

    def test_a_timeout_beside_a_dropped_touch_fails_without_a_rerun(self):
        result = self.sandbox.run(FLOWS, fixture("app-start-a-film-tap-and-a-timeout"), xcodebuild_exits="65 0")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.sandbox.calls("xcodebuild-calls")), 1)
        self.assertIn("no dropped touch: JournalFlowTests/testExtraSmallLoadScreensAudit()", result.stderr)
        self.assertIn("does not excuse every failed test", result.stderr)
        self.assertEqual(self.notes(), "")

    def test_a_clipped_text_finding_beside_a_dropped_touch_fails_without_a_rerun(self):
        result = self.sandbox.run(FLOWS, fixture("app-back-button-tap-and-clipped-text"), xcodebuild_exits="65 0")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.sandbox.calls("xcodebuild-calls")), 1)
        self.assertIn("no dropped touch: JournalFlowTests/testLargestDynamicTypeCatalogAndLandscapeSettings()",
                      result.stderr)

    def test_a_failure_with_no_failed_test_fails_without_a_rerun(self):
        built = self.sandbox.fixture_without(fixture("harness-film-card-tap"),
                                             "PopulatedWorkflowTests/testSixBySixBlackAndWhiteLookScreens()")
        result = self.sandbox.run(HARNESS, built, xcodebuild_exits="65 0")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.sandbox.calls("xcodebuild-calls")), 1)

    def test_a_simulator_log_that_cannot_be_read_fails_without_a_rerun(self):
        result = self.sandbox.run(HARNESS, fixture("harness-film-card-tap"), xcodebuild_exits="65 0", log_fails=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.sandbox.calls("xcodebuild-calls")), 1)

    def test_a_check_that_names_no_test_never_reruns_everything(self):
        self.sandbox.install(self.sandbox.path("Scripts", "dropped-touch-tests.py"), "import sys\nsys.exit(0)\n")
        result = self.sandbox.run(HARNESS, fixture("harness-film-card-tap"), xcodebuild_exits="65 0")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.sandbox.calls("xcodebuild-calls")), 1)

    def test_the_dark_audits_rerun_without_building_too(self):
        dark = ["sh", "Scripts/screen-tests.sh", "FAKE-UDID", "ValidationDark", "test-without-building",
                "-only-testing:ImmerseUITests/JournalFlowTests"] + FLOWS[6:]
        result = self.sandbox.run(dark, fixture("harness-film-card-tap"), xcodebuild_exits="65 0")
        self.assertEqual(result.returncode, 0, result.stderr)
        first, rerun = self.sandbox.calls("xcodebuild-calls")
        self.assertTrue(first.endswith(" test-without-building"))
        self.assertIn("-resultBundlePath DerivedData/ValidationDark-rerun-", rerun)


if __name__ == "__main__":
    unittest.main()
