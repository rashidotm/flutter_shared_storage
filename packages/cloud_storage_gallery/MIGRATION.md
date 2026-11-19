# Migrating to cloud_storage_gallery 1.0.0

1.0.0 changes no Dart API in this package. Every widget, helper and parameter from 0.6.x works the same way. It is still a breaking release, because it changes what **your app** has to be built with:

1. The widgets are built on [`material_ui`](https://pub.dev/packages/material_ui), the standalone Material library that replaces the deprecated `package:flutter/material.dart`. Your `MaterialApp` has to come from `material_ui` too.
2. Video thumbnails come from [`fc_native_video_thumbnail`](https://pub.dev/packages/fc_native_video_thumbnail) instead of the unmaintained `video_thumbnail`. Its Android build used `jcenter()`, which Gradle 9 removed. The new plugin raises the iOS minimum to 16.
3. `file_picker` and `share_plus` moved to their 13.x lines, which build cleanly on AGP 9.

Work through the steps below in order.

## 1. Toolchain

- **Flutter 3.47 or newer** (Dart 3.13), since `material_ui` requires it. Flutter 3.50+ is what the package is tested with.

## 2. pubspec.yaml

```yaml
environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  cloud_storage_gallery: ^1.0.0
  material_ui: ^1.11.1
  # flutter_localizations:   # remove if you only used it for
  #   sdk: flutter           # Global*Localizations.delegate
```

Also check these:

- **`file_picker` / `share_plus`**: if your app depends on them directly, raise those constraints to `^13.4.0` / `^13.3.1`, or pub can't resolve. `file_picker` 12+ changed its API. `pickFiles()` now returns `List<PlatformFile>` directly (empty when cancelled, no `FilePickerResult`), and `pickFile()` handles single picks. See its [changelog](https://pub.dev/packages/file_picker/changelog).
- **`path` / `path_provider`**: 1.0.0 no longer depends on them. If your app imported them without declaring them, add them to your own `dependencies:`.
- **`video_thumbnail`**: if your app depended on it directly for the same reason, consider switching to `generateThumbnails` from this package, or to `fc_native_video_thumbnail`.

## 3. Move your app to material_ui

Flutter ships a data-driven fix that changes `package:flutter/material.dart` imports to `package:material_ui/material_ui.dart`:

```sh
dart fix --apply --code=migrate_design_widgets
```

### Why this step is required

`material_ui` is a separate copy of the Material library, not a re-export. Its `ThemeData`, `Theme` and `MaterialLocalizations` are different types from the ones in `flutter/material.dart`. If your app keeps a legacy `flutter/material.dart` `MaterialApp`:

- the gallery widgets will not see your theme and will fall back to `material_ui`'s defaults;
- anything that needs `MaterialLocalizations` (dialogs, tooltips, back buttons) will throw an assertion error.

`MaterialUiCompatibilityBridge` does **not** fix this. It only maps a `material_ui` theme onto legacy widgets, not the other way round.

### Your other packages

If your app also uses packages that still import `flutter/material.dart`, wrap your app (or just those subtrees) in the bridge so they keep your theme:

```dart
import 'package:material_ui/material_ui.dart';

MaterialApp(
  theme: myTheme,
  builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
  home: const HomeScreen(),
);
```

`MaterialUiCompatibilityBridge` is itself **deprecated**. Flutter marks it as a temporary migration utility, so expect `deprecated_member_use` infos, and plan to remove it once those packages migrate. Within `material_ui` 1.x it stays available; removing it would be a major bump of `material_ui`.

You don't need to do this for the gallery's own dependencies. `CloudMediaViewer` already bridges `chewie`.

## 4. Localization delegates

Use `material_ui`'s delegate bundle (Material + Cupertino + Widgets) instead of the three `flutter_localizations` delegates:

```diff
-import 'package:flutter/material.dart';
-import 'package:flutter_localizations/flutter_localizations.dart';
+import 'package:material_ui/material_ui.dart';

 MaterialApp(
   supportedLocales: CloudGalleryLocalizations.supportedLocales,
   localizationsDelegates: const [
     CloudGalleryLocalizations.delegate,
-    GlobalMaterialLocalizations.delegate,
-    GlobalWidgetsLocalizations.delegate,
-    GlobalCupertinoLocalizations.delegate,
+    ...GlobalMaterialLocalizations.delegates,
   ],
 );
```

## 5. iOS

`fc_native_video_thumbnail` 4.x requires **iOS 16.0**.

- In Xcode (`ios/Runner.xcodeproj`), set **iOS Deployment Target** to 16.0 for the Runner target. The build setting is `IPHONEOS_DEPLOYMENT_TARGET = 16.0`.
- If your `ios/Podfile` has a `platform :ios, '...'` line, set it to `'16.0'`, then run `cd ios && pod install --repo-update`.

## 6. Android

Flutter 3.50 itself requires Gradle 9.3.1 or newer. The example app uses the values from Flutter 3.50's app template:

| File | Setting |
|---|---|
| `android/gradle/wrapper/gradle-wrapper.properties` | `distributionUrl=...gradle-9.5.0-all.zip` |
| `android/settings.gradle.kts` | `com.android.application` **9.3.1**, `org.jetbrains.kotlin.android` **2.4.20** |
| `android/app/build.gradle.kts` | drop `id("kotlin-android")`; replace `kotlinOptions { jvmTarget = ... }` with `kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_17 } }` |
| `android/gradle.properties` | `android.builtInKotlin=false` and `android.newDsl=false` (Flutter's migrator adds these on the first build) |

`minSdk` must be **24** or higher. `flutter.minSdkVersion` already is on current Flutter.

After upgrading plugins, run `flutter clean` once. Stale Kotlin build output from older plugin versions can cause misleading "unresolved reference" errors.

## 7. Behaviour notes

- `generateThumbnails` keeps its contract: `null` means "upload without variants". It also returns `null` (and logs via `debugPrint`) when the native decoder can't read a video. Setup errors such as a `MissingPluginException` still throw, so a misconfigured app doesn't silently lose every thumbnail.
- Video thumbnails are still taken from the first frame and are limited by width only, so portrait clips keep a 1024px-wide preview, as in 0.6.x.
- Supported platforms are still **Android and iOS**. `fc_native_video_thumbnail` also builds for desktop, but on Windows it returns square frames and can't seek, so desktop thumbnails would not match the 256w/1024w aspect-preserving output.

## Reference

- The [example app](https://github.com/rashidotm/flutter_shared_storage/tree/master/example) is migrated and builds on Flutter 3.50. Compare its `lib/main.dart` and `android/` with your app.
- [`material_ui` migration notes](https://pub.dev/packages/material_ui)
