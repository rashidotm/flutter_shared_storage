# cloud_storage_gallery

Ready-made widgets for browsing folders, viewing media, uploading with progress, and generating thumbnails on top of [`cloud_storage`](../cloud_storage).

Everything inherits from the host app's `Theme` and respects `Directionality.of(context)` for RTL/LTR.

## Fast path — `CloudFolderScreen`

Drop-in file browser with every action wired up. This is what the example app uses:

```dart
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
- Long-press context menu — **Open**, **Download**, **Rename**, **Move to…**, **Info**, **Delete** (last three suppressed when `readOnly`).
- FABs — **Create folder**, **Upload file** (client-side thumbnails generated automatically for images + videos). Hidden when `readOnly`.
- Upload progress dialog with a Cancel button; failed/cancelled uploads roll back the Firestore doc.

## Building blocks

If you want a different UX, compose your own screen from the pieces:

| Widget / helper | Purpose |
|---|---|
| `CloudFolderGrid` | Live grid of a folder's contents. Tap and long-press callbacks. |
| `CloudFolderBreadcrumb` | Ancestor-chain breadcrumb. Accepts a pre-computed chain to skip fetching. |
| `CloudMediaViewer` | Headless, swipeable image/video viewer. You provide the `Scaffold` / `AppBar`. |
| `CloudUploadDialog` | Progress dialog with an idempotent cancel. |
| `pickCloudFolder(...)` | Modal folder picker. Returns the selected folder id. |
| `generateThumbnails(File)` | JPEG thumb (256w) + preview (1024w) for images + videos. Returns `null` for other MIME types. |

## Dependencies

Pulls in `cached_network_image`, `photo_view`, `video_player`, `chewie`, `file_picker`, `share_plus`, `image`, `video_thumbnail`, `mime`, `path`, `path_provider`. If any of these are unwanted, either fork the widgets or depend only on `cloud_storage` and build your own UI.
