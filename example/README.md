# cloud_storage example

Demo app exercising upload, folder navigation, and the gallery viewer.

It also serves as the reference host app for `cloud_storage_gallery` 1.0.0. It is built on `package:material_ui` and uses Flutter 3.50's Android template (Gradle 9.5, AGP 9.3.1, Kotlin 2.4.20) with an iOS 16.0 deployment target. See [`MIGRATION.md`](../packages/cloud_storage_gallery/MIGRATION.md).

## Requirements

- Flutter **3.47+** (tested on 3.50)
- Android: Gradle 9.3.1+ (Flutter 3.50 enforces this), minSdk 24
- iOS: 16.0+

## Setup

1. `flutterfire configure` from this directory to generate `firebase_options.dart`.
2. `lib/main.dart` already passes it to `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`. The file is gitignored, so the app won't compile until you've generated it.
3. Enable **anonymous sign-in** in Firebase Auth (or remove the `signInAnonymously()` line and sign in your own way).
4. Deploy the Firestore rules + indexes and the Storage rules from the monorepo root (`firebase deploy --only firestore,storage`).

## Run

```bash
flutter pub get
flutter run
```
