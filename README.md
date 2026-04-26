# flutter_dexcom_follow

Unofficial Flutter client for **Dexcom Share** glucose data: charts, configurable alarms, and Android foreground monitoring. This project is **not** affiliated with, endorsed by, or supported by Dexcom. Use at your own risk; it is **not** a medical device and must not replace clinical judgment or prescribed therapy. In fact it will miss alarms and probably cause harm if used. Its an experiment.

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) (stable channel), Dart SDK as declared in `pubspec.yaml`
- Android SDK / Xcode tooling for the platforms you build

## Getting started

```bash
flutter pub get
flutter run
```

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

After that, new GitHub releases should be detected by Obtainium and installed from the release APK. The Android package ID is `com.rknell.teddycom`; keep that ID and signing key stable or Android will treat a future build as a different app.

## Security and privacy

- Dexcom username and password are stored on-device only when the user enables remembered login (see `lib/app/credentials.dart`).
- Do not commit `android/local.properties`, keystores, `key.properties`, or environment files containing real credentials. See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
