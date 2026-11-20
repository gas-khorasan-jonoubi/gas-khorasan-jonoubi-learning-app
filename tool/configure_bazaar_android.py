#!/usr/bin/env python3
"""Configure the Android host project for Cafe Bazaar billing.

This script changes only the generated Android host configuration. It does not
build an APK. It is intentionally idempotent so CI and Codemagic can both run it.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def _configure_jitpack(android: Path) -> None:
    kotlin_gradle = android / "build.gradle.kts"
    groovy_gradle = android / "build.gradle"
    gradle_file = kotlin_gradle if kotlin_gradle.is_file() else groovy_gradle
    if not gradle_file.is_file():
        raise RuntimeError("Android root Gradle file was not generated.")

    source = gradle_file.read_text(encoding="utf-8")
    if "https://jitpack.io" in source:
        return

    if gradle_file.suffix == ".kts":
        repository = """
            maven {
                url = uri("https://jitpack.io")
                content {
                    includeGroup("com.github.cafebazaar.Poolakey")
                    includeGroup("com.github.myketstore")
                }
            }
        """
    else:
        repository = """
            maven {
                url 'https://jitpack.io'
            }
        """

    pattern = re.compile(r"(allprojects\s*\{\s*repositories\s*\{)")
    updated, count = pattern.subn(
        lambda match: match.group(1) + repository,
        source,
        count=1,
    )
    if count != 1:
        raise RuntimeError(
            "Could not add JitPack to the Android allprojects repositories."
        )
    gradle_file.write_text(updated, encoding="utf-8")


def _configure_activity(android: Path) -> None:
    source_root = android / "app" / "src" / "main"
    candidates = [
        path
        for path in source_root.rglob("*")
        if path.is_file()
        and path.name in {"MainActivity.kt", "MainActivity.java"}
    ] if source_root.is_dir() else []

    if len(candidates) != 1:
        raise RuntimeError(
            f"Expected exactly one MainActivity.kt or MainActivity.java, "
            f"found {len(candidates)}."
        )

    activity_file = candidates[0]
    source = activity_file.read_text(encoding="utf-8")

    if "FlutterFragmentActivity" not in source:
        source = source.replace(
            "import io.flutter.embedding.android.FlutterActivity",
            "import io.flutter.embedding.android.FlutterFragmentActivity",
        )

        if activity_file.suffix == ".kt":
            source, count = re.subn(
                r"(class\s+MainActivity\s*:\s*)FlutterActivity(\s*\(\s*\))",
                r"\1FlutterFragmentActivity\2",
                source,
                count=1,
            )
        else:
            source, count = re.subn(
                r"(class\s+MainActivity\s+extends\s+)FlutterActivity",
                r"\1FlutterFragmentActivity",
                source,
                count=1,
            )

        if count != 1:
            raise RuntimeError(
                "Could not change MainActivity to FlutterFragmentActivity."
            )

    if "FlutterFragmentActivity" not in source:
        raise RuntimeError("MainActivity is not ActivityResult-compatible.")

    activity_file.write_text(source, encoding="utf-8")


def _configure_min_sdk(android: Path) -> None:
    kotlin_gradle = android / "app" / "build.gradle.kts"
    groovy_gradle = android / "app" / "build.gradle"
    gradle_file = kotlin_gradle if kotlin_gradle.is_file() else groovy_gradle
    if not gradle_file.is_file():
        raise RuntimeError("Android app Gradle file was not generated.")

    source = gradle_file.read_text(encoding="utf-8")
    if gradle_file.suffix == ".kts":
        if re.search(r"minSdk\s*=\s*24\b", source):
            return
        updated, count = re.subn(
            r"minSdk\s*=\s*[^\s]+",
            "minSdk = 24",
            source,
            count=1,
        )
    else:
        if re.search(r"minSdkVersion\s+24\b", source):
            return
        updated, count = re.subn(
            r"minSdkVersion\s+[^\s]+",
            "minSdkVersion 24",
            source,
            count=1,
        )

    if count != 1:
        raise RuntimeError("Could not set Android minSdk to 24.")
    gradle_file.write_text(updated, encoding="utf-8")


def configure_android(android_directory: Path) -> None:
    if not android_directory.is_dir():
        raise RuntimeError(f"Android directory does not exist: {android_directory}")
    _configure_jitpack(android_directory)
    _configure_activity(android_directory)
    _configure_min_sdk(android_directory)


def main() -> int:
    android_directory = Path(__file__).resolve().parents[1] / "android"
    try:
        configure_android(android_directory)
    except (OSError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("OK: Cafe Bazaar Android host configured (JitPack, FragmentActivity, minSdk 24).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
