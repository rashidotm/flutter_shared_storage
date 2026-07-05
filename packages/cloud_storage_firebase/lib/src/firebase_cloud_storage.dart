import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

// `cloud_firestore` re-exports a `Source` enum, and `flutter_cache_manager`
// re-exports a `FileSource` class — both clash with our platform-interface
// types. Hide them at the import site so callers see only ours.
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:firebase_storage/firebase_storage.dart' as fbs;
import 'package:flutter_cache_manager/flutter_cache_manager.dart' hide FileSource;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'firebase_upload_task.dart';
import 'firestore_schema.dart';
import 'name_resolver.dart';
import 'node_codec.dart';

/// Firebase implementation of [CloudStorage].
///
/// **Caller-supplied paths.** The package makes no assumption about where in
/// Firestore/Storage your data lives. You pass:
///
/// - [firestorePath]: a Firestore collection path where node documents live,
///   e.g. `users/abc/nodes`, `orgs/acme/projects/xyz/files`, `tenants/t1/blobs`.
/// - [storagePath]: a bucket-relative prefix where blobs live,
///   e.g. `users/abc/blobs`, `orgs/acme/files`.
///
/// Authentication, access control, and tenancy are entirely your concern.
/// Use Firestore/Storage security rules to scope each user/tenant to their
/// own prefix.
class FirebaseCloudStorage implements CloudStorage {
  FirebaseCloudStorage({
    required String firestorePath,
    required String storagePath,
    FirebaseFirestore? firestore,
    fbs.FirebaseStorage? storage,
    BaseCacheManager? cacheManager,
  }) : _firestorePath = _validatePath(firestorePath, 'firestorePath'),
       _storageRoot = _validatePath(storagePath, 'storagePath'),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? fbs.FirebaseStorage.instance,
       _cache = cacheManager ?? DefaultCacheManager();

  final String _firestorePath;
  final String _storageRoot;
  final FirebaseFirestore _firestore;
  final fbs.FirebaseStorage _storage;
  final BaseCacheManager _cache;

  // ── Internals ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _nodes =>
      _firestore.collection(_firestorePath);

  NameResolver get _resolver => NameResolver(_nodes);

  Future<String> _pathFor(String parentId, String name) async {
    if (parentId == kRootFolderId) return '/$name';
    final parent = await getNode(parentId);
    return p.posix.join(parent.path, name);
  }

  static String _validatePath(String value, String paramName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw InvalidArgumentException('$paramName cannot be empty');
    }
    if (trimmed.startsWith('/') || trimmed.endsWith('/')) {
      throw InvalidArgumentException(
        '$paramName must not start or end with "/"',
      );
    }
    if (trimmed.contains('//')) {
      throw InvalidArgumentException(
        '$paramName must not contain consecutive slashes',
      );
    }
    return trimmed;
  }

  // ── Listing ───────────────────────────────────────────────────────────────

  @override
  Stream<List<CloudNode>> watchFolder(String folderId) {
    return _nodes
        .where(kFieldParentId, isEqualTo: folderId)
        .snapshots()
        .map((q) => _sort(q.docs.map(nodeFromQueryDoc).toList()));
  }

  @override
  Future<List<CloudNode>> listFolder(String folderId) async {
    final q = await _nodes.where(kFieldParentId, isEqualTo: folderId).get();
    return _sort(q.docs.map(nodeFromQueryDoc).toList());
  }

  @override
  Future<CloudNode> getNode(String nodeId) async {
    if (nodeId == kRootFolderId) {
      // Synthetic root — has no document but callers expect a node back.
      return CloudFolder(
        id: kRootFolderId,
        name: '',
        parentId: '',
        path: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    final snap = await _nodes.doc(nodeId).get();
    if (!snap.exists) throw NotFoundException('Node $nodeId not found');
    return nodeFromSnapshot(snap);
  }

  static List<CloudNode> _sort(List<CloudNode> nodes) {
    nodes.sort((a, b) {
      // Folders first, then files, then by name (case-insensitive).
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return nodes;
  }

  // ── Folders ───────────────────────────────────────────────────────────────

  @override
  Future<CloudFolder> createFolder({
    required String parentId,
    required String name,
  }) async {
    _validateName(name);
    final resolved = await _resolver.resolve(parentId: parentId, desiredName: name);
    final path = await _pathFor(parentId, resolved);
    final doc = _nodes.doc();
    final now = FieldValue.serverTimestamp();
    await doc.set(<String, Object?>{
      kFieldType: kTypeFolder,
      kFieldName: resolved,
      kFieldParentId: parentId,
      kFieldPath: path,
      kFieldCreatedAt: now,
      kFieldUpdatedAt: now,
    });
    final created = await doc.get();
    final node = nodeFromSnapshot(created);
    return node as CloudFolder;
  }

  @override
  Future<void> renameFolder(String folderId, String newName) async {
    _validateName(newName);
    await _renameNode(folderId, newName);
  }

  @override
  Future<void> deleteFolder(String folderId, {bool recursive = false}) async {
    final children = await _nodes.where(kFieldParentId, isEqualTo: folderId).get();
    if (children.docs.isNotEmpty && !recursive) {
      throw const InvalidArgumentException(
        'Folder is not empty. Pass recursive: true to delete its contents.',
      );
    }
    for (final child in children.docs) {
      final type = child.data()[kFieldType] as String?;
      if (type == kTypeFolder) {
        await deleteFolder(child.id, recursive: true);
      } else {
        await deleteFile(child.id);
      }
    }
    await _nodes.doc(folderId).delete();
  }

  @override
  Future<void> moveFolder(String folderId, {required String newParentId}) =>
      _moveNode(folderId, newParentId);

  // ── Files ─────────────────────────────────────────────────────────────────

  @override
  UploadTask upload({
    required String parentId,
    required String name,
    required Source source,
    String? mimeType,
  }) {
    final controller = _DeferredUploadTask();
    unawaited(
      _startUpload(
        parentId: parentId,
        name: name,
        source: source,
        mimeType: mimeType,
        controller: controller,
      ),
    );
    return controller;
  }

  Future<void> _startUpload({
    required String parentId,
    required String name,
    required Source source,
    required String? mimeType,
    required _DeferredUploadTask controller,
  }) async {
    try {
      _validateName(name);
      final resolvedName = await _resolver.resolve(
        parentId: parentId,
        desiredName: name,
      );
      final path = await _pathFor(parentId, resolvedName);
      final guessedMime = mimeType ??
          lookupMimeType(resolvedName) ??
          'application/octet-stream';

      final doc = _nodes.doc();
      final ext = p.extension(resolvedName);
      final storagePath = storagePathFor(_storageRoot, doc.id, ext);
      final ref = _storage.ref(storagePath);

      final size = await source.length();

      // Pre-create the Firestore doc with placeholder fields so listings can
      // show the file as "uploading" if the consumer wants to render that.
      await doc.set(<String, Object?>{
        kFieldType: kTypeFile,
        kFieldName: resolvedName,
        kFieldParentId: parentId,
        kFieldPath: path,
        kFieldMimeType: guessedMime,
        kFieldSizeBytes: size ?? 0,
        kFieldStoragePath: storagePath,
        kFieldDownloadUrl: '',
        kFieldCreatedAt: FieldValue.serverTimestamp(),
        kFieldUpdatedAt: FieldValue.serverTimestamp(),
      });

      // nodeId is stored on the object for debug/cross-check. The Cloud
      // Function pairs storage objects with Firestore docs by extracting
      // nodeId from the storage path under its configured prefix.
      final metadata = fbs.SettableMetadata(
        contentType: guessedMime,
        customMetadata: <String, String>{'nodeId': doc.id},
      );

      final fbs.UploadTask storageTask = switch (source) {
        FileSource(:final file) => ref.putFile(file, metadata),
        BytesSource(:final bytes) => ref.putData(bytes, metadata),
        XFileSource(:final xfile) =>
          ref.putData(await xfile.readAsBytes(), metadata),
      };

      controller._bind(
        FirebaseUploadTask(
          storageTask: storageTask,
          nodeDoc: doc,
          onSuccess: (snap) async {
            final url = await ref.getDownloadURL();
            await doc.update(<String, Object?>{
              kFieldDownloadUrl: url,
              kFieldSizeBytes: snap.totalBytes,
              kFieldUpdatedAt: FieldValue.serverTimestamp(),
            });
          },
        ),
      );
    } catch (e, st) {
      controller._fail(e, st);
    }
  }

  @override
  Future<File> download(String fileId, {bool useCache = true}) async {
    final node = await getNode(fileId);
    if (node is! CloudFile) {
      throw const InvalidArgumentException('Node is a folder, not a file');
    }
    if (node.downloadUrl.isEmpty) {
      throw const DownloadFailedException('File is still uploading');
    }
    try {
      if (!useCache) {
        await _cache.removeFile(node.downloadUrl);
      }
      final file = await _cache.getSingleFile(node.downloadUrl, key: node.id);
      return file;
    } catch (e) {
      throw DownloadFailedException('Download failed', cause: e);
    }
  }

  @override
  Future<Uint8List> downloadBytes(String fileId) async {
    final file = await download(fileId);
    return file.readAsBytes();
  }

  @override
  Future<void> deleteFile(String fileId) async {
    final node = await getNode(fileId);
    if (node is! CloudFile) {
      throw const InvalidArgumentException('Node is a folder, not a file');
    }
    // Delete from cache, storage, then Firestore.
    await _cache.removeFile(node.id).catchError((_) {});
    if (node.storagePath.isNotEmpty) {
      try {
        await _storage.ref(node.storagePath).delete();
      } on fbs.FirebaseException catch (e) {
        // object-not-found is fine; the doc is what matters.
        if (e.code != 'object-not-found') rethrow;
      }
    }
    await _nodes.doc(fileId).delete();
  }

  @override
  Future<void> renameFile(String fileId, String newName) async {
    _validateName(newName);
    await _renameNode(fileId, newName);
  }

  @override
  Future<void> moveFile(String fileId, {required String newParentId}) =>
      _moveNode(fileId, newParentId);

  // ── Shared rename/move ────────────────────────────────────────────────────

  Future<void> _renameNode(String nodeId, String newName) async {
    final node = await getNode(nodeId);
    if (node.name == newName) return;
    final resolved = await _resolver.resolve(
      parentId: node.parentId,
      desiredName: newName,
    );
    final newPath = await _pathFor(node.parentId, resolved);
    await _nodes.doc(nodeId).update(<String, Object?>{
      kFieldName: resolved,
      kFieldPath: newPath,
      kFieldUpdatedAt: FieldValue.serverTimestamp(),
    });
    if (node is CloudFolder) {
      await _rewritePathsUnder(nodeId, newPath);
    }
  }

  Future<void> _moveNode(String nodeId, String newParentId) async {
    final node = await getNode(nodeId);
    if (node.parentId == newParentId) return;
    final resolved = await _resolver.resolve(
      parentId: newParentId,
      desiredName: node.name,
    );
    final newPath = await _pathFor(newParentId, resolved);
    await _nodes.doc(nodeId).update(<String, Object?>{
      kFieldParentId: newParentId,
      kFieldName: resolved,
      kFieldPath: newPath,
      kFieldUpdatedAt: FieldValue.serverTimestamp(),
    });
    if (node is CloudFolder) {
      await _rewritePathsUnder(nodeId, newPath);
    }
  }

  /// After a folder is renamed/moved, rewrite `path` on every descendant.
  Future<void> _rewritePathsUnder(String folderId, String newBasePath) async {
    final children = await _nodes.where(kFieldParentId, isEqualTo: folderId).get();
    for (final child in children.docs) {
      final childName = child.data()[kFieldName] as String? ?? '';
      final childPath = p.posix.join(newBasePath, childName);
      await child.reference.update(<String, Object?>{
        kFieldPath: childPath,
        kFieldUpdatedAt: FieldValue.serverTimestamp(),
      });
      if (child.data()[kFieldType] == kTypeFolder) {
        await _rewritePathsUnder(child.id, childPath);
      }
    }
  }

  static void _validateName(String name) {
    if (name.isEmpty) {
      throw const InvalidArgumentException('Name cannot be empty');
    }
    if (name.contains('/') || name.contains(r'\')) {
      throw const InvalidArgumentException('Name cannot contain slashes');
    }
    if (name == '.' || name == '..') {
      throw const InvalidArgumentException('Name cannot be "." or ".."');
    }
  }
}

/// Holds an [UploadTask] that's resolved asynchronously after some
/// pre-upload work (name resolution, doc creation) completes.
class _DeferredUploadTask implements UploadTask {
  final _bound = Completer<UploadTask>();
  final _progress = StreamController<UploadProgress>.broadcast();
  final _result = Completer<CloudFile>();

  void _bind(UploadTask inner) {
    inner.progress.listen(
      _progress.add,
      onError: _progress.addError,
      onDone: _progress.close,
    );
    inner.result.then(_result.complete).catchError((Object e, StackTrace st) {
      if (!_result.isCompleted) _result.completeError(e, st);
    });
    _bound.complete(inner);
  }

  void _fail(Object error, StackTrace st) {
    final wrapped = error is CloudStorageException
        ? error
        : UploadFailedException('Upload failed', cause: error);
    _progress.add(
      UploadProgress(
        bytesTransferred: 0,
        totalBytes: null,
        status: UploadStatus.error,
        error: wrapped,
      ),
    );
    if (!_result.isCompleted) _result.completeError(wrapped, st);
    if (!_bound.isCompleted) _bound.completeError(wrapped, st);
    unawaited(_progress.close());
  }

  @override
  Stream<UploadProgress> get progress => _progress.stream;

  @override
  Future<CloudFile> get result => _result.future;

  @override
  Future<void> cancel() async {
    if (_bound.isCompleted) {
      final inner = await _bound.future;
      await inner.cancel();
    }
  }
}
