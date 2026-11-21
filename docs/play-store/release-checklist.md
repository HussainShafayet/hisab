# Release checklist for Google Play

## What is set up in the project (done)
- **Package** `com.hishab.app`, **minSdk 24**, **target and compile SDK 36**
  (Google Play needs a recent target; this is Flutter's default).
- **Version** from `pubspec.yaml` (`1.10.1+21`): the part after `+` is the
  versionCode. Every upload needs a higher number than the last one.
- **Upload key**: `~/hishab-release-key/upload-keystore.jks` (alias `upload`,
  RSA 2048, valid until 2056). Its passwords are in `android/key.properties`
  (not in git: `android/.gitignore` has `key.properties`, `*.jks`).
  SHA-1 `BB:7D:AE:CE:2D:BC:87:3F:4F:17:7C:58:F7:57:ED:0D:63:63:69:A7`,
  SHA-256 `DC:A1:58:03:0C:E5:8F:98:FB:63:BE:38:76:23:17:7E:40:46:F9:19:8D:06:03:7B:2D:34:A4:B9:C0:05:C4:88`.
  **Copy the `hishab-release-key` folder and `android/key.properties` somewhere
  safe** (a USB stick, a password manager). Anyone with them can upload as you;
  without them you cannot upload updates, though Play can reset an upload key
  (Console, App integrity, Request upload key reset).
- **Signing in `android/app/build.gradle.kts`**: a *bundle* build
  (`flutter build appbundle`) is signed with the upload key. An *APK* build keeps
  the debug key, so an APK for your phone still installs over the one already
  there.
- **Checked** on the 1.10.1 build: all native libraries are 16 KB page aligned
  (needed for Android 15+), R8 rules for notifications come with the plugin, no
  sensitive permissions (internet, notifications, boot completed, vibrate).
- **Texts, graphics, policy, declarations**: the other files in this folder.

## Build the bundle
```
export PATH="$HOME/development/flutter/bin:$PATH" \
       ANDROID_HOME="$HOME/development/android-sdk" \
       JAVA_HOME="$HOME/development/jdk-21"
flutter build appbundle --release --split-debug-info=build/symbols/<version>
```
Output: `build/app/outputs/bundle/release/app-release.aab`. Keep the
`build/symbols/<version>` folder: it turns a crash stack trace back into names
(`flutter symbolize`). Do not use `--obfuscate` (enum names are stored in the
database).

## In Play Console (only you can do these)
1. Pay the one time registration fee and verify your identity. A personal account
   made after November 2023 must run a **closed test with at least 12 testers for
   14 days** before it can apply for production access.
2. **Create app**: name, default language, App, Free, accept the declarations.
3. **Set up your app** (Dashboard): privacy policy URL (put `privacy-policy.md`
   online first, with your contact email filled in: for example GitHub Pages or a
   public page), app access, ads, content rating, target audience, data safety
   and financial features: answers in `data-safety.md`.
4. **Store listing**: `store-listing.md` and `assets/`; add 2 to 8 phone
   screenshots from your phone.
5. **Release**: Testing, Closed testing (or Internal testing first), Create new
   release. Choose **Play App Signing** (the default): upload `app-release.aab`.
   Add release notes. Send to testers (add their Google emails to a list).
6. After the test period: Production, Create release, the same bundle or a newer
   one, countries (Bangladesh and others), and send for review.

## After the app exists in Play
- **App signing key**: Console, Test and release, App signing. Play re-signs the
  app with its own key, so an install from Play has a different signature from
  your sideloaded APK: **you cannot update one over the other**. Take
  Backup & export in Hishab, uninstall the APK, install from Play, restore.
- **Google sign-in for Drive**: the Android OAuth client in Google Cloud needs
  the SHA-1 of that **App signing key** (shown in the same page), or sign-in to
  Drive fails for people who installed from Play. The upload key's SHA-1 above is
  for the bundle only. (Noted as a reminder: nothing in the app needs to change.)
- Later updates: raise the version (`+N`), build the bundle, upload to a new
  release.

## Before each release
`flutter analyze`, `flutter test -j 2`, then the bundle.
