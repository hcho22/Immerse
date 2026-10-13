"""Scripts/dropped-touch-tests.py against fixtures cut from the three CI runs in which the simulator dropped a touch."""
import os
import unittest

from support import Sandbox, fixture

FILM_CARD = "PopulatedWorkflowTests/testSixBySixBlackAndWhiteLookScreens()"
START_A_FILM = "TestingUnlockUITests/testUnlockIndicatorFollowsThePersistedSettingsSwitch()"
TIMEOUT = "JournalFlowTests/testExtraSmallLoadScreensAudit()"
BACK_BUTTON = "ContentSizeTests/testLandscapeSettingsTopTextAtLarge()"
CLIPPED_TEXT = "JournalFlowTests/testLargestDynamicTypeCatalogAndLandscapeSettings()"


class DroppedTouchTests(unittest.TestCase):
    def setUp(self):
        self.sandbox = Sandbox(self)

    def check(self, fixture_directory, source=("--simulator", "FAKE-UDID"), **options):
        command = ["python3", "-B", "Scripts/dropped-touch-tests.py", "DerivedData/Some.xcresult", *source]
        return self.sandbox.run(command, fixture_directory, **options)

    def test_the_film_card_tap_the_simulator_dropped_is_excused(self):
        result = self.check(fixture("harness-film-card-tap"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split(), [
            "-only-testing:PopulatedJournalHarnessTests/PopulatedWorkflowTests/testSixBySixBlackAndWhiteLookScreens"])
        self.assertIn("dropped touch: " + FILM_CARD, result.stderr)
        self.assertIn("discarded 7 touch events at 14:59:08 UTC", result.stderr)
        self.assertIn("from 14:58:59 UTC to 15:00:17 UTC", result.stderr)

    def test_the_start_a_film_tap_is_excused_and_the_timeout_beside_it_is_not(self):
        result = self.check(fixture("app-start-a-film-tap-and-a-timeout"))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "", "nothing is rerun while one failure stands")
        self.assertIn("dropped touch: " + START_A_FILM, result.stderr)
        self.assertIn("discarded 7 touch events at 14:30:15 UTC", result.stderr)
        self.assertIn("no dropped touch: " + TIMEOUT, result.stderr)

    def test_the_back_button_tap_is_excused_and_the_clipped_text_beside_it_is_not(self):
        result = self.check(fixture("app-back-button-tap-and-clipped-text"))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("dropped touch: " + BACK_BUTTON, result.stderr)
        self.assertIn("discarded 7 touch events at 14:51:05 UTC", result.stderr)
        self.assertIn("no dropped touch: " + CLIPPED_TEXT, result.stderr)

    def test_each_dropped_tap_alone_earns_its_rerun(self):
        for name, other, selection in (
            ("app-start-a-film-tap-and-a-timeout", TIMEOUT,
             "ImmerseUITests/TestingUnlockUITests/testUnlockIndicatorFollowsThePersistedSettingsSwitch"),
            ("app-back-button-tap-and-clipped-text", CLIPPED_TEXT,
             "ImmerseUITests/ContentSizeTests/testLandscapeSettingsTopTextAtLarge"),
        ):
            with self.subTest(name):
                result = self.check(self.sandbox.fixture_without(fixture(name), other))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.split(), ["-only-testing:" + selection])

    def test_the_timeout_and_the_clipped_text_alone_earn_none(self):
        for name, dropped, standing in (
            ("app-start-a-film-tap-and-a-timeout", START_A_FILM, TIMEOUT),
            ("app-back-button-tap-and-clipped-text", BACK_BUTTON, CLIPPED_TEXT),
        ):
            with self.subTest(name):
                result = self.check(self.sandbox.fixture_without(fixture(name), dropped))
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, "")
                self.assertIn("no dropped touch: " + standing, result.stderr)
                self.assertNotIn("dropped touch: " + dropped, result.stderr)

    def test_an_unregistered_touchscreen_that_lost_no_event_is_no_proof(self):
        # The "unknown digitizer" record alone says the touchscreen's first event came early, not that any was lost.
        directory = self.sandbox.fixture_without(fixture("harness-film-card-tap"), "none")
        log = os.path.join(directory, "simulator-log.ndjson")
        with open(log) as file:
            records = [line for line in file if "unknown digitizer" in line]
        self.assertEqual(len(records), 1)
        with open(log, "w") as file:
            file.writelines(records)
        result = self.check(directory)
        self.assertEqual(result.returncode, 1)
        self.assertIn("no dropped touch: " + FILM_CARD, result.stderr)

    def test_a_run_that_failed_without_a_failed_test_is_not_excused(self):
        result = self.check(self.sandbox.fixture_without(fixture("harness-film-card-tap"), FILM_CARD))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("holds no failed test", result.stderr)

    def test_a_log_that_cannot_be_read_excuses_nothing(self):
        result = self.check(fixture("harness-film-card-tap"), log_fails=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("could not read", result.stderr)

    def test_a_booted_simulator_is_asked_for_its_own_log_since_the_first_failed_test(self):
        self.check(fixture("harness-film-card-tap"))
        asked = [call for call in self.sandbox.calls("tool-calls") if " show " in call]
        self.assertEqual(len(asked), 1)
        self.assertRegex(asked[0], r"^xcrun simctl spawn FAKE-UDID log show --last \d+m --style ndjson --predicate ")
        self.assertIn('process == "backboardd"', asked[0])

    def test_a_collected_log_archive_is_read_the_same_way(self):
        result = self.check(fixture("harness-film-card-tap"), source=("--archive", "some/system.logarchive"))
        self.assertEqual(result.returncode, 0, result.stderr)
        asked = [call for call in self.sandbox.calls("tool-calls") if " show " in call]
        self.assertRegex(asked[0], r"^log show --archive some/system.logarchive --style ndjson --predicate ")

    def test_it_explains_itself_when_called_wrongly(self):
        result = self.sandbox.run(["python3", "-B", "Scripts/dropped-touch-tests.py"], fixture("harness-film-card-tap"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usage: dropped-touch-tests.py", result.stderr)


if __name__ == "__main__":
    unittest.main()
