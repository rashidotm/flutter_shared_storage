# cloud_storage example

Demo app exercising upload, folder navigation, and the gallery viewer.

## Setup

1. `flutterfire configure` from this directory to generate `firebase_options.dart`.
2. Pass it to `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` in `lib/main.dart` (the current code calls the bare overload — adjust as needed).
3. Enable **anonymous sign-in** in Firebase Auth (or remove the `signInAnonymously()` line and sign in your own way).
4. Deploy the security rules and Cloud Functions from the monorepo root.

## Run

```bash
flutter pub get
flutter run
```
