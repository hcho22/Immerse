"""Scripts/collect-failure-evidence.sh: what a failed packages part keeps, and that only a failed packages part keeps it."""
import json
import os
import subprocess
import tempfile
import unittest

from support import ROOT, Sandbox

REPORTS = ["VTDecoderXPCService-2026-10-28-212700.ips", "JetsamEvent-2026-10-28-212600.ips",
           "DevelopmentExitWorker-2026-10-28-212701.ips", "xctest-2026-10-28-212702.ips"]
UNFINISHED = "cinema16mm-discard-reassembly-A"
FINISHED = "super8HomeMovie-discard-reassembly-B"
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
        # A Film whose test stopped before its resumed snapshot, and one whose test went past it.
        self.write(os.path.join(self.films, UNFINISHED, "original.json"), "{}")
        self.write(os.path.join(self.films, UNFINISHED, "App", "Media", "F", "clip-2.mov"), "clip")
        self.write(os.path.join(self.films, FINISHED, "resumed.json"), "{}")

    def write(self, path, text):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as file:
            file.write(text)

    def write_bytes(self, path, size):
        """A file of `size` bytes, holes and all, so a Film can be as large as the cap without filling the disk."""
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as file:
            file.truncate(size)

    def collect(self, **options):
        return self.sandbox.run(["sh", "Scripts/collect-failure-evidence.sh", "out"], self.fixture, environment={
            "IMMERSE_EVIDENCE_REPORT_DIRS": self.reports, "IMMERSE_EVIDENCE_FILMS_DIR": self.films}, **options)

    def test_keeps_the_decoder_reports_the_filtered_log_and_every_film(self):
        result = self.collect()
        self.assertEqual(result.returncode, 0, result.stderr)
        out = self.sandbox.path("out")
        self.assertEqual(sorted(os.listdir(os.path.join(out, "reports"))), sorted(REPORTS))
        self.assertEqual(sorted(os.listdir(os.path.join(out, "films"))), [UNFINISHED, FINISHED])
        with open(os.path.join(out, "films", UNFINISHED, "App", "Media", "F", "clip-2.mov")) as clip:
            self.assertEqual(clip.read(), "clip")
        with open(os.path.join(out, "films", FINISHED, "resumed.json")) as snapshot:
            self.assertEqual(snapshot.read(), "{}")
        with open(os.path.join(out, "system-log.txt")) as log:
            self.assertEqual(log.read(), LOG)
        [call] = [line for line in self.sandbox.calls("tool-calls") if line.startswith("log ")]
        self.assertTrue(call.startswith("log show --last 20m --style compact --predicate "), call)
        for name in ('process == "VTDecoderXPCService"', '"DevelopmentExitWorker"', 'subsystem == "com.apple.coremedia"',
                     'eventMessage CONTAINS "memorystatus"'):
            self.assertIn(name, call)
        self.assertIn("probe Films kept: 2 (8 bytes); left past the 100000000-byte cap: 0", result.stdout)

    def test_a_log_that_cannot_be_read_leaves_the_rest_kept(self):
        result = self.collect(log_fails=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("log show ended with status 1", result.stdout)
        self.assertEqual(len(os.listdir(self.sandbox.path("out", "reports"))), len(REPORTS))
        self.assertEqual(sorted(os.listdir(self.sandbox.path("out", "films"))), [UNFINISHED, FINISHED])

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

    def test_keeps_the_newest_films_until_the_next_would_pass_100_mb(self):
        # Under the cap on its own, the second newest Film would pass it on top of the newest, so it and the older one
        # are left, however small.
        self.write_bytes(os.path.join(self.films, FINISHED, "App", "Media", "F", "clip-1.mov"), 1_000_000)
        self.write_bytes(os.path.join(self.films, "cinema16mm-every-boundary-C", "App", "Media", "F", "clip-1.mov"),
                         99_500_000)
        for seconds, film in enumerate([UNFINISHED, "cinema16mm-every-boundary-C", FINISHED], start=1_793_000_001):
            os.utime(os.path.join(self.films, film), (seconds, seconds))
        result = self.collect()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.listdir(self.sandbox.path("out", "films")), [FINISHED])
        with open(self.sandbox.path("out", "notes.txt")) as notes:
            self.assertIn("probe Films kept: 1 (1000002 bytes); left past the 100000000-byte cap: 2\n", notes.read())

    def test_the_workflow_keeps_it_only_after_a_failed_packages_part(self):
        # GitHub reads the workflow as YAML; Ruby's YAML reads it the same way and hands the steps over as JSON.
        parsed = subprocess.run(["ruby", "-ryaml", "-rjson", "-e", "puts JSON.dump(YAML.load_file(ARGV[0]))",
                                 os.path.join(ROOT, ".github", "workflows", "native.yml")],
                                capture_output=True, text=True, check=True)
        steps = json.loads(parsed.stdout)["jobs"]["part"]["steps"]
        names = [step.get("name") for step in steps]
        keep = steps[names.index("Keep the evidence of a failed packages part")]
        retain = steps[names.index("Retain the evidence of a failed packages part")]
        for step in (keep, retain):
            self.assertEqual(step["if"], "failure() && matrix.part == 'packages'")
            self.assertGreater(steps.index(step), names.index("Validate"))
        self.assertEqual(keep["run"], "sh Scripts/collect-failure-evidence.sh DerivedData/FailureEvidence")
        self.assertEqual(retain["with"]["path"], "DerivedData/FailureEvidence")
        self.assertEqual(retain["with"]["name"], "failure-evidence-packages")


if __name__ == "__main__":
    unittest.main()
