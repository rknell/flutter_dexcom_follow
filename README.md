# Teddycom

Unofficial Flutter client for **Dexcom Share** glucose data, built for a small private Android install base. It shows recent glucose data, charts, simple 20-minute prediction, configurable alarms, and Android foreground monitoring.

This project is **not** affiliated with, endorsed by, or supported by Dexcom. Use at your own risk; it is **not** a medical device and must not replace clinical judgment, prescribed therapy, or the official Dexcom app. It can miss alarms. Treat it as an experiment.

## Current app behavior

- Signs in to Dexcom Share using the EU/International server.
- Displays the latest glucose reading in mmol/L with trend direction and local reading time.
- Loads up to 24 hours of glucose history for the chart.
- Shows a 20-minute prediction when enough recent readings are available.
- Draws alarm threshold lines on the glucose chart.
- Stores alarm settings locally on the device.
- Can remember the Dexcom login locally if enabled. This is convenient for background monitoring, but it is not secure storage.
- Runs Android background monitoring as a foreground service when saved login is enabled.
- Polls in the background about every 5 minutes.
- Shows monitoring and alarm notifications on Android.

## Alarm behavior

- Standard low/high alarms are configurable. Defaults are 3.9 mmol/L low and 14.0 mmol/L high.
- Standard alarms repeat no more than once per minute while glucose remains out of range.
- Stale-data alarms are enabled by default and trigger when no new reading arrives for more than 15 minutes.
- Critical low alarms at or below 3.1 mmol/L always run, even if standard alarms are disabled.
- Predicted critical lows below 3.1 mmol/L also alarm, using a distinct short-beep pattern.
- Background alarms require Android notification permission and can be affected by OEM battery restrictions.

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) (stable channel), Dart SDK as declared in `pubspec.yaml`
- Android SDK for APK builds
- Xcode tooling only if you experiment with iOS/macOS builds

## Getting started

```bash
flutter pub get
flutter run
```

The app is primarily maintained for Android. Other Flutter platform folders exist from the project template, but the background monitoring and APK release workflow are Android-focused.

### Dependency layout

The Dart client for the Share API lives in-repo at [`packages/dexcom_share_api`](packages/dexcom_share_api). The app depends on it via a `path` entry in `pubspec.yaml`, so a fresh `git clone` is enough—no sibling repositories required.

## Tests and analysis

```bash
flutter analyze
flutter test
```

Package tests (optional integration tests need `DEXCOM_USERNAME` / `DEXCOM_PASSWORD` in the environment or a `packages/dexcom_share_api/.env` file—never commit real credentials):

```bash
cd packages/dexcom_share_api && dart pub get && dart test
```

## Android releases

Android APK releases are published by the `Android APK Release` GitHub Actions workflow. Run it manually from GitHub Actions; it fetches existing release tags, increments the patch version and Android build number, builds a signed APK, pushes the new tag, and attaches the APK to a GitHub release.

Release tags use the same version string Android reports to update managers, for example `v1.2.3`. The Android `versionCode` still increments on every release so APK upgrades install cleanly.

Pushes to `main` also publish an Android release unless every changed file is under `.github/workflows/**`. Workflow-only pushes are ignored because GitHub's default Actions token cannot reliably create release tags that point at workflow-changing commits.

The published Android package ID is:

```text
com.rknell.teddycom
```

Keep this package ID and signing key stable. Changing either one means Android will treat a future APK as a different app or refuse to upgrade it.

The workflow requires these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Local release signing uses ignored files at `android/release-keystore.jks` and `android/key.properties`.

### Obtainium updates

Teddycom is distributed as a GitHub release APK for [Obtainium](https://obtainium.imranr.dev/).

On each Android device:

1. Install Obtainium.
2. Add `https://github.com/rknell/flutter_dexcom_follow`.
3. Use the GitHub source if Obtainium asks.
4. Set the APK filter regex to `^teddycom-.*\.apk$`.
5. Install Teddycom from Obtainium once.

After that, new GitHub releases should be detected by Obtainium and installed from the release APK. Android will still ask for install confirmation unless the device has a privileged/managed installer setup.

If a device previously had a build installed with the old package ID `com.example.flutter_dexcom_follow`, uninstall that build and install the new Obtainium-managed `com.rknell.teddycom` build once.

## Security and privacy

- Dexcom username and password are stored on-device only when the user enables remembered login (see `lib/app/credentials.dart`).
- Saved login is needed for background monitoring to auto-start after sign-in or reboot.
- Use "Log out and clear saved login" or "Clear saved login" to remove saved credentials from the device.
- Do not commit `android/local.properties`, keystores, `key.properties`, or environment files containing real credentials. See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
