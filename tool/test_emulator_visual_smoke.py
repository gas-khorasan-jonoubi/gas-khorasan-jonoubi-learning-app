#!/usr/bin/env python3
"""Unit tests for Android emulator visual smoke-test helpers."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from emulator_visual_smoke import EXPECTED_APPLICATION_ID, run_smoke_test


class EmulatorVisualSmokeTest(unittest.TestCase):
    @patch("emulator_visual_smoke.read_accessibility_tree")
    @patch("emulator_visual_smoke.capture_screenshot", side_effect=["splash-hash", "dashboard-hash"])
    @patch("emulator_visual_smoke.time.sleep")
    @patch("emulator_visual_smoke.subprocess.run")
    def test_smoke_test_captures_both_screens_without_requiring_accessibility_labels(
        self, run, sleep, screenshot, accessibility
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            application_id = root / "application_id.txt"
            application_id.write_text(EXPECTED_APPLICATION_ID, encoding="utf-8")
            run.return_value.returncode = 0
            run.return_value.stdout = "4321"

            run_smoke_test(application_id, root / "review")

            self.assertEqual(screenshot.call_count, 2)
            self.assertEqual(
                screenshot.call_args_list[0].args[0],
                root / "review" / "flutter-splash.png",
            )
            self.assertEqual(
                screenshot.call_args_list[1].args[0],
                root / "review" / "dashboard.png",
            )
            self.assertEqual(run.call_count, 2)
            self.assertEqual(
                run.call_args_list[0].args[0],
                ["adb", "shell", "pidof", EXPECTED_APPLICATION_ID],
            )
            self.assertIn("logcat", run.call_args_list[1].args[0])
            self.assertEqual(accessibility.call_count, 1)
            self.assertEqual(sleep.call_args_list[0].args[0], 0.5)
            self.assertGreaterEqual(sleep.call_args_list[1].args[0], 5)

    @patch("emulator_visual_smoke.capture_screenshot", side_effect=["same", "same"])
    @patch("emulator_visual_smoke.time.sleep")
    def test_smoke_test_rejects_unchanged_screen(self, sleep, screenshot) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            application_id = root / "application_id.txt"
            application_id.write_text(EXPECTED_APPLICATION_ID, encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "screenshots are identical"):
                run_smoke_test(application_id, root / "review")

    def test_smoke_test_rejects_wrong_package_id(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            application_id = root / "application_id.txt"
            application_id.write_text("ir.example.wrong", encoding="utf-8")
            with self.assertRaises(RuntimeError):
                run_smoke_test(application_id, root / "review")

    @patch("emulator_visual_smoke.time.sleep")
    @patch("emulator_visual_smoke.capture_screenshot")
    def test_smoke_test_requires_enough_time_for_splash(self, screenshot, sleep) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            application_id = root / "application_id.txt"
            application_id.write_text(EXPECTED_APPLICATION_ID, encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "five-second"):
                run_smoke_test(
                    application_id, root / "review", splash_timeout=4
                )
            screenshot.assert_not_called()
            sleep.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
