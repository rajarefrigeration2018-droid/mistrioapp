#!/usr/bin/env python3
"""
Validates google-services.json before Gradle gets near it.

A malformed or mismatched file otherwise surfaces as an opaque Gradle failure
several minutes into the build, so it is worth catching here with a message
that says what to actually do about it.
"""

import json
import pathlib
import sys

EXPECTED_PACKAGE = "com.mistrio.user"
PATH = pathlib.Path("android/app/google-services.json")

if not PATH.exists() or PATH.stat().st_size == 0:
    sys.exit(
        "google-services.json is missing or empty.\n"
        "The GOOGLE_SERVICES_JSON secret is probably not set.\n"
        "Add it under Settings > Secrets and variables > Actions, pasting the\n"
        "raw contents of the file downloaded from Firebase."
    )

try:
    data = json.loads(PATH.read_text())
except json.JSONDecodeError as error:
    sys.exit(
        f"google-services.json is not valid JSON: {error}\n"
        "Re-copy the whole file from Firebase into the GOOGLE_SERVICES_JSON secret."
    )

packages = [
    client.get("client_info", {}).get("android_client_info", {}).get("package_name")
    for client in data.get("client", [])
]
packages = [p for p in packages if p]

print("Package names found:", ", ".join(packages) or "(none)")

if EXPECTED_PACKAGE not in packages:
    sys.exit(
        f"\nThis file has no entry for '{EXPECTED_PACKAGE}'.\n\n"
        "Fix it in Firebase Console:\n"
        "  Project Settings > Your apps > Add app > Android\n"
        f"  Android package name: {EXPECTED_PACKAGE}\n"
        "  Download the new google-services.json\n"
        "  Update the GOOGLE_SERVICES_JSON secret with its contents\n"
    )

project_id = data.get("project_info", {}).get("project_id", "unknown")
print(f"Valid. Firebase project '{project_id}' has a client for {EXPECTED_PACKAGE}.")
