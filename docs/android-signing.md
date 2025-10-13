# Android Release Signing Guide

This guide shows how to generate and use a signing key so you can build signed APKs/AABs for releases—now and in the future.

## 1) Generate a keystore (one-time)

Use keytool from JDK 17 or Android Studio (Keystore path will be inside the `android/` folder for simplicity):

```
# Run from the project root, adjust your names as needed.
# It will prompt for a password (remember it!), name, org, etc.
# Alias must match the one used in key.properties (e.g., my_release_key)

keytool -genkeypair -v -keystore android/release-keystore.jks -keyalg RSA -keysize 2048 -validity 36500 -alias my_release_key
```

Notes:
- Keep the keystore file safe. Consider copying it to a secure backup (encrypted drive or password manager file storage).
- Validity 36500 ~ 100 years—adjust as you like.

## 2) Create `android/key.properties` (secrets)

Create a file at `android/key.properties` with this content (do not commit it):

```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=my_release_key
storeFile=../release-keystore.jks
```

Tips:
- Replace `YOUR_PASSWORD` with the password you set during keystore creation.
- On Windows, save with UTF-8 (no BOM) to avoid parsing issues. The project is tolerant to BOM now, but UTF-8 without BOM is recommended.
- This file is already ignored by Git via `android/.gitignore`.

## 3) Gradle configuration (already set up)

The module Gradle file `android/app/build.gradle.kts` is configured to:
- Load `android/key.properties` in UTF-8 (handles BOM if present).
- Create `signingConfigs.release` using your keystore and passwords.
- Apply it to `buildTypes.release`.

No changes are needed unless you rename paths or alias.

## 4) Build signed artifacts

From project root:

- APK (recommended for sideload/testing):

```
powershell
flutter build apk --release
```

- AAB (required for Play Store):

```
powershell
flutter build appbundle --release
```

Artifacts will be created at:
- APK: `build/app/outputs/apk/release/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## 5) Verify signing (optional)

Use apksigner from Android SDK Build-Tools (change version/path accordingly):

```
powershell
& "$Env:ANDROID_HOME\build-tools\<version>\apksigner.bat" verify --print-certs build/app/outputs/apk/release/app-release.apk
```

You should see certificate details; verification should pass without errors.

## 6) Backups and rotation

- Back up `android/release-keystore.jks` and `android/key.properties` (or the passwords separately) in a secure location.
- If you lose the keystore, you cannot update the same app on Play Store. Consider keeping an off-site backup.
- To rotate keys: generate a new keystore, update `key.properties`, and update Play Console (App signing key/ upload key) per Google’s documentation.

## 7) Troubleshooting

- Error: `SigningConfig "release" is missing required property "storePassword"`:
  - Ensure `android/key.properties` exists and uses correct keys: `storePassword`, `keyPassword`, `keyAlias`, `storeFile`.
  - Save file in UTF-8; avoid BOM. This project also has a BOM-safe loader.
  - Confirm `storeFile` path resolves correctly from `android/app` (default `../release-keystore.jks`).

- Windows: Lint file lock error (e.g., `FileSystemException` on `lint-cache`):
  - This project disables lint on release to avoid intermittent Windows file lock issues.
  - If re-enabled, you may need to stop Gradle daemons and remove the lint cache:
    - `gradlew --stop`
    - Delete `build/app/intermediates/lint-cache` (PowerShell: `Remove-Item -Recurse -Force`).

- Wrong alias or password:
  - Re-run keytool with the correct alias, or update `keyAlias`/passwords in `key.properties`.

## 8) CI/CD hints

- Store `key.properties` values as CI secrets; write them to the workspace at build time.
- Upload keystore as an encrypted CI secret or use secure artifact storage.
- Run:
  - `flutter pub get`
  - `flutter build appbundle --release` (or `apk`) on CI.

---

Keep this document updated if you change keystore names, aliases, or paths.
