#!/usr/bin/env python3
"""Run a reliable Android emulator smoke test for the branded splash and dashboard."""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Iterable

from dismiss_immersive_prompt import dismiss_immersive_prompt


SPLASH_LABELS = {
    "شرکت گاز خراسان جنوبی",
    "شهرستان عشق آباد",
    "اداره گاز عشق آباد",
}
EXPECTED_APPLICATION_ID = "ir.gas.khorasanjonoubi.danestanihayegaz.debug"


def accessible_texts(root: ET.Element) -> set[str]:
    """Return visible/accessibility text labels from a UIAutomator hierarchy."""
    return {
        value.strip()
        for node in root.iter("node")
        for value in (node.attrib.get("text", ""), node.attrib.get("content-desc", ""))
        if value.strip()
    }


def read_accessibility_tree(remote_path: str, local_path: Path) -> ET.Element | None:
    """Dump and pull the current hierarchy; return None while Android UI is not ready."""
    local_path.parent.mkdir(parents=True, exist_ok=True)
    local_path.unlink(missing_ok=True)

    try:
        subprocess.run(
            ["adb", "shell", "uiautomator", "dump", remote_path],
            check=False,
            capture_output=True,
            text=True,
            timeout=20,
        )
        pulled = subprocess.run(
            ["adb", "pull", remote_path, str(local_path)],
            check=False,
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None

    if pulled.returncode != 0 or not local_path.is_file():
        return None
    try:
        return ET.parse(local_path).getroot()
    except (OSError, ET.ParseError):
        return None


def wait_for_labels(
    expected: Iterable[str],
    *,
    remote_path: str,
    local_path: Path,
    timeout_seconds: float,
    poll_interval: float = 0.5,
) -> set[str]:
    """Wait for accessible labels, safely dismissing Android's optional 'Got it' prompt."""
    expected_set = set(expected)
    deadline = time.monotonic() + timeout_seconds
    last_labels: set[str] = set()

    while time.monotonic() < deadline:
        root = read_accessibility_tree(remote_path, local_path)
        if root is not None:
            last_labels = accessible_texts(root)
            if any(label.casefold() == "got it" for label in last_labels):
                dismiss_immersive_prompt(local_path)
                time.sleep(poll_interval)
                continue
            if expected_set.issubset(last_labels):
                return last_labels
        time.sleep(poll_interval)

    missing = sorted(expected_set - last_labels)
    raise TimeoutError(
        f"Timed out waiting for Android UI labels: {missing or sorted(expected_set)}"
    )


def capture_screenshot(destination: Path) -> None:
    """Write a PNG screenshot from the connected emulator."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as output:
        subprocess.run(
            ["adb", "exec-out", "screencap", "-p"],
            check=True,
            stdout=output,
            timeout=20,
        )
    if destination.stat().st_size < 1024:
        raise RuntimeError(f"Screenshot is unexpectedly small: {destination}")


def run_smoke_test(
    application_id_file: Path,
    output_dir: Path,
    *,
    splash_timeout: float = 60,
    dashboard_timeout: float = 30,
) -> None:
    """Verify splash text, dashboard text, app process and Android crash log."""
    application_id = application_id_file.read_text(encoding="utf-8").strip()
    if application_id != EXPECTED_APPLICATION_ID:
        raise RuntimeError(
            f"Unexpected emulator application id: {application_id!r}; "
            f"expected {EXPECTED_APPLICATION_ID!r}"
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    wait_for_labels(
        SPLASH_LABELS,
        remote_path="/sdcard/danestani-splash.xml",
        local_path=output_dir / "splash-window.xml",
        timeout_seconds=splash_timeout,
    )
    capture_screenshot(output_dir / "flutter-splash.png")

    wait_for_labels(
        {"داشبورد"},
        remote_path="/sdcard/danestani-dashboard.xml",
        local_path=output_dir / "dashboard-window.xml",
        timeout_seconds=dashboard_timeout,
    )
    capture_screenshot(output_dir / "dashboard.png")

    process = subprocess.run(
        ["adb", "shell", "pidof", application_id],
        check=False,
        capture_output=True,
        text=True,
        timeout=20,
    )
    if process.returncode != 0 or not process.stdout.strip():
        raise RuntimeError("The app process is not running after the dashboard appeared.")

    crash_log = subprocess.run(
        ["adb", "logcat", "-d", "-s", "AndroidRuntime:E"],
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    ).stdout
    (output_dir / "android-runtime.log").write_text(crash_log, encoding="utf-8")
    if "FATAL EXCEPTION" in crash_log:
        raise RuntimeError("AndroidRuntime reported a fatal exception; see android-runtime.log.")

    print("Verified branded splash labels, dashboard title, screenshots and app process.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application-id-file", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--splash-timeout", type=float, default=60)
    parser.add_argument("--dashboard-timeout", type=float, default=30)
    args = parser.parse_args()

    try:
        run_smoke_test(
            args.application_id_file,
            args.output_dir,
            splash_timeout=args.splash_timeout,
            dashboard_timeout=args.dashboard_timeout,
        )
    except (OSError, RuntimeError, TimeoutError, subprocess.SubprocessError) as error:
        print(f"Android emulator smoke test failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
