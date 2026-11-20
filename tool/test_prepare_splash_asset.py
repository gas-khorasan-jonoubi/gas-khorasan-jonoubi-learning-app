#!/usr/bin/env python3
"""Unit tests for the reproducible approved splash WebP optimizer."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_splash_asset import prepare_splash_asset  # noqa: E402


class PrepareSplashAssetTest(unittest.TestCase):
    def test_preserves_dimensions_and_creates_smaller_webp(self) -> None:
        source = Path("assets/approved_splash.png")
        self.assertTrue(source.is_file(), "approved splash source must exist")

        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "approved_splash.webp"
            width, height, source_size, output_size = prepare_splash_asset(
                source,
                output,
                quality=92,
            )

            self.assertTrue(output.is_file())
            self.assertGreater(width, 0)
            self.assertGreater(height, 0)
            self.assertGreater(source_size, output_size)

            with Image.open(output) as image:
                self.assertEqual(image.format, "WEBP")
                self.assertEqual(image.size, (width, height))

    def test_rejects_quality_outside_supported_range(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "invalid.webp"
            with self.assertRaises(ValueError):
                prepare_splash_asset(
                    Path("assets/approved_splash.png"),
                    output,
                    quality=101,
                )

    def test_rejects_missing_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "missing.webp"
            with self.assertRaises(FileNotFoundError):
                prepare_splash_asset(
                    Path(temporary) / "missing.png",
                    output,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
