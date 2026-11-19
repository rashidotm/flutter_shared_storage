# cloud_storage_gallery

Ready-made widgets for browsing folders, viewing media, uploading with progress, and generating thumbnails on top of [`cloud_storage`](../cloud_storage).

Everything inherits from the host app's `Theme` and respects `Directionality.of(context)` for RTL/LTR.

Ships with **English** and **Arabic** translations out of the box — see [Localization](#localization) below.

> **Upgrading from 0.6.x?** 1.0.0 is a breaking release: the widgets are now built on [`material_ui`](https://pub.dev/packages/material_ui) and the platform minimums went up. Follow the [migration guide](MIGRATION.md).

## Requirements

| | Minimum |
|---|---|
| Flutter / Dart | **3.47** / **3.13** |
| Android | minSdk **24**; Gradle **9.3.1+** / AGP **9** (what Flutter 3.50's app template generates) |
| iOS | **16.0** deployment target |
| Host app | Built with [`package:material_ui`](https://pub.dev/packages/material_ui), not the deprecated `package:flutter/material.dart` |

The widgets read `Theme` and `MaterialLocalizations` from `material_ui`. Those are separate types from the ones in `package:flutter/material.dart`. Under a legacy `flutter/material.dart` `MaterialApp`, the widgets would not see your theme, and anything that needs `MaterialLocalizations` would assert. Flutter's `MaterialUiCompatibilityBridge` only bridges the other way round (legacy widgets inside a `material_ui` app), so it does not help here.

## Fast path — `CloudFolderScreen`

Drop-in file browser with every action wired up. This is what the example app uses:

```dart
import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:material_ui/material_ui.dart';

MaterialApp(
  home: CloudFolderScreen(storage: myCloudStorage),
);
```

For viewer-only users, set `readOnly: true`:

```dart
CloudFolderScreen(storage: myCloudStorage, readOnly: true),
```

In read-only mode both FABs are hidden and the long-press menu drops **Rename**, **Move to…**, and **Delete**. **Open**, **Download**, and **Info** stay. The flag is a UI concern only — pair it with Firestore/Storage security rules if you need actual protection.

Ships with:

- Breadcrumb in the app bar (tap any segment to jump).
- Grid of subfolders + files, thumbnails when available.
- Long-press context menu — **Select**, **Open**, **Download**, **Rename**, **Move to…**, **Info**, **Delete** (mutation entries + **Select** suppressed when `readOnly`).
- **Selection mode** — long-press → *Select* enters multi-select; tap tiles to toggle; the AppBar switches to `X selected` with bulk **Move to…** and **Delete** actions. Selected tiles get a primary-colored border + check-circle badge.
- FABs — **Create folder**, **Upload file** (client-side thumbnails generated automatically for images + videos; supports selecting multiple files at once). Hidden when `readOnly`.
- Upload progress dialog with a Cancel button; failed/cancelled uploads roll back the Firestore doc. For multi-file selections, an aggregate "X of N complete" batch dialog replaces the single-file one.

## Building blocks

If you want a different UX, compose your own screen from the pieces:

| Widget / helper | Purpose |
|---|---|
| `CloudFolderGrid` | Live grid of a folder's contents. Tap and long-press callbacks. |
| `CloudFolderBreadcrumb` | Ancestor-chain breadcrumb. Accepts a pre-computed chain to skip fetching. |
| `CloudMediaViewer` | Headless, swipeable image/video viewer. You provide the `Scaffold` / `AppBar`. |
| `CloudUploadDialog` | Progress dialog with an idempotent cancel. |
| `CloudBatchUploadDialog` | Aggregate "X of N complete" progress dialog for a list of upload tasks. |
| `pickCloudFolder(...)` | Modal folder picker. Returns the selected folder id. |
| `generateThumbnails(File)` | JPEG thumb (256w) + preview (1024w) for images + videos. Returns `null` for other MIME types, and for videos the platform can't decode. Video frames come from [`fc_native_video_thumbnail`](https://pub.dev/packages/fc_native_video_thumbnail) (native platform APIs, no FFmpeg). |

## Localization

Register the delegate on your `MaterialApp` and choose a locale (or let the device locale drive it):

```dart
import 'package:material_ui/material_ui.dart';

MaterialApp(
  supportedLocales: CloudGalleryLocalizations.supportedLocales,
  localizationsDelegates: const [
    CloudGalleryLocalizations.delegate,
    // material_ui's bundle: Material + Cupertino + Widgets delegates.
    ...GlobalMaterialLocalizations.delegates,
  ],
  // Force a locale for testing; omit in production to follow the device.
  locale: const Locale('ar'),
  home: CloudFolderScreen(storage: myStorage),
);
```

`GlobalMaterialLocalizations` comes from `material_ui`, which you already depend on (see [Requirements](#requirements)). You don't need `flutter_localizations`:

```yaml
dependencies:
  material_ui: ^1.11.1
```

**Adding a language.** Subclass `CloudGalleryLocalizations`, override every getter, and register your own `LocalizationsDelegate<CloudGalleryLocalizations>` before the built-in one in `localizationsDelegates`. Your delegate wins for the languages it says it supports; the built-in one covers `en` and `ar` and falls back to English otherwise.

## Dependencies

Pulls in `material_ui`, `cached_network_image`, `flutter_cache_manager`, `photo_view`, `video_player`, `chewie`, `file_picker`, `share_plus`, `image`, `fc_native_video_thumbnail`, `mime`, `open_filex`, `url_launcher`. If any of these are unwanted, either fork the widgets or depend only on `cloud_storage` and build your own UI.

`chewie` (the video player controls) still uses `package:flutter/material.dart`. Internally the viewer wraps it in `MaterialUiCompatibilityBridge`, so its controls pick up your `material_ui` theme. You don't need to do anything. The bridge is a deprecated, temporary Flutter utility. It's available throughout `material_ui` 1.x (which this package pins with `^1.11.1`), and the wrapper will be dropped once chewie migrates.
