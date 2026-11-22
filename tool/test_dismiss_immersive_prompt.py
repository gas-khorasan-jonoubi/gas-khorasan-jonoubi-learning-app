#!/usr/bin/env python3
"""Unit tests for the emulator immersive-mode dialog helper."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from dismiss_immersive_prompt import dismiss_immersive_prompt


class DismissImmersivePromptTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.window_dump = Path(self.temp_dir.name) / "window.xml"

    def write_xml(self, content: str) -> None:
        self.window_dump.write_text(content, encoding="utf-8")

    @patch("dismiss_immersive_prompt.subprocess.run")
    def test_taps_center_of_accessible_got_it_button(self, run) -> None:
        self.write_xml(
            '<hierarchy><node text="Got it" bounds="[10,20][110,60]" /></hierarchy>'
        )

        self.assertTrue(dismiss_immersive_prompt(self.window_dump))
        run.assert_called_once_with(
            ["adb", "shell", "input", "tap", "60", "40"],
            check=True,
        )

    @patch("dismiss_immersive_prompt.subprocess.run")
    def test_does_not_tap_when_prompt_is_absent(self, run) -> None:
        self.write_xml(
            '<hierarchy><node text="Settings" bounds="[10,20][110,60]" /></hierarchy>'
        )

        self.assertFalse(dismiss_immersive_prompt(self.window_dump))
        run.assert_not_called()

    @patch("dismiss_immersive_prompt.subprocess.run")
    def test_does_not_tap_when_got_it_bounds_are_invalid(self, run) -> None:
        self.write_xml('<hierarchy><node text="Got it" bounds="unknown" /></hierarchy>')

        self.assertFalse(dismiss_immersive_prompt(self.window_dump))
        run.assert_not_called()

    @patch("dismiss_immersive_prompt.subprocess.run")
    def test_missing_or_malformed_dump_is_safe(self, run) -> None:
        self.assertFalse(dismiss_immersive_prompt(self.window_dump))
        self.write_xml("<hierarchy><node")
        self.assertFalse(dismiss_immersive_prompt(self.window_dump))
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
