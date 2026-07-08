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
