# Mistrio — Customer App

Flutter Android app for booking appliance repair and buying spare parts.

## Create the Flutter project first

This repo holds `lib/`, `pubspec.yaml` and the CI workflow. The Android
scaffolding is generated once by Flutter itself. In Codespaces:

```bash
# in an empty folder, generate the shell
flutter create --org com.mistrio --project-name mistrio .

# then copy this repo's lib/, pubspec.yaml, analysis_options.yaml
# and .github/ over the generated files
flutter pub get
```

`flutter create` writes `android/`, `ios/` and a starter `lib/main.dart`.
Overwrite that `main.dart` with the one here.

## Android configuration

**`android/app/build.gradle`** — three changes:

```gradle
android {
    namespace "com.mistrio.user"
    compileSdk 34

    defaultConfig {
        applicationId "com.mistrio.user"
        minSdk 23          // firebase_auth needs 23+
        targetSdk 34
        multiDexEnabled true
    }

    signingConfigs {
        debug {
            storeFile file('debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
    }

    buildTypes {
        release {
            // Signed with the debug key so the SHA-1 in Firebase stays valid
            // during testing. Swap for a real upload key before production.
            signingConfig signingConfigs.debug
            minifyEnabled false
        }
    }
}
```

At the very bottom of the same file:

```gradle
apply plugin: 'com.google.gms.google-services'
```

**`android/build.gradle`** — inside `buildscript.dependencies`:

```gradle
classpath 'com.google.gms:google-services:4.4.2'
```

**`android/app/src/main/AndroidManifest.xml`** — inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Inside `<application>`, set the label and add the Maps key:

```xml
android:label="Mistrio"

<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_MAPS_API_KEY"/>
```

## Firebase

1. Firebase Console → your project → Add app → Android
2. Package name: `com.mistrio.user`
3. Add the **SHA-1** from the keystore (the CI workflow prints it in the build log)
4. Download `google-services.json` → `android/app/google-services.json`
5. Authentication → Sign-in method → **Phone** → Enable
6. Add test numbers under Phone → "Phone numbers for testing" so you can sign
   in without burning SMS quota

Full detail is in the backend repo's `FIREBASE_SETUP.md`.

## GitHub Secrets for CI

The workflow builds a signed APK on every push to `main`. Add two secrets:

| Secret | How to produce it |
|---|---|
| `GOOGLE_SERVICES_JSON` | `base64 -w0 google-services.json` |
| `DEBUG_KEYSTORE` | `base64 -w0 ~/.android/debug.keystore` |

Using the same keystore on every build keeps the SHA-1 stable, which is what
makes Phone Auth work on the APKs you download from Actions.

## The one line you change at launch

`lib/core/constants/app_constants.dart`:

```dart
static const String apiBaseUrl = 'https://.../api';
```

No other file in this app contains a hostname. When the domain arrives, edit
that line, bump the version, rebuild.

## Architecture

```
lib/
  core/
    constants/app_constants.dart   API URL, storage keys, routes
    api/api_client.dart            HTTP, token, envelope, one exception type
    theme/app_theme.dart           Material 3 theme, colours from server
    utils/formatters.dart          money, dates, status labels
  data/
    models/models.dart             plain data classes, defensive fromJson
    providers/
      config_provider.dart         server-driven settings, force update, location
      auth_provider.dart           Firebase phone OTP → backend JWT
  presentation/
    screens/                       one folder per feature
    widgets/                       shared pieces
```

**Nothing user-facing is hardcoded.** Colours, support numbers, tax, payment
methods, cancellation rules and legal links all come from `/app-config` and are
editable from the admin console without an app update.

## How auth actually works

Firebase runs the OTP on the device and hands back an ID token. That token goes
to `POST /auth/user/firebase`, the backend verifies it with the Firebase Admin
SDK, and issues its own JWT. Every request after that carries our JWT, not the
Firebase one.

On Android the SMS is often read automatically — `verificationCompleted` fires
and the user is signed in without typing anything. The OTP field is the fallback.

## What is built

- Splash: config load, force-update gate, maintenance gate, session restore
- Login: phone entry, OTP, auto-detect, resend timer, referral code
- Placeholder home showing the signed-in user

## What is next

Home with categories and services, service detail, cart, checkout with address
and slot picking, live booking tracking, wallet, spare parts shop, profile.
