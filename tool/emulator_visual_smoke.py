#!/usr/bin/env python3
"""Capture and validate the branded splash and dashboard on an Android emulator.

Flutter's semantics tree is not guaranteed to be exposed to UIAutomator unless
an accessibility service is active. Therefore UIAutomator text lookup is kept
diagnostic-only and is never used as a release-blocking assertion.
"""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

EXPECTED_APPLICATION_ID = "ir.gas.khorasanjonoubi.danestanihayegaz.debug"
SPLASH_DISPLAY_SECONDS = 5
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def read_accessibility_tree(remote_path: str, local_path: Path) -> ET.Element | None:
    """Best-effort UI hierarchy capture for diagnostics; it may be unavailable."""
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


def run_smoke_test(
    application_id_file: Path,
    output_dir: Path,
    *,
    splash_timeout: float = 15,
    dashboard_timeout: float = 30,
) -> None:
    """Verify package launch, capture both screens, and reject Android crashes."""
    application_id = application_id_file.read_text(encoding="utf-8").strip()
    if application_id != EXPECTED_APPLICATION_ID:
        raise RuntimeError(
            f"Unexpected emulator application id: {application_id!r}; "
            f"expected {EXPECTED_APPLICATION_ID!r}"
        )

    # Validate all timing constraints before touching the emulator or taking
    # screenshots, so invalid test configuration fails fast and predictably.
    if splash_timeout < SPLASH_DISPLAY_SECONDS:
        raise RuntimeError("Splash timeout must allow the configured five-second display.")
    transition_wait = min(SPLASH_DISPLAY_SECONDS + 2, dashboard_timeout)
    if transition_wait < SPLASH_DISPLAY_SECONDS:
        raise RuntimeError("Dashboard timeout is shorter than the splash display duration.")

    output_dir.mkdir(parents=True, exist_ok=True)
    # Capture the first Flutter frame promptly, before any slow diagnostic command.
    time.sleep(0.5)
    splash_digest = capture_screenshot(output_dir / "flutter-splash.png")

    # The app preloads its local WebP poster before starting the five-second
    # display timer. Wait beyond that interval, without relying on UIAutomator
    # exposing Flutter semantics to an accessibility service.
    time.sleep(transition_wait)
    dashboard_digest = capture_screenshot(output_dir / "dashboard.png")
    if splash_digest == dashboard_digest:
        raise RuntimeError("Splash and dashboard screenshots are identical; screen transition was not observed.")

    process = subprocess.run(
        ["adb", "shell", "pidof", application_id],
        check=False, capture_output=True, text=True, timeout=20,
    )
    if process.returncode != 0 or not process.stdout.strip():
        raise RuntimeError("The app process is not running after the expected dashboard transition.")

    crash_log = subprocess.run(
        ["adb", "logcat", "-d", "-s", "AndroidRuntime:E"],
        check=True, capture_output=True, text=True, timeout=30,
    ).stdout
    (output_dir / "android-runtime.log").write_text(crash_log, encoding="utf-8")
    if "FATAL EXCEPTION" in crash_log:
        raise RuntimeError("AndroidRuntime reported a fatal exception; see android-runtime.log.")

    # Preserve an optional hierarchy snapshot for later manual inspection.
    read_accessibility_tree(
        "/sdcard/danestani-dashboard.xml",
        output_dir / "dashboard-window.xml",
    )
    print("Verified app launch, distinct splash/dashboard screenshots, live process and no fatal Android exception.")


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
