# 0.1.1

* Bumped sibling dep constraints to `^0.1.1`
  (`cloud_storage_platform_interface`, `cloud_storage_firebase`) —
  picks up the Firebase major bumps in `cloud_storage_firebase` 0.1.1.
* Removed unnecessary library-name declaration.

# 0.1.0

Initial release.

* Umbrella package re-exporting `cloud_storage_platform_interface` and
  `cloud_storage_firebase`.
* `defaultCloudStorage({firestorePath, storagePath})` convenience factory
  returning the default Firebase backend.
