#!/usr/bin/env python3
"""Dismiss Android's one-time immersive-mode confirmation in emulator smoke tests."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


BOUNDS_PATTERN = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")


def dismiss_immersive_prompt(window_dump: Path) -> bool:
    """Tap the center of an accessible 'Got it' node; otherwise do nothing."""
    if not window_dump.is_file():
        print(f"No Android window dump found at {window_dump}; nothing to dismiss.")
        return False

    try:
        root = ET.parse(window_dump).getroot()
    except (OSError, ET.ParseError) as error:
        print(f"Could not read Android window dump: {error}", file=sys.stderr)
        return False

    for node in root.iter("node"):
        if node.attrib.get("text", "").strip().casefold() != "got it":
            continue

        match = BOUNDS_PATTERN.fullmatch(node.attrib.get("bounds", ""))
        if match is None:
            continue

        left, top, right, bottom = map(int, match.groups())
        x = (left + right) // 2
        y = (top + bottom) // 2
        subprocess.run(
            ["adb", "shell", "input", "tap", str(x), str(y)],
            check=True,
        )
        print("Dismissed Android immersive-mode confirmation.")
        return True

    print("No immersive-mode confirmation was present.")
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("window_dump", type=Path)
    args = parser.parse_args()
    dismiss_immersive_prompt(args.window_dump)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
