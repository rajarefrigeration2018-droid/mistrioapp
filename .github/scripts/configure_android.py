#!/usr/bin/env python3
"""
Applies the Mistrio-specific Android configuration to the project that
`flutter create` just generated.

Run from the repo root by the build workflow. Safe to run repeatedly.
"""

import pathlib
import re
import sys

APP_ID = "com.mistrio.user"
APP_LABEL = "Mistrio"
COMPILE_SDK = 35
TARGET_SDK = 35
MIN_SDK = 23  # firebase_auth requires 23 or higher

ANDROID = pathlib.Path("android")


def find(directory: pathlib.Path, stem: str) -> pathlib.Path:
    """Gradle files may be Groovy or Kotlin DSL depending on the Flutter version."""
    for suffix in ("", ".kts"):
        candidate = directory / f"{stem}{suffix}"
        if candidate.exists():
            return candidate
    sys.exit(f"Could not find {directory}/{stem}")


# ----------------------------------------------------------------- settings
def patch_settings() -> None:
    path = find(ANDROID, "settings.gradle")
    text = path.read_text()

    if "com.google.gms.google-services" in text:
        return

    patched = re.sub(
        r'(id\s+["\']com\.android\.application["\'][^\n]*\n)',
        r'\1    id "com.google.gms.google-services" version "4.4.2" apply false\n',
        text,
        count=1,
    )

    if patched == text:
        print("  ! could not register the Google Services plugin in settings.gradle")
        return

    path.write_text(patched)
    print(f"  patched {path}")


# ----------------------------------------------------------------- root
SUBPROJECT_FIX = """
// MISTRIO_SUBPROJECT_FIX
// Several plugins ship without declaring a compileSdk and inherit nothing,
// which fails configuration with "compileSdkVersion is not specified".
// Forcing one SDK level across every subproject is the standard remedy.
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            project.android {
                compileSdkVersion COMPILE_SDK_PLACEHOLDER
                if (namespace == null) {
                    namespace project.group
                }
            }
        }
    }
}
"""


def patch_root() -> None:
    path = find(ANDROID, "build.gradle")
    text = path.read_text()

    if "MISTRIO_SUBPROJECT_FIX" in text:
        return

    block = SUBPROJECT_FIX.replace("COMPILE_SDK_PLACEHOLDER", str(COMPILE_SDK))
    path.write_text(text.rstrip() + "\n" + block)
    print(f"  patched {path}")


# ----------------------------------------------------------------- app
def patch_app() -> None:
    path = find(ANDROID / "app", "build.gradle")
    text = path.read_text()

    # apply the Google Services plugin
    if "com.google.gms.google-services" not in text:
        if re.search(r'id\s+["\']dev\.flutter\.flutter-gradle-plugin["\']', text):
            text = re.sub(
                r'(id\s+["\']dev\.flutter\.flutter-gradle-plugin["\'][^\n]*\n)',
                r'\1    id "com.google.gms.google-services"\n',
                text,
                count=1,
            )
        else:
            text += '\napply plugin: "com.google.gms.google-services"\n'

    text = re.sub(r'namespace\s*=?\s*["\'][^"\']+["\']', f'namespace = "{APP_ID}"', text)
    text = re.sub(
        r'applicationId\s*=?\s*["\'][^"\']+["\']', f'applicationId = "{APP_ID}"', text
    )

    # These arrive as `compileSdk = flutter.compileSdkVersion` and similar.
    text = re.sub(r'compileSdk\w*\s*=?\s*[^\n]+', f"compileSdk = {COMPILE_SDK}", text)
    text = re.sub(r'minSdk\w*\s*=?\s*[^\n]+', f"minSdk = {MIN_SDK}", text)
    text = re.sub(r'targetSdk\w*\s*=?\s*[^\n]+', f"targetSdk = {TARGET_SDK}", text)

    if "multiDexEnabled" not in text:
        text = re.sub(
            r'(applicationId\s*=\s*["\'][^"\']+["\']\n)',
            r"\1        multiDexEnabled = true\n",
            text,
            count=1,
        )

    # Sign release with the debug keystore so a single SHA-1 covers every build
    # during testing. Swap for a real upload key before production.
    # Check for the block declaration, not the `signingConfigs.debug`
    # reference that Flutter already generates.
    if not re.search(r"signingConfigs\s*\{", text):
        signing = (
            "\n    signingConfigs {\n"
            "        debug {\n"
            '            storeFile file("debug.keystore")\n'
            '            storePassword "android"\n'
            '            keyAlias "androiddebugkey"\n'
            '            keyPassword "android"\n'
            "        }\n"
            "    }\n"
        )
        text = re.sub(r"(\n\s*buildTypes\s*\{)", signing + r"\1", text, count=1)

    text = re.sub(
        r"signingConfig\s*=?\s*signingConfigs\.debug",
        "signingConfig signingConfigs.debug",
        text,
    )

    path.write_text(text)
    print(f"  patched {path}")


# ----------------------------------------------------------------- manifest
PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.CAMERA",
]


def patch_manifest() -> None:
    path = ANDROID / "app/src/main/AndroidManifest.xml"
    text = path.read_text()

    missing = [p for p in PERMISSIONS if p not in text]
    if missing:
        block = "\n".join(f'    <uses-permission android:name="{p}"/>' for p in missing)
        text = re.sub(r"(<manifest[^>]*>\n)", r"\1" + block + "\n", text, count=1)

    text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', text, count=1)

    # The real key is substituted from a secret by the next workflow step.
    if "com.google.android.geo.API_KEY" not in text:
        meta = (
            "\n        <meta-data\n"
            '            android:name="com.google.android.geo.API_KEY"\n'
            '            android:value="MAPS_KEY_PLACEHOLDER"/>'
        )
        text = re.sub(r"(\n\s*</application>)", meta + r"\1", text, count=1)

    path.write_text(text)
    print(f"  patched {path}")


# ----------------------------------------------------------------- properties
def patch_properties() -> None:
    path = ANDROID / "gradle.properties"
    text = path.read_text() if path.exists() else ""

    wanted = [
        "android.useAndroidX=true",
        "android.enableJetifier=true",
        "org.gradle.jvmargs=-Xmx4G",
    ]
    for line in wanted:
        key = line.split("=", 1)[0]
        if key not in text:
            if text and not text.endswith("\n"):
                text += "\n"
            text += line + "\n"

    path.write_text(text)
    print(f"  patched {path}")


if __name__ == "__main__":
    print("Configuring Android project for", APP_ID)
    patch_settings()
    patch_root()
    patch_app()
    patch_manifest()
    patch_properties()
    print("Done.")
