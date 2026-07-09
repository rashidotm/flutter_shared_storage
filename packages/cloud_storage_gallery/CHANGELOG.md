# 0.1.1

* **`file_picker` bumped `^8` → `^11`.** API change: use
  `FilePicker.pickFiles(...)` (static) instead of the removed
  `FilePicker.platform.pickFiles(...)`. Package internals updated;
  consumers using the gallery widgets don't need changes.
* **`share_plus` bumped `^10` → `^11`.** API change: switched to
  `SharePlus.instance.share(ShareParams(files: ..., subject: ...))`.
  The legacy `Share.shareXFiles(...)` was deprecated. Only affects
  the "open in external app" fallback flow.
* `mime` bumped `^1` → `^2`.
* `chewie` bumped `^1.8.5` → `^1.13.0`. Deliberately capped below 1.14
  (which pulls in `win32 ^6` via `wakelock_plus 1.6+` and conflicts
  with `share_plus <13` and `file_picker <12`).
* `path_provider` `^2.1.6`.
* Sibling dep `cloud_storage_platform_interface` bumped to `^0.1.1`.
* Removed unnecessary library-name declaration.

# 0.1.0

Initial release. Ready-made Flutter widgets on top of `cloud_storage`.

Widgets:

* `CloudFolderScreen` — drop-in file-manager screen. Breadcrumb app bar,
  thumbnail grid, long-press context menu, four floating action buttons
  (Select / Create folder / Add link / Upload file), full-featured
  action dialogs.
* `CloudMediaViewer` — headless swipeable photo/video viewer. Videos
  stream from the network on first play and cache locally for instant
  replay.
* `CloudFolderGrid` — reactive grid tile view of a folder.
* `CloudFolderBreadcrumb` — self-loading or externally-supplied
  breadcrumb.
* `CloudUploadDialog`, `CloudBatchUploadDialog`, `CloudBulkProgressDialog`
  — modal progress dialogs.
* `pickCloudFolder(...)` — modal folder picker.
* `generateThumbnails(File)` — helper that produces 256 px thumb + 1024 px
  preview JPEGs from images and videos.

Features:

* Selection mode with bulk delete / move.
* Custom thumbnail support for files and links (including videos when
  the auto-generated one isn't good enough).
* External-app open flow for non-media files (PDFs, docs, ...) with
  fallback to the OS share sheet.
* URL links open in an external browser via `url_launcher`.
* Read-only mode hides all write-oriented UI.
* Localization via `CloudGalleryLocalizations` delegate — English and
  Arabic strings included; RTL layouts respected throughout.
* Every widget derives its colors, text styles, and directionality
  from the ambient `Theme` / `Directionality`.
