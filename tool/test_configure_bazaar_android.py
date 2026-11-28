#!/usr/bin/env python3
"""Unit tests for the generated Android Cafe Bazaar host configuration."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from configure_bazaar_android import configure_android  # noqa: E402


class ConfigureBazaarAndroidTest(unittest.TestCase):
    def _make_project(self, kotlin_dsl: bool) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        android = Path(temporary.name) / "android"
        app_main = android / "app" / "src" / "main"
        app_main.mkdir(parents=True)
        (app_main / "AndroidManifest.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <application>\n    </application>\n</manifest>\n',
            encoding="utf-8",
        )

        if kotlin_dsl:
            (android / "build.gradle.kts").write_text(
                "allprojects {\n    repositories {\n        google()\n"
                "        mavenCentral()\n    }\n}\n",
                encoding="utf-8",
            )
            (android / "app" / "build.gradle.kts").write_text(
                "android {\n    defaultConfig {\n"
                "        minSdk = flutter.minSdkVersion\n"
                "    }\n"
                "    buildTypes {\n"
                "        release {\n"
                "            signingConfig = signingConfigs.getByName(\"debug\")\n"
                "        }\n"
                "    }\n"
                "}\n",
                encoding="utf-8",
            )
            package = app_main / "kotlin" / "com" / "example"
            package.mkdir(parents=True)
            (package / "MainActivity.kt").write_text(
                "package com.example\n"
                "import io.flutter.embedding.android.FlutterActivity\n"
                "class MainActivity : FlutterActivity()\n",
                encoding="utf-8",
            )
        else:
            (android / "build.gradle").write_text(
                "allprojects {\n    repositories {\n"
                "        google()\n        mavenCentral()\n"
                "    }\n}\n",
                encoding="utf-8",
            )
            (android / "app" / "build.gradle").write_text(
                "android {\n    defaultConfig {\n"
                "        minSdkVersion flutter.minSdkVersion\n"
                "    }\n"
                "    buildTypes {\n"
                "        release {\n"
                "            signingConfig signingConfigs.debug\n"
                "        }\n"
                "    }\n"
                "}\n",
                encoding="utf-8",
            )
            package = app_main / "java" / "com" / "example"
            package.mkdir(parents=True)
            (package / "MainActivity.java").write_text(
                "package com.example;\n"
                "import io.flutter.embedding.android.FlutterActivity;\n"
                "public class MainActivity extends FlutterActivity {}\n",
                encoding="utf-8",
            )
        return android

    def test_configures_kotlin_gradle_host(self) -> None:
        android = self._make_project(kotlin_dsl=True)
        configure_android(android, application_id="ir.gas.khorasanjonoubi.danestani_gaz")
        root_gradle = (android / "build.gradle.kts").read_text(encoding="utf-8")
        app_gradle = (android / "app" / "build.gradle.kts").read_text(encoding="utf-8")
        activity = next((android / "app" / "src" / "main").rglob("MainActivity.kt"))
        activity_text = activity.read_text(encoding="utf-8")

        self.assertIn("https://jitpack.io", root_gradle)
        self.assertIn('includeGroup("com.github.cafebazaar.Poolakey")', root_gradle)
        self.assertIn("minSdk = 24", app_gradle)
        self.assertIn('applicationId = "ir.gas.khorasanjonoubi.danestani_gaz"', app_gradle)
        self.assertIn("FlutterFragmentActivity", activity_text)
        self.assertIn("danestani_gaz/contact_picker", activity_text)
        self.assertIn("ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE", activity_text)
        self.assertIn("CONTACT_PICK_REQUEST", activity_text)
        manifest = (android / "app" / "src" / "main" / "AndroidManifest.xml").read_text(encoding="utf-8")
        self.assertIn("<queries>", manifest)
        self.assertIn("android.speech.RecognitionService", manifest)
        self.assertIn("android.permission.RECORD_AUDIO", manifest)
        self.assertIn("com.yalantis.ucrop.UCropActivity", manifest)
        self.assertNotIn("class MainActivity : FlutterActivity", activity_text)
        manifest = (android / "app" / "src" / "main" / "AndroidManifest.xml").read_text(encoding="utf-8")
        self.assertIn("<queries>", manifest)
        self.assertIn("android.speech.RecognitionService", manifest)

    def test_configures_groovy_gradle_host(self) -> None:
        android = self._make_project(kotlin_dsl=False)
        configure_android(android, application_id="ir.gas.khorasanjonoubi.danestani_gaz")
        root_gradle = (android / "build.gradle").read_text(encoding="utf-8")
        app_gradle = (android / "app" / "build.gradle").read_text(encoding="utf-8")
        activity = next((android / "app" / "src" / "main").rglob("MainActivity.java"))
        activity_text = activity.read_text(encoding="utf-8")

        self.assertIn("https://jitpack.io", root_gradle)
        self.assertIn("minSdkVersion 24", app_gradle)
        manifest = (android / "app" / "src" / "main" / "AndroidManifest.xml").read_text(encoding="utf-8")
        self.assertIn("android.permission.RECORD_AUDIO", manifest)
        self.assertIn("com.yalantis.ucrop.UCropActivity", manifest)
        self.assertIn("android.speech.RecognitionService", manifest)
        self.assertIn('applicationId "ir.gas.khorasanjonoubi.danestani_gaz"', app_gradle)
        self.assertIn("FlutterFragmentActivity", activity_text)
        self.assertIn("danestani_gaz/contact_picker", activity_text)
        self.assertIn("ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE", activity_text)

    def _signing_environment(self) -> dict[str, str]:
        return {
            "CM_KEYSTORE_PATH": "/private/test-release.keystore",
            "CM_KEYSTORE_PASSWORD": "not-a-real-password",
            "CM_KEY_ALIAS": "test-release",
            "CM_KEY_PASSWORD": "not-a-real-key-password",
        }

    def test_configures_kotlin_release_signing_without_embedding_secrets(self) -> None:
        android = self._make_project(kotlin_dsl=True)
        configure_android(android, signing_environment=self._signing_environment())
        app_gradle = (android / "app" / "build.gradle.kts").read_text(encoding="utf-8")

        self.assertIn('create("release")', app_gradle)
        self.assertIn('signingConfig = signingConfigs.getByName("release")', app_gradle)
        self.assertNotIn('signingConfig = signingConfigs.getByName("debug")', app_gradle)
        self.assertIn('System.getenv("CM_KEYSTORE_PASSWORD")', app_gradle)
        self.assertNotIn("not-a-real-password", app_gradle)
        self.assertNotIn("/private/test-release.keystore", app_gradle)

    def test_configures_groovy_release_signing_without_embedding_secrets(self) -> None:
        android = self._make_project(kotlin_dsl=False)
        configure_android(android, signing_environment=self._signing_environment())
        app_gradle = (android / "app" / "build.gradle").read_text(encoding="utf-8")

        self.assertIn("signingConfigs {", app_gradle)
        self.assertIn("signingConfig signingConfigs.release", app_gradle)
        self.assertNotIn("signingConfig signingConfigs.debug", app_gradle)
        self.assertIn('System.getenv("CM_KEYSTORE_PASSWORD")', app_gradle)
        self.assertNotIn("not-a-real-password", app_gradle)

    def test_partial_signing_environment_fails_closed(self) -> None:
        android = self._make_project(kotlin_dsl=True)
        with self.assertRaisesRegex(RuntimeError, "partially configured"):
            configure_android(
                android,
                signing_environment={"CM_KEYSTORE_PATH": "/private/key.keystore"},
            )

    def test_configuration_is_idempotent(self) -> None:
        android = self._make_project(kotlin_dsl=True)
        signing_environment = self._signing_environment()
        configure_android(android, signing_environment=signing_environment)
        configure_android(android, signing_environment=signing_environment)
        root_gradle = (android / "build.gradle.kts").read_text(encoding="utf-8")
        app_gradle = (android / "app" / "build.gradle.kts").read_text(encoding="utf-8")
        self.assertEqual(root_gradle.count("https://jitpack.io"), 1)
        activity = next((android / "app" / "src" / "main").rglob("MainActivity.kt"))
        activity_text = activity.read_text(encoding="utf-8")
        self.assertEqual(activity_text.count("danestani_gaz/contact_picker"), 1)
        manifest = (android / "app" / "src" / "main" / "AndroidManifest.xml").read_text(encoding="utf-8")
        self.assertEqual(manifest.count("<queries>"), 1)
        self.assertEqual(manifest.count("android.speech.RecognitionService"), 1)
        self.assertEqual(manifest.count("android.permission.RECORD_AUDIO"), 1)
        self.assertEqual(manifest.count("com.yalantis.ucrop.UCropActivity"), 1)
        self.assertEqual(app_gradle.count('create("release")'), 1)
        self.assertEqual(
            app_gradle.count('signingConfig = signingConfigs.getByName("release")'),
            1,
        )

    def test_invalid_application_id_fails_clearly(self) -> None:
        android = self._make_project(kotlin_dsl=True)
        with self.assertRaisesRegex(RuntimeError, "valid Android application ID"):
            configure_android(android, application_id="invalid package id")

    def test_application_id_is_inserted_when_missing(self) -> None:
        android = self._make_project(kotlin_dsl=True)
        app_gradle_path = android / "app" / "build.gradle.kts"
        source = app_gradle_path.read_text(encoding="utf-8")
        app_gradle_path.write_text(source, encoding="utf-8")
        configure_android(android, application_id="ir.gas.khorasanjonoubi.danestani_gaz")
        updated = app_gradle_path.read_text(encoding="utf-8")
        self.assertIn(
            'applicationId = "ir.gas.khorasanjonoubi.danestani_gaz"',
            updated,
        )

    def test_missing_activity_fails_clearly(self) -> None:
        android = self._make_project(kotlin_dsl=True)
        activity = next((android / "app" / "src" / "main").rglob("MainActivity.kt"))
        activity.unlink()
        with self.assertRaisesRegex(RuntimeError, "MainActivity"):
            configure_android(android)


if __name__ == "__main__":
    unittest.main(verbosity=2)
