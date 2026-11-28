#!/usr/bin/env python3
"""Configure the Android host project for Cafe Bazaar billing.

This script changes only the generated Android host configuration. It does not
build an APK. It is intentionally idempotent so CI and Codemagic can both run it.
"""

from __future__ import annotations

import os
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


def _configure_speech_queries(android: Path) -> None:
    manifest = android / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.is_file():
        raise RuntimeError("AndroidManifest.xml was not generated.")
    source = manifest.read_text(encoding="utf-8")
    additions = ""
    if "android.permission.RECORD_AUDIO" not in source:
        additions += '\n    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n'
    if "android.speech.RecognitionService" not in source:
        additions += """
    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
    </queries>
"""
    if not additions:
        return
    updated, count = re.subn(
        r"(<manifest\b[^>]*>)",
        lambda match: match.group(1) + additions,
        source,
        count=1,
    )
    if count != 1:
        raise RuntimeError("Could not configure Android microphone permission and speech recognition visibility.")
    manifest.write_text(updated, encoding="utf-8")



def _configure_contact_picker(android: Path) -> None:
    """Install a native, single-number contact picker with URI-grant access."""
    source_root = android / "app" / "src" / "main"
    candidates = [
        path
        for path in source_root.rglob("*")
        if path.is_file() and path.name in {"MainActivity.kt", "MainActivity.java"}
    ] if source_root.is_dir() else []
    if len(candidates) != 1:
        raise RuntimeError(
            f"Expected exactly one MainActivity.kt or MainActivity.java, found {len(candidates)}."
        )

    activity_file = candidates[0]
    source = activity_file.read_text(encoding="utf-8")
    if "danestani_gaz/contact_picker" in source:
        return

    if activity_file.suffix == ".kt":
        extra_imports = """import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.ContactsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel"""
        package_match = re.search(r"(?m)^package\s+[\w.]+\s*$", source)
        if package_match is None:
            raise RuntimeError("Could not find the MainActivity Kotlin package declaration.")
        source = source[:package_match.end()] + "\n\n" + extra_imports + source[package_match.end():]
        activity = r'''class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CONTACT_PICK_REQUEST = 7321
        private const val CONTACT_CHANNEL = "danestani_gaz/contact_picker"
    }

    private var pendingContactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "pickPhone") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingContactResult != null) {
                    result.error("PICKER_BUSY", "A contact selection is already in progress.", null)
                    return@setMethodCallHandler
                }
                pendingContactResult = result
                val intent = Intent(Intent.ACTION_PICK).apply {
                    type = ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE
                }
                try {
                    startActivityForResult(intent, CONTACT_PICK_REQUEST)
                } catch (error: ActivityNotFoundException) {
                    pendingContactResult?.error(
                        "NO_CONTACT_PICKER",
                        error.message,
                        null
                    )
                    pendingContactResult = null
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CONTACT_PICK_REQUEST) return

        val result = pendingContactResult
        pendingContactResult = null
        val contactUri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (contactUri == null) {
            result?.success(null)
            return
        }

        try {
            contentResolver.query(
                contactUri,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                null,
                null,
                null
            )?.use { cursor ->
                result?.success(
                    if (cursor.moveToFirst()) cursor.getString(0) else null
                )
            } ?: result?.success(null)
        } catch (error: Exception) {
            result?.error("CONTACT_READ_FAILED", error.message, null)
        }
    }
}'''
        pattern = r"class\s+MainActivity\s*:\s*FlutterFragmentActivity\s*\(\s*\)\s*(?:\{\s*\})?"
        updated, count = re.subn(pattern, lambda _: activity, source, count=1)
    else:
        extra_imports = """import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.database.Cursor;
import android.provider.ContactsContract;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;"""
        package_match = re.search(r"(?m)^package\s+[\w.]+;\s*$", source)
        if package_match is None:
            raise RuntimeError("Could not find the MainActivity Java package declaration.")
        source = source[:package_match.end()] + "\n\n" + extra_imports + source[package_match.end():]
        activity = r'''public class MainActivity extends FlutterFragmentActivity {
    private static final int CONTACT_PICK_REQUEST = 7321;
    private static final String CONTACT_CHANNEL = "danestani_gaz/contact_picker";
    private MethodChannel.Result pendingContactResult;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            CONTACT_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if (!"pickPhone".equals(call.method)) {
                result.notImplemented();
                return;
            }
            if (pendingContactResult != null) {
                result.error("PICKER_BUSY", "A contact selection is already in progress.", null);
                return;
            }
            pendingContactResult = result;
            Intent intent = new Intent(Intent.ACTION_PICK);
            intent.setType(ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE);
            try {
                startActivityForResult(intent, CONTACT_PICK_REQUEST);
            } catch (ActivityNotFoundException error) {
                pendingContactResult.error("NO_CONTACT_PICKER", error.getMessage(), null);
                pendingContactResult = null;
            }
        });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != CONTACT_PICK_REQUEST) return;

        MethodChannel.Result result = pendingContactResult;
        pendingContactResult = null;
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            if (result != null) result.success(null);
            return;
        }

        Cursor cursor = null;
        try {
            cursor = getContentResolver().query(
                data.getData(),
                new String[]{ContactsContract.CommonDataKinds.Phone.NUMBER},
                null,
                null,
                null
            );
            if (cursor != null && cursor.moveToFirst()) {
                if (result != null) result.success(cursor.getString(0));
            } else if (result != null) {
                result.success(null);
            }
        } catch (Exception error) {
            if (result != null) result.error("CONTACT_READ_FAILED", error.getMessage(), null);
        } finally {
            if (cursor != null) cursor.close();
        }
    }
}'''
        pattern = r"public\s+class\s+MainActivity\s+extends\s+FlutterFragmentActivity\s*\{\s*\}"
        updated, count = re.subn(pattern, lambda _: activity, source, count=1)

    if count != 1:
        raise RuntimeError("Could not add the native phone contact picker to MainActivity.")
    activity_file.write_text(updated, encoding="utf-8")


def _configure_cropper_activity(android: Path) -> None:
    manifest = android / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.is_file():
        raise RuntimeError("AndroidManifest.xml was not generated.")
    source = manifest.read_text(encoding="utf-8")
    if "com.yalantis.ucrop.UCropActivity" in source:
        return
    activity = '''
        <activity
            android:name="com.yalantis.ucrop.UCropActivity"
            android:screenOrientation="portrait"
            android:theme="@style/Ucrop.CropTheme" />
'''
    updated, count = re.subn(
        r"(</application>)",
        lambda match: activity + "    " + match.group(1),
        source,
        count=1,
    )
    if count != 1:
        raise RuntimeError("Could not register image cropper activity.")
    manifest.write_text(updated, encoding="utf-8")

def _configure_cropper_styles(android: Path) -> None:
    """Provide the uCrop theme required by image_cropper 14 on all Android versions."""
    app_res = android / "app" / "src" / "main" / "res"
    values = app_res / "values"
    values.mkdir(parents=True, exist_ok=True)
    styles = values / "styles.xml"
    source = styles.read_text(encoding="utf-8") if styles.exists() else '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n</resources>\n'
    if "name=" + '"Ucrop.CropTheme"' not in source:
        updated, count = re.subn(
            r"</resources>",
            '    <style name="Ucrop.CropTheme" parent="Theme.AppCompat.Light.NoActionBar"/>\n</resources>',
            source,
            count=1,
        )
        if count != 1:
            raise RuntimeError("Could not add the uCrop theme to values/styles.xml.")
        styles.write_text(updated, encoding="utf-8")

    values_v35 = app_res / "values-v35"
    values_v35.mkdir(parents=True, exist_ok=True)
    edge_styles = values_v35 / "styles.xml"
    edge_source = edge_styles.read_text(encoding="utf-8") if edge_styles.exists() else '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n</resources>\n'
    if "name=" + '"Ucrop.CropTheme"' not in edge_source:
        updated, count = re.subn(
            r"</resources>",
            '    <style name="Ucrop.CropTheme" parent="Theme.AppCompat.Light.NoActionBar">\n'
            '        <item name="android:windowOptOutEdgeToEdgeEnforcement">true</item>\n'
            '    </style>\n</resources>',
            edge_source,
            count=1,
        )
        if count != 1:
            raise RuntimeError("Could not add the Android 15 uCrop theme override.")
        edge_styles.write_text(updated, encoding="utf-8")


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


def _configure_application_id(android: Path, application_id: str | None) -> None:
    if not application_id:
        return

    package_pattern = r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+"
    if not re.fullmatch(package_pattern, application_id):
        raise RuntimeError(
            "BAZAAR_APPLICATION_ID must be a valid Android application ID "
            "with at least two dot-separated segments."
        )

    kotlin_gradle = android / "app" / "build.gradle.kts"
    groovy_gradle = android / "app" / "build.gradle"
    gradle_file = kotlin_gradle if kotlin_gradle.is_file() else groovy_gradle
    if not gradle_file.is_file():
        raise RuntimeError("Android app Gradle file was not generated.")

    source = gradle_file.read_text(encoding="utf-8")
    if gradle_file.suffix == ".kts":
        assignment = f'applicationId = "{application_id}"'
        pattern = r'(?m)^(\s*)applicationId\s*=\s*"[^"]+"'
    else:
        assignment = f'applicationId "{application_id}"'
        pattern = r"(?m)^(\s*)applicationId\s+['\"][^'\"]+['\"]"

    existing, count = re.subn(
        pattern,
        lambda match: match.group(1) + assignment,
        source,
        count=1,
    )
    if count == 0:
        default_config = re.search(r'(?m)^(\s*)defaultConfig\s*\{', source)
        if default_config is None:
            raise RuntimeError("Could not find defaultConfig to set applicationId.")
        indent = default_config.group(1) + "    "
        existing = (
            source[:default_config.end()]
            + "\n"
            + indent
            + assignment
            + source[default_config.end():]
        )

    gradle_file.write_text(existing, encoding="utf-8")


def _configure_release_signing(
    android: Path,
    environment: dict[str, str],
) -> bool:
    required = (
        "CM_KEYSTORE_PATH",
        "CM_KEYSTORE_PASSWORD",
        "CM_KEY_ALIAS",
        "CM_KEY_PASSWORD",
    )
    values = {name: environment.get(name, "").strip() for name in required}
    if not any(values.values()):
        return False

    missing = [name for name, value in values.items() if not value]
    if missing:
        raise RuntimeError(
            "Android release signing is partially configured. Missing: "
            + ", ".join(missing)
        )

    kotlin_gradle = android / "app" / "build.gradle.kts"
    groovy_gradle = android / "app" / "build.gradle"
    gradle_file = kotlin_gradle if kotlin_gradle.is_file() else groovy_gradle
    if not gradle_file.is_file():
        raise RuntimeError("Android app Gradle file was not generated.")

    source = gradle_file.read_text(encoding="utf-8")
    if gradle_file.suffix == ".kts":
        signing_block = """
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("CM_KEYSTORE_PATH") ?: error("CM_KEYSTORE_PATH is required"))
            storePassword = System.getenv("CM_KEYSTORE_PASSWORD") ?: error("CM_KEYSTORE_PASSWORD is required")
            keyAlias = System.getenv("CM_KEY_ALIAS") ?: error("CM_KEY_ALIAS is required")
            keyPassword = System.getenv("CM_KEY_PASSWORD") ?: error("CM_KEY_PASSWORD is required")
        }
    }
"""
        signing_marker = 'create("release")'
        build_types_pattern = r"(?m)^([ \t]*)buildTypes[ \t]*\{"
        debug_assignment = 'signingConfig = signingConfigs.getByName("debug")'
        release_assignment = 'signingConfig = signingConfigs.getByName("release")'
        release_header_pattern = r"(?m)^([ \t]*)release[ \t]*\{"
    else:
        signing_block = """
    signingConfigs {
        release {
            storeFile file(System.getenv("CM_KEYSTORE_PATH"))
            storePassword System.getenv("CM_KEYSTORE_PASSWORD")
            keyAlias System.getenv("CM_KEY_ALIAS")
            keyPassword System.getenv("CM_KEY_PASSWORD")
        }
    }
"""
        signing_marker = "signingConfigs {"
        build_types_pattern = r"(?m)^([ \t]*)buildTypes[ \t]*\{"
        debug_assignment = "signingConfig signingConfigs.debug"
        release_assignment = "signingConfig signingConfigs.release"
        release_header_pattern = r"(?m)^([ \t]*)release[ \t]*\{"

    if signing_marker not in source:
        match = re.search(build_types_pattern, source)
        if match is None:
            raise RuntimeError("Could not find buildTypes to configure release signing.")
        source = source[:match.start()] + signing_block + source[match.start():]

    build_types = re.search(build_types_pattern, source)
    if build_types is None:
        raise RuntimeError("Could not find buildTypes to configure release signing.")
    release_header = re.search(release_header_pattern, source[build_types.end():])
    if release_header is None:
        raise RuntimeError("Could not find the release build type for signing.")
    absolute_end = build_types.end() + release_header.end()
    release_body = source[absolute_end:]

    if debug_assignment in release_body:
        release_body = release_body.replace(debug_assignment, release_assignment, 1)
    elif release_assignment not in release_body.split("}", 1)[0]:
        line_break = "\n"
        indent = " " * (len(release_header.group(1)) + 4)
        release_body = line_break + indent + release_assignment + release_body

    source = source[:absolute_end] + release_body
    gradle_file.write_text(source, encoding="utf-8")
    return True


def configure_android(
    android_directory: Path,
    application_id: str | None = None,
    signing_environment: dict[str, str] | None = None,
) -> None:
    if not android_directory.is_dir():
        raise RuntimeError(f"Android directory does not exist: {android_directory}")
    _configure_jitpack(android_directory)
    _configure_activity(android_directory)
    _configure_contact_picker(android_directory)
    _configure_min_sdk(android_directory)
    _configure_speech_queries(android_directory)
    _configure_cropper_activity(android_directory)
    _configure_cropper_styles(android_directory)
    _configure_application_id(android_directory, application_id)
    _configure_release_signing(android_directory, signing_environment or {})


def main() -> int:
    android_directory = Path(__file__).resolve().parents[1] / "android"
    application_id = os.environ.get("BAZAAR_APPLICATION_ID", "").strip() or None
    try:
        signing_environment = dict(os.environ)
        signing_names = (
            "CM_KEYSTORE_PATH",
            "CM_KEYSTORE_PASSWORD",
            "CM_KEY_ALIAS",
            "CM_KEY_PASSWORD",
        )
        signing_configured = all(
            signing_environment.get(name, "").strip() for name in signing_names
        )
        configure_android(
            android_directory,
            application_id=application_id,
            signing_environment=signing_environment,
        )
    except (OSError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(
        "OK: Cafe Bazaar Android host configured "
        "(JitPack, FragmentActivity, minSdk 24"
        + (", registered application ID" if application_id else "")
        + (", release signing configured" if signing_configured else "")
        + ")."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
