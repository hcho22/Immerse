"""Scripts/collect-failure-evidence.sh: what a failed packages part keeps, and that only a failed packages part keeps it."""
import os
import re
import tempfile
import unittest

from support import ROOT, Sandbox

REPORTS = ["VTDecoderXPCService-2026-10-28-212700.ips", "JetsamEvent-2026-10-28-212600.ips",
           "DevelopmentExitWorker-2026-10-28-212701.ips", "xctest-2026-10-28-212702.ips"]
LOG = "2026-10-28 21:27:00.000 E  DevelopmentExitWorker[1:2] [com.apple.coremedia:] synthetic decoder line\n"


class CollectFailureEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.sandbox = Sandbox(self)
        self.reports = self.sandbox.path("DiagnosticReports")
        self.films = self.sandbox.path("DevelopmentProcessExit")
        self.fixture = tempfile.mkdtemp(dir=self.sandbox.tree)
        os.makedirs(self.reports)
        with open(os.path.join(self.fixture, "simulator-log.ndjson"), "w") as log:
            log.write(LOG)
        for name in REPORTS + ["Safari-2026-10-28-212703.ips"]:
            self.write(os.path.join(self.reports, name), "{}")
        # A Film whose test stopped before its resumed snapshot, and one whose test finished.
        self.write(os.path.join(self.films, "cinema16mm-discard-reassembly-A", "original.json"), "{}")
        self.write(os.path.join(self.films, "cinema16mm-discard-reassembly-A", "App", "Media", "F", "clip-2.mov"), "clip")
        self.write(os.path.join(self.films, "super8HomeMovie-discard-reassembly-B", "resumed.json"), "{}")

    def write(self, path, text):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as file:
            file.write(text)

    def collect(self, **options):
        return self.sandbox.run(["sh", "Scripts/collect-failure-evidence.sh", "out"], self.fixture, environment={
            "IMMERSE_EVIDENCE_REPORT_DIRS": self.reports, "IMMERSE_EVIDENCE_FILMS_DIR": self.films}, **options)

    def test_keeps_the_decoder_reports_the_filtered_log_and_the_unfinished_films(self):
        result = self.collect()
        self.assertEqual(result.returncode, 0, result.stderr)
        out = self.sandbox.path("out")
        self.assertEqual(sorted(os.listdir(os.path.join(out, "reports"))), sorted(REPORTS))
        self.assertEqual(os.listdir(os.path.join(out, "films")), ["cinema16mm-discard-reassembly-A"])
        with open(os.path.join(out, "films", "cinema16mm-discard-reassembly-A", "App", "Media", "F", "clip-2.mov")) as clip:
            self.assertEqual(clip.read(), "clip")
        with open(os.path.join(out, "system-log.txt")) as log:
            self.assertEqual(log.read(), LOG)
        [call] = [line for line in self.sandbox.calls("tool-calls") if line.startswith("log ")]
        self.assertTrue(call.startswith("log show --last 20m --style compact --predicate "), call)
        for name in ('process == "VTDecoderXPCService"', '"DevelopmentExitWorker"', 'subsystem == "com.apple.coremedia"',
                     'eventMessage CONTAINS "memorystatus"'):
            self.assertIn(name, call)
        self.assertIn("unfinished probe Films kept: 1", result.stdout)

    def test_a_log_that_cannot_be_read_leaves_the_rest_kept(self):
        result = self.collect(log_fails=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("log show ended with status 1", result.stdout)
        self.assertEqual(len(os.listdir(self.sandbox.path("out", "reports"))), len(REPORTS))
        self.assertEqual(os.listdir(self.sandbox.path("out", "films")), ["cinema16mm-discard-reassembly-A"])

    def test_keeps_only_the_newest_twenty_reports(self):
        for name in REPORTS:
            os.utime(os.path.join(self.reports, name), (1_700_000_000, 1_700_000_000))
        for index in range(30):
            path = os.path.join(self.reports, "JetsamEvent-2026-10-28-%06d.ips" % index)
            self.write(path, "{}")
            os.utime(path, (1_793_000_000 + index, 1_793_000_000 + index))
        result = self.collect()
        self.assertEqual(result.returncode, 0, result.stderr)
        kept = sorted(os.listdir(self.sandbox.path("out", "reports")))
        self.assertEqual(kept, ["JetsamEvent-2026-10-28-%06d.ips" % index for index in range(10, 30)])

    def test_the_workflow_keeps_it_only_after_a_failed_packages_part(self):
        with open(os.path.join(ROOT, ".github", "workflows", "native.yml")) as file:
            workflow = file.read()
        steps = re.split(r"\n      - ", workflow)
        named = {re.match(r"(?:name: )?(.*)", step).group(1): step for step in steps}
        names = list(named)
        for name in ("Keep the evidence of a failed packages part", "Retain the evidence of a failed packages part"):
            self.assertIn("\n        if: failure() && matrix.part == 'packages'\n", named[name], name)
            self.assertGreater(names.index(name), names.index("Validate"))
        self.assertIn("run: sh Scripts/collect-failure-evidence.sh DerivedData/FailureEvidence",
                      named["Keep the evidence of a failed packages part"])
        self.assertIn("path: DerivedData/FailureEvidence", named["Retain the evidence of a failed packages part"])


if __name__ == "__main__":
    unittest.main()
