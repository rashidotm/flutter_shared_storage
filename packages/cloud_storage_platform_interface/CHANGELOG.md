# 0.1.2

* New `UploadTask.name` getter for progress UIs. Defaults to an empty
  string on the abstract class, so existing implementations remain
  source-compatible — backends should override with the actual filename.

# 0.1.1

* Bumped `meta` to `^1.17.0` and `cross_file` to `^0.3.5+2`.
* Dev deps: `flutter_lints` `^6.0.0`, `test` `^1.31.0`.

# 0.1.0

Initial release.

* Sealed `CloudNode` hierarchy: `CloudFolder`, `CloudFile`, `CloudLink`.
* `CloudStorage` abstract contract for a backend-agnostic file/folder/link
  storage layer:
  * Live folder listings via `watchFolder`.
  * File uploads with progress streams and optional pre-supplied JPEG
    thumbnail / preview variants (`upload`, `setThumbnail`).
  * Folder / file / link mutations: `create*`, `rename*`, `move*`,
    `delete*`, `updateLinkUrl`.
* Supporting types: `Source` (`FileSource` / `BytesSource` /
  `XFileSource`), `UploadTask`, `UploadProgress`, `UploadStatus`.
* Exception hierarchy: `CloudStorageException`, `NotFoundException`,
  `PermissionDeniedException`, `InvalidArgumentException`,
  `UploadFailedException`, `DownloadFailedException`,
  `UnauthenticatedException`.
