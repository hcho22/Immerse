"""Scripts/rerun-tests.py against fixtures cut from run 39424197098, in which one test ran out of its allowance on an
animation stall (Evidence/NativeApp/main-ci-flakes-074.md) and another lost a touch."""
import json
import re
import unittest

from support import Sandbox, fixture, stall_fixture

BOTH = stall_fixture("darkroom-stall-and-instant-dropped-touch")
DARKROOM = "PopulatedWorkflowTests/testDarkroomTurningLeavesALoadErrorInPlace()"
INSTANT = "PopulatedWorkflowTests/testInstantLookScreens()"
DARKROOM_FLAG = "-only-testing:PopulatedJournalHarnessTests/PopulatedWorkflowTests/testDarkroomTurningLeavesALoadErrorInPlace"
INSTANT_FLAG = "-only-testing:PopulatedJournalHarnessTests/PopulatedWorkflowTests/testInstantLookScreens"
ALLOWANCE = "Test exceeded execution time allowance of 3 minutes"
# The first request of the stalled launch that no reply followed, and the last reply before it.
FIRST_UNANSWERED = "2026-10-20 13:17:55.413533+0000 PopulatedJournalHarness[67204:182983] [Default] Received request to notify when animations are idle\n"
LAST_REQUEST_IN_WINDOW = "2026-10-20 13:20:12.021732+0000 PopulatedJournalHarness[67204:192115] [Default] Received request to notify when animations are idle\n"
REPLY = "2026-10-20 13:20:12.500000+0000 PopulatedJournalHarness[67204:182876] [Default] Sending animations idle reply with error: (null)\n"


def exports(sandbox):
    return [call for call in sandbox.calls("tool-calls") if " export " in call]


class RerunTestsTests(unittest.TestCase):
    def setUp(self):
        self.sandbox = Sandbox(self)

    def check(self, fixture_directory, source=("--simulator", "FAKE-UDID"), **options):
        command = ["python3", "-B", "Scripts/rerun-tests.py", "DerivedData/Some.xcresult", *source]
        return self.sandbox.run(command, fixture_directory, **options)

    def without_instant(self):
        return self.sandbox.fixture_without(BOTH, INSTANT)

    def without_darkroom(self):
        return self.sandbox.fixture_without(BOTH, DARKROOM)

    def assertStands(self, result, test):
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout, "", "nothing is rerun while a failure stands")
        self.assertIn("no animation stall: " + test, result.stderr)

    def test_the_stalled_darkroom_test_and_the_dropped_touch_beside_it_are_both_excused_by_their_own_records(self):
        result = self.check(BOTH)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split(), [DARKROOM_FLAG, INSTANT_FLAG])
        self.assertIn("animation stall: " + DARKROOM + ". The test ended at its time allowance. XCTest gave up waiting "
                      "for the app's animations at 13:18:55 UTC and the app never replied to its request at 13:17:55 UTC, "
                      "inside the test's run from 13:17:35 UTC to 13:20:35 UTC.", result.stderr)
        self.assertIn("dropped touch: " + INSTANT + ". The simulator discarded 7 touch events at 13:25:48 UTC", result.stderr)
        self.assertNotIn("no dropped touch", result.stderr)
        self.assertNotIn("no animation stall", result.stderr)

    def test_the_stall_alone_is_excused(self):
        result = self.check(self.without_instant())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split(), [DARKROOM_FLAG])
        self.assertIn("animation stall: " + DARKROOM, result.stderr)

    def test_the_dropped_touch_alone_is_excused_without_reading_the_apps_log(self):
        result = self.check(self.without_darkroom())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split(), [INSTANT_FLAG])
        self.assertEqual(exports(self.sandbox), [])

    def test_a_collected_log_archive_serves_the_dropped_touch_and_the_bundle_the_stall(self):
        result = self.check(BOTH, source=("--archive", "some/system.logarchive"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split(), [DARKROOM_FLAG, INSTANT_FLAG])
        calls = self.sandbox.calls("tool-calls")
        self.assertTrue(any(call.startswith("log show --archive some/system.logarchive") for call in calls))
        self.assertTrue(any(call.startswith("xcrun xcresulttool export diagnostics --path DerivedData/Some.xcresult") for call in calls))

    def test_the_apps_log_is_exported_once_for_all_the_failed_tests(self):
        both = self.sandbox.edited(BOTH, "simulator-log.ndjson", lambda text: "")
        self.check(both)
        self.assertEqual(len(exports(self.sandbox)), 1)

    def test_xcests_wait_alone_is_not_the_stall(self):
        # The app answered the last request of the window: the counter did come back to zero.
        answered = self.sandbox.edited(self.without_instant(), "app-log.txt",
                                       lambda text: text.replace(LAST_REQUEST_IN_WINDOW, LAST_REQUEST_IN_WINDOW + REPLY))
        result = self.check(answered)
        self.assertStands(result, DARKROOM)
        self.assertIn("the app's log holds no animation-idle request without a reply inside the test's run from "
                      "13:17:35 UTC to 13:20:35 UTC", result.stderr)

    def test_the_apps_unanswered_request_alone_is_not_the_stall(self):
        no_wait = self.sandbox.edited(self.without_instant(), "activities.json",
                                      lambda text: text.replace("App animations complete notification not received, will attempt to continue.",
                                                                "Wait finished"))
        result = self.check(no_wait)
        self.assertStands(result, DARKROOM)
        self.assertIn("XCTest recorded no unanswered wait for the app's animations inside the test's run", result.stderr)
        self.assertEqual(exports(self.sandbox), [], "the app's log is read only after XCTest's wait is found")

    def test_a_reply_answers_only_the_requests_before_it(self):
        # Answered at 13:17:55.6, the first wait's request is not what the other two, at 13:19:03 and 13:20:12, are.
        early = self.sandbox.edited(self.without_instant(), "app-log.txt",
                                    lambda text: text.replace(FIRST_UNANSWERED, FIRST_UNANSWERED + REPLY.replace("13:20:12.500000", "13:17:55.600000")))
        result = self.check(early)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("never replied to its request at 13:19:03 UTC", result.stderr)

    def test_a_signature_outside_the_tests_window_excuses_nothing(self):
        later = lambda text: re.sub(r'("startTime": )1792502255\.041', r"\g<1>1792509255.041", text)
        for name, edit in (
            ("the test's window", ("test-details.json", later)),
            ("XCTest's wait", ("activities.json", lambda text: re.sub(r'"startTime": (1792502[34]\d\d\.\d+)',
                                                                    lambda match: '"startTime": %.3f' % (float(match.group(1)) + 7000), text))),
            ("the app's request", ("app-log.txt", lambda text: text.replace("2026-10-20 13:", "2026-10-19 13:"))),
        ):
            with self.subTest(name):
                result = self.check(self.sandbox.edited(self.without_instant(), *edit))
                self.assertStands(result, DARKROOM)

    def test_a_failure_that_is_not_the_time_allowance_is_not_the_stall_even_after_a_stalled_wait(self):
        assertion = self.sandbox.edited(self.without_instant(), "test-details.json",
                                        lambda text: text.replace(ALLOWANCE, "XCTAssertTrue failed - Print unavailable"))
        result = self.check(assertion)
        self.assertStands(result, DARKROOM)
        self.assertIn("its failure is not only the time allowance", result.stderr)
        self.assertEqual(exports(self.sandbox), [])

    def test_a_time_allowance_beside_an_assertion_failure_of_the_same_test_is_not_the_stall(self):
        def both_failures(text):
            details = json.loads(text)
            runs = details[DARKROOM]["testRuns"][0]["children"][0]["children"]
            runs.append({"nodeType": "Test Case Run", "name": "XCTAssertTrue failed - Print unavailable", "result": "Failed"})
            return json.dumps(details)

        result = self.check(self.sandbox.edited(self.without_instant(), "test-details.json", both_failures))
        self.assertStands(result, DARKROOM)

    def test_a_test_with_no_failure_text_is_not_the_stall(self):
        none = self.sandbox.edited(self.without_instant(), "test-details.json", lambda text: text.replace(ALLOWANCE, "").replace('"Test Case Run"', '"Source Code Reference"'))
        self.assertStands(self.check(none), DARKROOM)

    def test_the_stall_beside_a_failure_nothing_excuses_earns_no_rerun(self):
        no_discard = self.sandbox.edited(BOTH, "simulator-log.ndjson", lambda text: "")
        result = self.check(no_discard)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("animation stall: " + DARKROOM, result.stderr)
        self.assertIn("no dropped touch: " + INSTANT, result.stderr)
        self.assertIn("no animation stall: " + INSTANT + ". its failure is not only the time allowance", result.stderr)

    def test_the_runners_own_log_is_not_the_apps(self):
        # The stub's runner log holds an unanswered request inside the Darkroom test's window.
        answered = self.sandbox.edited(self.without_instant(), "app-log.txt",
                                       lambda text: text.replace(LAST_REQUEST_IN_WINDOW, LAST_REQUEST_IN_WINDOW + REPLY))
        self.assertStands(self.check(answered), DARKROOM)

    def test_a_request_that_lost_its_timestamp_to_another_line_proves_nothing_and_one_that_kept_it_does(self):
        def mangled(text):
            return re.sub(r"2026-10-20 13:(17:55|19:03|20:12)\.\d+\+0000 PopulatedJournalHarness\[67204:\d+\] ", "", text)

        self.assertStands(self.check(self.sandbox.edited(self.without_instant(), "app-log.txt", mangled)), DARKROOM)
        prefixed = self.sandbox.edited(self.without_instant(), "app-log.txt",
                                       lambda text: text.replace(FIRST_UNANSWERED, "2026-10-20 13:17:" + FIRST_UNANSWERED))
        self.assertEqual(self.check(prefixed).returncode, 0)

    def test_diagnostics_that_cannot_be_exported_excuse_nothing(self):
        result = self.check(self.without_instant(), export_fails=True)
        self.assertStands(result, DARKROOM)
        self.assertIn("could not read the bundle's diagnostics", result.stderr)

    def test_a_simulator_log_that_cannot_be_read_still_lets_the_bundle_excuse_the_stall_but_not_the_touch(self):
        result = self.check(self.without_instant(), log_fails=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.check(self.without_darkroom(), log_fails=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("Could not read the simulator's log", result.stderr)

    def test_a_run_that_failed_without_a_failed_test_is_not_excused(self):
        result = self.check(self.sandbox.fixture_without(self.without_darkroom(), INSTANT))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("holds no failed test", result.stderr)

    def test_the_old_dropped_touch_fixtures_are_excused_as_before(self):
        result = self.check(fixture("harness-film-card-tap"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split(), [
            "-only-testing:PopulatedJournalHarnessTests/PopulatedWorkflowTests/testSixBySixBlackAndWhiteLookScreens"])
        result = self.check(fixture("app-start-a-film-tap-and-a-timeout"))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("dropped touch: TestingUnlockUITests/testUnlockIndicatorFollowsThePersistedSettingsSwitch()", result.stderr)
        self.assertIn("no dropped touch: JournalFlowTests/testExtraSmallLoadScreensAudit()", result.stderr)

    def test_it_explains_itself_when_called_wrongly(self):
        result = self.sandbox.run(["python3", "-B", "Scripts/rerun-tests.py"], BOTH)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usage: rerun-tests.py", result.stderr)


if __name__ == "__main__":
    unittest.main()
