#!/usr/bin/env python3
"""Capture and validate the branded splash and dashboard on an Android emulator."""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageChops
from dismiss_immersive_prompt import dismiss_immersive_prompt

EXPECTED_APPLICATION_ID = "ir.gas.khorasanjonoubi.danestanihayegaz.debug"
SPLASH_DISPLAY_SECONDS = 5
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def read_accessibility_tree(remote_path: str, local_path: Path) -> ET.Element | None:
    """Best-effort UI hierarchy capture for diagnostics and system-dialog handling."""
    local_path.parent.mkdir(parents=True, exist_ok=True)
    local_path.unlink(missing_ok=True)
    try:
        subprocess.run(
            ["adb", "shell", "uiautomator", "dump", remote_path],
            check=False, capture_output=True, text=True, timeout=20,
        )
        pulled = subprocess.run(
            ["adb", "pull", remote_path, str(local_path)],
            check=False, capture_output=True, text=True, timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if pulled.returncode != 0 or not local_path.is_file():
        return None
    try:
        return ET.parse(local_path).getroot()
    except (OSError, ET.ParseError):
        return None


def capture_screenshot(destination: Path) -> str:
    """Capture a valid PNG and return its SHA-256 digest."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as output:
        subprocess.run(
            ["adb", "exec-out", "screencap", "-p"],
            check=True, stdout=output, timeout=20,
        )
    data = destination.read_bytes()
    if len(data) < 1024 or not data.startswith(PNG_SIGNATURE):
        raise RuntimeError(f"Screenshot is missing, invalid, or unexpectedly small: {destination}")
    return hashlib.sha256(data).hexdigest()


def has_expected_splash(path: Path) -> bool:
    """Reject Android's white launch image; require Flutter's navy splash canvas."""
    with Image.open(path) as source:
        image = source.convert("RGB")
        width, height = image.size
        crop = image.crop((0, int(height * .05), width, int(height * .94)))
        navy = sum(
            1 for r, g, b in crop.getdata()
            if abs(r - 18) <= 12 and abs(g - 59) <= 18 and abs(b - 102) <= 22
        )
        return navy / max(1, crop.width * crop.height) >= .08


def has_meaningful_dashboard(path: Path, splash_path: Path) -> bool:
    """Require a real screen transition away from the poster, not a system overlay."""
    with Image.open(path) as current, Image.open(splash_path) as splash:
        current = current.convert("RGB")
        splash = splash.convert("RGB")
        if current.size != splash.size:
            return True
        diff = ImageChops.difference(current, splash).convert("L")
        changed = diff.point(lambda value: 255 if value > 28 else 0)
        changed_ratio = sum(changed.histogram()[1:]) / max(1, current.width * current.height)
        # The immersive-mode confirmation can cover much of the poster. Do not
        # accept that overlay as the dashboard: after dismissing it, the splash
        # matches the first capture until Flutter navigates to HomePage.
        return changed_ratio >= .12


def capture_diagnostics(output_dir: Path) -> str:
    """Save Flutter/Android errors and foreground activity state."""
    try:
        log = subprocess.run(
            ["adb", "logcat", "-d", "-v", "threadtime", "-s", "flutter:E", "AndroidRuntime:E"],
            check=False, capture_output=True, text=True, timeout=30,
        ).stdout
    except (OSError, subprocess.TimeoutExpired) as error:
        log = f"Could not capture logcat: {error}"
    (output_dir / "android-errors.log").write_text(log, encoding="utf-8")
    try:
        activity = subprocess.run(
            ["adb", "shell", "dumpsys", "activity", "activities"],
            check=False, capture_output=True, text=True, timeout=20,
        ).stdout
    except (OSError, subprocess.TimeoutExpired) as error:
        activity = f"Could not capture activity state: {error}"
    (output_dir / "activity-state.txt").write_text(activity, encoding="utf-8")
    return log


def run_smoke_test(
    application_id_file: Path,
    output_dir: Path,
    *,
    splash_timeout: float = 15,
    dashboard_timeout: float = 30,
) -> None:
    """Verify splash, dismiss Android's prompt, then verify the actual dashboard."""
    application_id = application_id_file.read_text(encoding="utf-8").strip()
    if application_id != EXPECTED_APPLICATION_ID:
        raise RuntimeError(
            f"Unexpected emulator application id: {application_id!r}; "
            f"expected {EXPECTED_APPLICATION_ID!r}"
        )
    if splash_timeout < SPLASH_DISPLAY_SECONDS:
        raise RuntimeError("Splash timeout must allow the configured five-second display.")
    if dashboard_timeout < SPLASH_DISPLAY_SECONDS:
        raise RuntimeError("Dashboard timeout is shorter than the splash display duration.")

    output_dir.mkdir(parents=True, exist_ok=True)
    splash_path = output_dir / "flutter-splash.png"
    deadline = time.monotonic() + splash_timeout
    splash_digest = ""
    while time.monotonic() <= deadline:
        splash_digest = capture_screenshot(splash_path)
        if has_expected_splash(splash_path):
            break
        time.sleep(.5)
    else:
        capture_diagnostics(output_dir)
        raise RuntimeError("Flutter splash was not visually detected; inspect screenshot and diagnostics.")

    dashboard_path = output_dir / "dashboard.png"
    hierarchy_path = output_dir / "dashboard-window.xml"
    deadline = time.monotonic() + dashboard_timeout
    dashboard_digest = ""
    prompt_dismissed = False
    while time.monotonic() <= deadline:
        tree = read_accessibility_tree("/sdcard/danestani-dashboard.xml", hierarchy_path)
        if tree is not None and dismiss_immersive_prompt(hierarchy_path):
            prompt_dismissed = True
            time.sleep(.5)
            continue
        dashboard_digest = capture_screenshot(dashboard_path)
        if has_meaningful_dashboard(dashboard_path, splash_path):
            break
        time.sleep(.5)
    else:
        capture_diagnostics(output_dir)
        reason = "Android prompt was dismissed but Flutter remained on splash." if prompt_dismissed else "Dashboard did not appear."
        raise RuntimeError(f"{reason} Inspect screenshot and diagnostic logs.")

    process = subprocess.run(
        ["adb", "shell", "pidof", application_id],
        check=False, capture_output=True, text=True, timeout=20,
    )
    if process.returncode != 0 or not process.stdout.strip():
        capture_diagnostics(output_dir)
        raise RuntimeError("The app process is not running after the dashboard transition.")

    crash_log = capture_diagnostics(output_dir)
    if any(marker in crash_log for marker in (
        "FATAL EXCEPTION", "E/flutter", "Unhandled Exception",
        "Exception caught by widgets library",
    )):
        raise RuntimeError("Flutter or Android runtime errors were logged; inspect android-errors.log.")
    if splash_digest == dashboard_digest:
        raise RuntimeError("Splash and dashboard screenshots are identical.")

    print("Verified splash, dismissed Android immersive prompt, detected dashboard transition, live process and clean runtime logs.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application-id-file", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--splash-timeout", type=float, default=15)
    parser.add_argument("--dashboard-timeout", type=float, default=30)
    args = parser.parse_args()
    try:
        run_smoke_test(
            args.application_id_file, args.output_dir,
            splash_timeout=args.splash_timeout,
            dashboard_timeout=args.dashboard_timeout,
        )
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Android emulator smoke test failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
