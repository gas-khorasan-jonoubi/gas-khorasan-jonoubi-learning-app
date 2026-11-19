"""Fast, platform-independent quality checks for the Android learning app."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ProjectQualityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        cls.codemagic = (ROOT / "codemagic.yaml").read_text(encoding="utf-8")
        cls.main_dart = (ROOT / "lib" / "main.dart").read_text(encoding="utf-8")
        cls.workflow = (ROOT / ".github" / "workflows" / "flutter-checks.yml").read_text(encoding="utf-8")
        cls.integration_test = ROOT / "integration_test" / "app_smoke_test.dart"

    def test_persian_android_app_label_is_configured(self):
        self.assertIn('android:label="دانستنی‌های گاز"', self.codemagic)
        self.assertIn("Could not find the Android application label", self.codemagic)

    def test_splash_asset_is_declared_and_present(self):
        splash = ROOT / "assets" / "splash.webp"
        self.assertIn("assets/splash.webp", self.pubspec)
        self.assertTrue(splash.is_file(), "Splash image is missing from the repository")
        self.assertGreater(splash.stat().st_size, 0, "Splash image is empty")

    def test_splash_duration_is_three_seconds(self):
        self.assertRegex(
            self.main_dart,
            r"Future\.delayed\(const Duration\(seconds:\s*3\)",
        )

    def test_exam_timer_uses_thirty_seconds_per_question(self):
        self.assertRegex(
            self.main_dart,
            r"const\s+examDurationPerQuestion\s*=\s*30\s*;",
        )

    def test_demo_question_bank_is_not_misrepresented_as_official(self):
        self.assertIn("These are demonstration questions only", self.main_dart)
        self.assertIn("organization-approved question banks", self.main_dart)

    def test_release_apk_is_not_triggered_by_normal_feature_pushes(self):
        self.assertIn("__manual_build_only__", self.codemagic)

    def test_android_emulator_smoke_test_is_present(self):
        self.assertTrue(self.integration_test.is_file())
        self.assertIn("Android emulator smoke test", self.workflow)
        self.assertIn("app_smoke_test.dart", self.workflow)


if __name__ == "__main__":
    unittest.main(verbosity=2)
