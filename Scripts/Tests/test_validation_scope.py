"""Scripts/validation-scope.sh: only a pull request that changes Markdown alone skips the screen-test parts."""
import json
import os
import shutil
import subprocess
import unittest

from support import ROOT

EVERY = ["packages", "harness", "ui-text", "ui-flows"]
# The six files of the Markdown-only pull request whose check failed on a dropped touch on 2026-10-13.
TEST_PLAN_PULL_REQUEST = [
    "AGENTS.md",
    "Evidence/NativeApp/final-candidate-050.md",
    "Evidence/NativeApp/launch-readiness.md",
    "Evidence/NativeApp/manual-validation.md",
    "Evidence/NativeApp/qa13-measurement-049.md",
    "README.md",
]


class ValidationScopeTests(unittest.TestCase):
    def scope(self, event, paths, shell="sh"):
        script = os.path.join(ROOT, "Scripts", "validation-scope.sh")
        result = subprocess.run([shell, script, event], input="".join(path + "\n" for path in paths),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        self.assertEqual(len(lines), 2, "two step outputs, each on one line")
        self.assertTrue(lines[0].startswith("parts="))
        self.assertTrue(lines[1].startswith("note="))
        return json.loads(lines[0][len("parts="):]), lines[1][len("note="):]

    def test_a_markdown_only_pull_request_runs_packages_alone_and_says_why(self):
        parts, note = self.scope("pull_request", TEST_PLAN_PULL_REQUEST)
        self.assertEqual(parts, ["packages"])
        self.assertIn("Markdown-only pull request (6 files)", note)
        self.assertIn("harness, ui-text and ui-flows were skipped", note)
        self.assertIn("document checks", note)

    def test_one_other_file_in_the_change_runs_everything(self):
        parts, note = self.scope("pull_request", TEST_PLAN_PULL_REQUEST + ["Scripts/validate-local.sh"])
        self.assertEqual(parts, EVERY)
        self.assertIn("changes Scripts/validate-local.sh, which is not a document", note)

    def test_every_kind_of_file_that_is_not_markdown_runs_everything(self):
        for path in ("Packages/RenderCore/Sources/RenderCore/FilmLook.swift", ".github/workflows/native.yml",
                     "2026-09-29-film-camera-experience-v1-documents.zip", "Evidence/NativeApp/journal.png",
                     "notes.md.swift", "README.mdx", "README.MD", "md", "docs/.md/config.json"):
            with self.subTest(path):
                parts, _ = self.scope("pull_request", ["README.md", path])
                self.assertEqual(parts, EVERY)

    def test_markdown_where_xcode_bundles_what_it_finds_counts_as_code(self):
        for path in ("App/Immerse/Sources/Resources/Credits.md", "App/Immerse/README.md",
                     "Probes/PopulatedJournalHarness/Sources/Notes.md"):
            with self.subTest(path):
                parts, note = self.scope("pull_request", ["README.md", path])
                self.assertEqual(parts, EVERY)
                self.assertIn(path, note)

    def test_markdown_in_other_packages_and_probes_is_a_document(self):
        parts, _ = self.scope("pull_request", ["Packages/FilmRuntime/README.md", "Probes/TrialKeychainProbe/README.md",
                                               "2026-09-29-film-camera-experience-v1/adr/0016 notes.md"])
        self.assertEqual(parts, ["packages"])

    def test_a_push_to_main_runs_everything_whatever_it_changed(self):
        for paths in (TEST_PLAN_PULL_REQUEST, []):
            parts, note = self.scope("push", paths)
            self.assertEqual(parts, EVERY)
            self.assertIn("Every part ran", note)

    def test_a_pull_request_whose_files_cannot_be_listed_runs_everything(self):
        parts, note = self.scope("pull_request", [])
        self.assertEqual(parts, EVERY)
        self.assertIn("could not be listed", note)

    @unittest.skipUnless(shutil.which("dash"), "dash, the shell the scope job's runner uses for sh, is not installed")
    def test_it_decides_the_same_in_the_scope_jobs_shell(self):
        self.assertEqual(self.scope("pull_request", TEST_PLAN_PULL_REQUEST, shell="dash")[0], ["packages"])
        self.assertEqual(self.scope("pull_request", ["Scripts/screen-tests.sh"], shell="dash")[0], EVERY)

    def test_it_asks_for_the_event(self):
        script = os.path.join(ROOT, "Scripts", "validation-scope.sh")
        result = subprocess.run(["sh", script], input="", capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usage: validation-scope.sh", result.stderr)


if __name__ == "__main__":
    unittest.main()
