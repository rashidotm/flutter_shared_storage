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
