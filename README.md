# YetNew

YetNew is a Flutter + Firebase household inventory app. Track devices, organize them into storage boxes/compartments, and use the built‑in AI assistant to quickly find items or review what needs repair.

## Features

- Devices: add/edit items with photo, category, location, notes, status, and optional storage compartment number
- Storage: create storage boxes with a location, notes, and configurable number of compartments
- History: activity timeline for household changes
- Auth: Firebase email/password, Google Sign‑In, and Apple Sign‑In (platform support depends on configuration)
- AI Assistant: Gemini-powered chat (configured via `--dart-define`)
- Deep links: password reset links open the app (Android manifest intent filters)

## Tech Stack

- Flutter (Dart)
- Firebase: Auth + Firestore (+ Storage dependency present)
- Packages: `google_generative_ai`, `google_sign_in`, `sign_in_with_apple`, `app_links`, `flutter_svg`, `image_picker`

## Getting Started

### Prerequisites

- Flutter SDK installed
- A configured Firebase project
  - Android config file: `android/app/google-services.json`
  - iOS config file: `ios/Runner/GoogleService-Info.plist` (if building for iOS)

Note: For GitHub safety, Firebase config files and `lib/firebase_options.dart` may be excluded by `.gitignore`. If you clone this repo, you must add those files locally (or regenerate them with FlutterFire) before the app will build.

### Install dependencies

```powershell
flutter pub get
```

### Run (Android)

```powershell
flutter run -d <DEVICE_ID>
```

### Run with AI Chat (Gemini)

AI chat uses compile-time defines:

- `GEMINI_API_KEY` (required)
- `GEMINI_MODEL` (optional; defaults to `gemini-1.5-flash-latest`)

```powershell
flutter run -d <DEVICE_ID> `
	--dart-define=GEMINI_API_KEY=YOUR_KEY `
	--dart-define=GEMINI_MODEL=gemini-2.5-flash
```

Never commit your Gemini key to Git.

## App Icon / Display Name

- Launcher icon source: `assets/images/yetnew_app_icon.png`
- Generated via `flutter_launcher_icons` (see `pubspec.yaml`)

Regenerate icons:

```powershell
flutter pub get
dart run flutter_launcher_icons
```

Important: do NOT rename the project folder (e.g. keep `yetnew_app`) if your Firebase setup depends on it.

## Tests

```powershell
flutter test
```

## Build / Release

### Android APK (local install)

```powershell
flutter build apk --release
```

### Android App Bundle (Play Store)

```powershell
flutter build appbundle --release
```

## Troubleshooting

### Gemini key missing

- Run with `--dart-define=GEMINI_API_KEY=...` (the app reads this at compile time).

### Google Sign‑In fails (common on Android)

- Verify SHA-1/SHA-256 fingerprints are added in Firebase console for the Android app.
- Download the updated `google-services.json` and replace `android/app/google-services.json`.
- Ensure Google Play services are available/updated on the device.

### Password reset deep link not opening the app

- Confirm your Firebase Auth action URL domain matches the hosts in `android/app/src/main/AndroidManifest.xml`.

## Repo Notes

- Main entry: `lib/main.dart`
- Firebase options: `lib/firebase_options.dart`
- Screens: `lib/screens/**`
