#!/usr/bin/env python3
"""
Confirms every Dart file the app needs is actually in the repo, before the
build spends four minutes discovering it the hard way.

Uploading nested folders through a phone browser drops files silently, so this
prints exactly what is missing and where it belongs.
"""

import pathlib
import sys

EXPECTED = [
    "lib/main.dart",
    "lib/core/api/api_client.dart",
    "lib/core/constants/app_constants.dart",
    "lib/core/services/payment_service.dart",
    "lib/core/theme/app_theme.dart",
    "lib/core/utils/formatters.dart",
    "lib/data/models/models.dart",
    "lib/data/providers/auth_provider.dart",
    "lib/data/providers/cart_provider.dart",
    "lib/data/providers/config_provider.dart",
    "lib/data/repositories/booking_repository.dart",
    "lib/data/repositories/catalog_repository.dart",
    "lib/presentation/screens/address/address_sheet.dart",
    "lib/presentation/screens/auth/login_screen.dart",
    "lib/presentation/screens/bookings/booking_detail_screen.dart",
    "lib/presentation/screens/bookings/bookings_tab.dart",
    "lib/presentation/screens/cart/cart_bar.dart",
    "lib/presentation/screens/cart/cart_screen.dart",
    "lib/presentation/screens/checkout/booking_placed_screen.dart",
    "lib/presentation/screens/checkout/checkout_screen.dart",
    "lib/presentation/screens/home/category_screen.dart",
    "lib/presentation/screens/home/home_shell.dart",
    "lib/presentation/screens/home/home_tab.dart",
    "lib/presentation/screens/location/location_sheet.dart",
    "lib/presentation/screens/service/service_detail_screen.dart",
    "lib/presentation/screens/splash/splash_screen.dart",
    "lib/presentation/widgets/common.dart",
    "lib/presentation/widgets/service_card.dart",
]

print("Files currently in lib/")
print("-" * 60)
found = sorted(str(p) for p in pathlib.Path("lib").rglob("*.dart")) if pathlib.Path("lib").exists() else []
for path in found:
    print("  " + path)
if not found:
    print("  (lib/ is empty or missing entirely)")

print()
print(f"Found {len(found)} Dart files, expected {len(EXPECTED)}")

missing = [f for f in EXPECTED if not pathlib.Path(f).exists()]
extra = [f for f in found if f not in EXPECTED]

if extra:
    print()
    print("Unexpected files (harmless, just noting them):")
    for path in extra:
        print("  " + path)

if missing:
    print()
    print("=" * 60)
    print(f"MISSING {len(missing)} FILE(S)")
    print("=" * 60)
    for path in missing:
        print("  " + path)
    print()
    print("Add each one on github.com:")
    print("  Add file > Create new file")
    print("  Type the full path shown above, slashes included — that creates")
    print("  the folders automatically")
    print("  Paste the contents from the zip, then Commit changes")
    sys.exit(1)

print()
print("All expected files are present.")
