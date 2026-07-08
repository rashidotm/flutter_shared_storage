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
