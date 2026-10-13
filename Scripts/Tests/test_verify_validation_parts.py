"""Scripts/verify-validation-parts.sh against a copy of the repository's layout that each test breaks in one way."""
import glob
import os
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class VerifyValidationPartsTests(unittest.TestCase):
    def setUp(self):
        self.tree = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tree)
        for script in ("validation-parts.sh", "verify-validation-parts.sh"):
            self.copy(os.path.join("Scripts", script))
        for manifest in glob.glob(os.path.join(ROOT, "Packages", "*", "Package.swift")):
            self.write(os.path.relpath(manifest, ROOT))
        for probe in glob.glob(os.path.join(ROOT, "Probes", "*")):
            name = os.path.relpath(probe, ROOT)
            os.makedirs(os.path.join(self.tree, name))
            if os.path.exists(os.path.join(probe, "Package.swift")):
                self.write(os.path.join(name, "Package.swift"))
            for project in glob.glob(os.path.join(probe, "*.xcodeproj")):
                os.makedirs(os.path.join(self.tree, os.path.relpath(project, ROOT)))
        self.copy("App/Immerse/project.yml")
        self.copy("Probes/PopulatedJournalHarness/project.yml")
        for source in glob.glob(os.path.join(ROOT, "App/Immerse/UITests/*.swift")):
            with open(source) as file:
                classes = re.findall(r"^.*class \w+ *: *XCTestCase.*$", file.read(), re.M)
            self.write(os.path.relpath(source, ROOT), "\n".join(classes) + "\n")

    def copy(self, path):
        with open(os.path.join(ROOT, path)) as file:
            self.write(path, file.read())

    def write(self, path, text=""):
        target = os.path.join(self.tree, path)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "w") as file:
            file.write(text)

    def edit(self, path, old, new):
        with open(os.path.join(self.tree, path)) as file:
            text = file.read()
        self.assertIn(old, text)
        self.write(path, text.replace(old, new))

    def verify(self, tree=None):
        script = os.path.join(tree or self.tree, "Scripts", "verify-validation-parts.sh")
        return subprocess.run(["sh", script], capture_output=True, text=True)

    def assertRefuses(self, message):
        result = self.verify()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(message, result.stderr)

    def test_the_repository_assigns_everything_to_a_part(self):
        result = self.verify(ROOT)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ui-text runs ContentSizeTests", result.stdout)

    def test_the_copied_layout_passes_before_it_is_broken(self):
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_a_new_package_in_no_part_fails(self):
        self.write("Packages/NewLook/Package.swift")
        self.assertRefuses("Packages/NewLook belongs to no part")

    def test_a_new_probe_package_in_no_part_fails(self):
        self.write("Probes/NewStudy/Package.swift")
        self.assertRefuses("Probes/NewStudy belongs to no part")

    def test_a_new_probe_project_in_no_part_fails(self):
        os.makedirs(os.path.join(self.tree, "Probes/NewHarness/NewHarness.xcodeproj"))
        self.assertRefuses("Probes/NewHarness belongs to no part")

    def test_a_probe_with_neither_a_package_nor_a_project_is_not_a_test_target(self):
        self.write("Probes/NewNotes/README.md")
        self.assertEqual(self.verify().returncode, 0)

    def test_a_new_app_test_target_in_no_part_fails(self):
        self.edit("App/Immerse/project.yml", "  ImmerseTests:\n",
                  "  ImmerseSnapshotTests:\n    type: bundle.unit-test\n    platform: iOS\n  ImmerseTests:\n")
        self.assertRefuses("the app's test target ImmerseSnapshotTests belongs to no part")

    def test_a_new_harness_test_target_in_no_part_fails(self):
        self.edit("Probes/PopulatedJournalHarness/project.yml", "  PopulatedJournalHarnessTests:\n",
                  "  ExtraHarnessTests:\n    type: bundle.ui-testing\n  PopulatedJournalHarnessTests:\n")
        self.assertRefuses("the harness test target ExtraHarnessTests belongs to no part")

    def test_a_package_removed_from_the_list_fails(self):
        self.edit("Scripts/validation-parts.sh", "RenderCore FilmPersistence", "FilmPersistence")
        self.assertRefuses("Packages/RenderCore belongs to no part")

    def test_a_dark_suite_that_no_longer_exists_fails(self):
        self.edit("App/Immerse/UITests/FilmStockUITests.swift", "FilmStockUITests", "FilmStockScreenTests")
        self.assertRefuses("validation selects the suite FilmStockUITests, which App/Immerse/UITests does not define")

    def test_a_renamed_text_size_suite_fails(self):
        self.edit("App/Immerse/UITests/ContentSizeTests.swift", "ContentSizeTests", "TextSizeTests")
        self.assertRefuses("validation selects the suite ContentSizeTests")

    def test_a_new_screen_suite_lands_in_ui_flows(self):
        self.write("App/Immerse/UITests/ArchiveFlowTests.swift", "final class ArchiveFlowTests: XCTestCase {\n")
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, r"ui-flows runs.* ArchiveFlowTests")


if __name__ == "__main__":
    unittest.main()
