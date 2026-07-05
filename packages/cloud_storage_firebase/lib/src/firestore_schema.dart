/// Firestore document schema used by the Firebase implementation.
///
/// The collection path is supplied by the caller (see
/// `FirebaseCloudStorage(firestorePath: ...)`). Within whatever collection
/// the caller chooses, each document has this shape:
///
/// ```
/// {firestorePath}/{nodeId}
///     type:         "file" | "folder"
///     name:         string
///     parentId:     string  // "" for the root within the caller's namespace
///     path:         string  // "/photos/2025"
///     mimeType:     string?     // files only
///     sizeBytes:    int?        // files only
///     storagePath:  string?     // files only — absolute bucket path
///     downloadUrl:  string?     // files only
///     thumbnailUrl: string?     // populated by the Cloud Function
///     previewUrl:   string?     // populated by the Cloud Function
///     createdAt:    Timestamp
///     updatedAt:    Timestamp
/// ```
library firestore_schema;

const String kFieldType = 'type';
const String kFieldName = 'name';
const String kFieldParentId = 'parentId';
const String kFieldPath = 'path';
const String kFieldMimeType = 'mimeType';
const String kFieldSizeBytes = 'sizeBytes';
const String kFieldStoragePath = 'storagePath';
const String kFieldDownloadUrl = 'downloadUrl';
const String kFieldThumbnailUrl = 'thumbnailUrl';
const String kFieldPreviewUrl = 'previewUrl';
const String kFieldCreatedAt = 'createdAt';
const String kFieldUpdatedAt = 'updatedAt';

const String kTypeFile = 'file';
const String kTypeFolder = 'folder';

/// Storage path for the original bytes: `{storageRoot}/{nodeId}/original{.ext}`.
String storagePathFor(String storageRoot, String nodeId, String extension) {
  final ext = extension.isEmpty
      ? ''
      : (extension.startsWith('.') ? extension : '.$extension');
  final trimmedRoot = storageRoot.endsWith('/')
      ? storageRoot.substring(0, storageRoot.length - 1)
      : storageRoot;
  return '$trimmedRoot/$nodeId/original$ext';
}
