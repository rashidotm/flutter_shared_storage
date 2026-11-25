# 0.1.3

* **FlutterFire v5 allowed alongside v4.** The ranges now cover both
  majors, so apps can move to FlutterFire v5 (e.g. for
  `firebase_ui_auth` 4.x) without waiting on this package, or stay on v4:
  * `firebase_core` `>=4.0.0 <6.0.0`
  * `firebase_auth` `>=6.0.0 <8.0.0`
  * `firebase_storage` `>=13.0.0 <15.0.0`
  * `cloud_firestore` `>=6.0.0 <8.0.0`
* No code changes were needed. v5's breaking changes are native SDK
  bumps (Firebase iOS SDK 13, Android BoM 35 / minSdk 24, macOS 11 for
  Swift packages). The test suite passes against the latest v4
  (core 4.15.2 / auth 6.7.1 / storage 13.6.1 / firestore 6.10.2) and v5
  (core 5.2.0 / auth 7.1.0 / storage 14.1.0 / firestore 7.2.0).
* Dev-only: `fake_cloud_firestore` `>=4.1.1 <5.0.0` and
  `firebase_storage_mocks` `>=0.8.1 <0.10.0`, so the tests resolve
  against either major. The workspace-only `cloud_firestore` /
  `firebase_storage` override pins are removed; the monorepo now
  develops against v5.

# 0.1.2

* Implements the new `UploadTask.name` accessor from
  `cloud_storage_platform_interface` 0.1.2. Both `FirebaseUploadTask`
  and the pre-bind wrapper `_DeferredUploadTask` now carry the
  resolved filename through, so progress dialogs can render it.
* Sibling dep `cloud_storage_platform_interface` bumped to `^0.1.2`.

# 0.1.1

* **Firebase family major bump:** `firebase_core` `^4.0.0`,
  `firebase_auth` `^6.0.0`, `firebase_storage` `^13.0.0`,
  `cloud_firestore` `^6.0.0`. **Requires consumers to also bump their
  Firebase deps together.**
* `mime` bumped to `^2.0.0` (major).
* `path_provider` `^2.1.6`, `meta` `^1.17.0`.
* Sibling dep `cloud_storage_platform_interface` bumped to `^0.1.1`.
* Removed unnecessary library-name declarations flagged by
  `flutter_lints` v6.

# 0.1.0

Initial release.

* Firebase Storage + Firestore implementation of `CloudStorage` from
  `cloud_storage_platform_interface`.
* Caller-supplied paths — `FirebaseCloudStorage({firestorePath, storagePath})`.
  No assumption about tenancy; auth and access control are the consumer's
  concern (via Firestore + Storage security rules).
* Flat storage layout: originals at `{root}/{nodeId}.{ext}`; client-supplied
  thumbnail / preview JPEGs at `{root}/thumbs/{nodeId}.jpg` and
  `{root}/previews/{nodeId}.jpg`.
* Firestore-only mutations for renames and moves — the byte layer is never
  touched.
* Auto-rename on name conflict (`report.pdf` → `report (1).pdf`).
* Cancelled or failed uploads roll back the pre-created Firestore doc.
* Downloads cached via `flutter_cache_manager`.
* Link nodes: URL bookmarks stored purely in Firestore (no bytes) with
  optional custom thumbnail.
