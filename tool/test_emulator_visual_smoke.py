#!/usr/bin/env python3
"""Unit tests for Android emulator visual smoke-test helpers."""

from __future__ import annotations

import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch

from emulator_visual_smoke import (
    EXPECTED_APPLICATION_ID,
    accessible_texts,
    run_smoke_test,
    wait_for_labels,
)


class EmulatorVisualSmokeTest(unittest.TestCase):
    def test_accessible_texts_includes_text_and_content_descriptions(self) -> None:
        root = ET.fromstring(
            '<hierarchy><node text="داشبورد" content-desc="خانه" />'
            '<node text="" content-desc=" " /></hierarchy>'
        )
        self.assertEqual(accessible_texts(root), {"داشبورد", "خانه"})

    @patch("emulator_visual_smoke.read_accessibility_tree")
    @patch("emulator_visual_smoke.time.sleep")
    def test_waits_until_all_expected_labels_are_visible(self, sleep, read_tree) -> None:
        root = ET.fromstring('<hierarchy><node text="داشبورد" /></hierarchy>')
        read_tree.return_value = root

        with tempfile.TemporaryDirectory() as temporary:
            labels = wait_for_labels(
                {"داشبورد"},
                remote_path="/sdcard/dashboard.xml",
                local_path=Path(temporary) / "dashboard.xml",
                timeout_seconds=1,
            )

        self.assertIn("داشبورد", labels)
        read_tree.assert_called_once()

    @patch("emulator_visual_smoke.read_accessibility_tree", return_value=None)
    @patch("emulator_visual_smoke.time.sleep")
    @patch("emulator_visual_smoke.time.monotonic", side_effect=[0, 0, 2])
    def test_times_out_when_android_never_exposes_a_ui_tree(
        self, monotonic, sleep, read_tree
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(TimeoutError):
                wait_for_labels(
                    {"داشبورد"},
                    remote_path="/sdcard/dashboard.xml",
                    local_path=Path(temporary) / "dashboard.xml",
                    timeout_seconds=1,
                )

    @patch("emulator_visual_smoke.capture_screenshot")
    @patch("emulator_visual_smoke.wait_for_labels")
    @patch("emulator_visual_smoke.subprocess.run")
    @patch("emulator_visual_smoke.time.sleep")
    def test_smoke_test_checks_dashboard_and_both_screenshots(
        self, sleep, run, wait, screenshot
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            application_id = root / "application_id.txt"
            application_id.write_text(EXPECTED_APPLICATION_ID, encoding="utf-8")
            run.return_value.returncode = 0
            run.return_value.stdout = "4321"
            run.return_value.stderr = ""
            run.return_value.stdout = "4321"
            run_smoke_test(application_id, root / "review")

            wait.assert_called_once()
            self.assertEqual(wait.call_args.kwargs["timeout_seconds"], 90)
            self.assertEqual(screenshot.call_count, 2)
            self.assertEqual(run.call_count, 2)
            self.assertEqual(
                run.call_args_list[0].args[0],
                ["adb", "shell", "pidof", EXPECTED_APPLICATION_ID],
            )
            self.assertIn("logcat", run.call_args_list[1].args[0])

    def test_smoke_test_rejects_wrong_package_id(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            application_id = root / "application_id.txt"
            application_id.write_text("ir.example.wrong", encoding="utf-8")
            with self.assertRaises(RuntimeError):
                run_smoke_test(application_id, root / "review")


if __name__ == "__main__":
    unittest.main(verbosity=2)
