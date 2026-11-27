#!/usr/bin/env python3
"""Unit tests for Android emulator visual smoke-test helpers."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image, ImageDraw
from emulator_visual_smoke import (
    EXPECTED_APPLICATION_ID, capture_screenshot, has_expected_splash,
    has_meaningful_dashboard, run_smoke_test,
)


class EmulatorVisualSmokeTest(unittest.TestCase):
    @patch("emulator_visual_smoke.read_accessibility_tree", return_value=None)
    @patch("emulator_visual_smoke.capture_diagnostics", return_value="")
    @patch("emulator_visual_smoke.subprocess.run")
    @patch("emulator_visual_smoke.time.monotonic", side_effect=[0, 0, 6, 6])
    @patch("emulator_visual_smoke.time.sleep")
    @patch("emulator_visual_smoke.capture_screenshot", side_effect=["splash-hash", "dashboard-hash"])
    @patch("emulator_visual_smoke.has_expected_splash", return_value=True)
    @patch("emulator_visual_smoke.has_meaningful_dashboard", return_value=True)
    def test_smoke_test_accepts_two_visible_screens(
        self, dashboard, splash, screenshot, sleep, monotonic, run, diagnostics, accessibility
    ):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "application_id.txt"
            package.write_text(EXPECTED_APPLICATION_ID, encoding="utf-8")
            reference = root / "approved_splash.png"
            Image.new("RGB", (108, 192), (18, 59, 102)).save(reference)
            run.return_value.returncode = 0
            run.return_value.stdout = "4321"
            run_smoke_test(package, root / "review", splash_reference=reference)
            self.assertEqual(screenshot.call_count, 2)
            self.assertEqual(run.call_count, 1)
            diagnostics.assert_called_once()
            accessibility.assert_called_once()

    @patch("emulator_visual_smoke.read_accessibility_tree", return_value=object())
    @patch("emulator_visual_smoke.dismiss_immersive_prompt", return_value=True)
    @patch("emulator_visual_smoke.capture_diagnostics", return_value="")
    @patch("emulator_visual_smoke.has_meaningful_dashboard", return_value=False)
    @patch("emulator_visual_smoke.has_expected_splash", return_value=True)
    @patch("emulator_visual_smoke.capture_screenshot", return_value="same")
    @patch("emulator_visual_smoke.time.monotonic", side_effect=[0, 0, 6, 6, 40])
    @patch("emulator_visual_smoke.time.sleep")
    def test_smoke_test_rejects_splash_still_visible_after_prompt(
        self, sleep, monotonic, screenshot, splash, dashboard, diagnostics, dismiss_prompt, accessibility
    ):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "application_id.txt"
            package.write_text(EXPECTED_APPLICATION_ID, encoding="utf-8")
            reference = root / "approved_splash.png"
            Image.new("RGB", (108, 192), (18, 59, 102)).save(reference)
            with self.assertRaisesRegex(RuntimeError, "remained on splash"):
                run_smoke_test(package, root / "review", dashboard_timeout=30, splash_reference=reference)
            diagnostics.assert_called_once()
            dismiss_prompt.assert_called_once()

    def test_splash_detector_matches_approved_artwork_not_just_navy_color(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            reference = root / "approved.png"
            splash = root / "splash.png"
            dashboard = root / "dashboard.png"
            artwork = Image.new("RGB", (108, 192), "white")
            draw = ImageDraw.Draw(artwork)
            draw.rectangle((0, 0, 107, 35), fill=(18, 59, 102))
            draw.ellipse((25, 55, 82, 112), fill=(230, 180, 40))
            draw.rectangle((8, 130, 100, 175), fill=(30, 90, 140))
            artwork.save(reference)
            artwork.save(splash)
            self.assertTrue(has_expected_splash(splash, reference))

            # A dashboard with the same navy app bar must not pass as splash.
            home = Image.new("RGB", (108, 192), (246, 248, 251))
            ImageDraw.Draw(home).rectangle((0, 0, 107, 35), fill=(18, 59, 102))
            ImageDraw.Draw(home).rounded_rectangle((5, 45, 103, 180), radius=8, fill=(240, 240, 245))
            home.save(dashboard)
            self.assertFalse(has_expected_splash(dashboard, reference))

            white = Image.new("RGB", (108, 192), "white")
            white.save(dashboard)
            self.assertFalse(has_expected_splash(dashboard, reference))

    def test_splash_detector_matches_flutter_box_fit_contain_letterboxing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            reference = root / "approved.png"
            captured = root / "captured.png"
            artwork = Image.new("RGB", (100, 200), (18, 59, 102))
            draw = ImageDraw.Draw(artwork)
            draw.ellipse((20, 70, 80, 130), fill=(230, 180, 40))
            artwork.save(reference)

            # 108x192 screen: BoxFit.contain scales the 100x200 image
            # to 96x192 and centers it, leaving six black pixels per side.
            screen = Image.new("RGB", (108, 192), (0, 0, 0))
            fitted = artwork.resize((96, 192), Image.Resampling.BILINEAR)
            screen.paste(fitted, (6, 0))
            screen.save(captured)
            self.assertTrue(has_expected_splash(captured, reference))

    def test_dashboard_detector_rejects_splash_and_accepts_transition(self):
        with tempfile.TemporaryDirectory() as temporary:
            splash = Path(temporary) / "splash.png"
            dashboard = Path(temporary) / "dashboard.png"
            Image.new("RGB", (108, 192), (18, 59, 102)).save(splash)
            Image.new("RGB", (108, 192), (18, 59, 102)).save(dashboard)
            self.assertFalse(has_meaningful_dashboard(dashboard, splash))
            image = Image.new("RGB", (108, 192), (246, 248, 251))
            ImageDraw.Draw(image).rectangle((0, 0, 107, 22), fill=(18, 59, 102))
            ImageDraw.Draw(image).rectangle((5, 35, 103, 100), fill=(240, 240, 240))
            image.save(dashboard)
            self.assertTrue(has_meaningful_dashboard(dashboard, splash))

    def test_capture_screenshot_accepts_real_png_signature(self):
        with patch("emulator_visual_smoke.subprocess.run") as run:
            run.side_effect = lambda command, *, stdout, **kwargs: stdout.write(b"\x89PNG\r\n\x1a\n" + b"0" * 2048)
            with tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary) / "screen.png"
                self.assertEqual(len(capture_screenshot(path)), 64)

    def test_capture_screenshot_rejects_non_png_bytes(self):
        with patch("emulator_visual_smoke.subprocess.run") as run:
            run.side_effect = lambda command, *, stdout, **kwargs: stdout.write(b"not-a-png" + b"0" * 2048)
            with tempfile.TemporaryDirectory() as temporary:
                with self.assertRaisesRegex(RuntimeError, "invalid"):
                    capture_screenshot(Path(temporary) / "screen.png")

    def test_smoke_test_rejects_wrong_package_id(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "application_id.txt"
            package.write_text("ir.example.wrong", encoding="utf-8")
            with self.assertRaises(RuntimeError):
                run_smoke_test(package, root / "review")

    def test_smoke_test_requires_five_second_splash_window(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "application_id.txt"
            package.write_text(EXPECTED_APPLICATION_ID, encoding="utf-8")
            with patch("emulator_visual_smoke.capture_screenshot") as screenshot:
                with self.assertRaisesRegex(RuntimeError, "five-second"):
                    run_smoke_test(package, root / "review", splash_timeout=4)
                screenshot.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
