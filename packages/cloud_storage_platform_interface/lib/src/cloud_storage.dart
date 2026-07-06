import 'dart:io';
import 'dart:typed_data';

import 'models/cloud_node.dart';
import 'models/source.dart';
import 'upload_task.dart';

/// Sentinel used by [CloudStorage] APIs to refer to the user's root folder.
const String kRootFolderId = '';

/// Backend-agnostic contract for cloud file/folder storage.
///
/// Concrete implementations (e.g. `cloud_storage_firebase`) provide the
/// transport. Consumers depend on [CloudStorage] and inject an implementation.
abstract class CloudStorage {
  // ── Listing ───────────────────────────────────────────────────────────────

  /// Streams the contents of [folderId]. Folders are emitted before files.
  /// Pass [kRootFolderId] for the user's root.
  Stream<List<CloudNode>> watchFolder(String folderId);

  /// One-shot read of [folderId]'s contents.
  Future<List<CloudNode>> listFolder(String folderId);

  /// Resolves a node by id. Throws [NotFoundException] if missing.
  Future<CloudNode> getNode(String nodeId);

  // ── Folders ───────────────────────────────────────────────────────────────

  /// Creates a folder under [parentId]. If a sibling with the same name
  /// already exists, [name] is auto-suffixed with " (1)", " (2)", etc.
  Future<CloudFolder> createFolder({
    required String parentId,
    required String name,
  });

  Future<void> renameFolder(String folderId, String newName);

  /// Deletes [folderId]. If [recursive] is false and the folder is non-empty,
  /// throws [InvalidArgumentException].
  Future<void> deleteFolder(String folderId, {bool recursive = false});

  Future<void> moveFolder(String folderId, {required String newParentId});

  // ── Files ─────────────────────────────────────────────────────────────────

  /// Starts an upload. The returned [UploadTask] exposes a progress stream
  /// (tracking only the original) and the final [CloudFile]. Auto-renames
  /// on conflict.
  ///
  /// If [thumbnail] and/or [preview] are supplied, the package writes them
  /// alongside the original at the well-known variant paths and populates
  /// `thumbnailUrl` / `previewUrl` on the resulting [CloudFile]. The caller
  /// is responsible for generating them — the package does not do any
  /// image/video processing.
  ///
  /// Both variants should be **JPEG** bytes/files. They're written to
  /// `.jpg` paths regardless of the source's actual format.
  UploadTask upload({
    required String parentId,
    required String name,
    required Source source,
    String? mimeType,
    Source? thumbnail,
    Source? preview,
  });

  /// Downloads the file's bytes to a local cache and returns the file handle.
  /// Subsequent calls with [useCache] true return the cached copy.
  Future<File> download(String fileId, {bool useCache = true});

  /// Convenience: download as in-memory bytes.
  Future<Uint8List> downloadBytes(String fileId);

  Future<void> deleteFile(String fileId);

  Future<void> renameFile(String fileId, String newName);

  Future<void> moveFile(String fileId, {required String newParentId});

  /// Attaches or replaces a custom thumbnail (and optionally a preview)
  /// for an existing file. Useful for files that don't have a
  /// content-derived thumbnail — PDFs, docs, etc. — or to override a bad
  /// auto-generated one.
  ///
  /// Both sources should be **JPEG** bytes/files. The backend writes them
  /// to the well-known variant paths and updates the file's
  /// `thumbnailUrl` / `previewUrl`. Existing variants at those paths are
  /// overwritten.
  ///
  /// When the file is later deleted via [deleteFile], the variants are
  /// removed alongside it automatically.
  Future<void> setThumbnail(
    String fileId, {
    required Source thumbnail,
    Source? preview,
  });
}
