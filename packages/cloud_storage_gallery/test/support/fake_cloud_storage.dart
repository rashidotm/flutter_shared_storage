import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';

/// In-memory [CloudStorage] fake for widget tests.
///
/// Populate the constructor's [children] map with the folder → contents
/// layout the test needs. Reads ([watchFolder], [listFolder], [getNode])
/// return that data. Mutations throw [UnimplementedError] by default —
/// override on a per-test basis by extending this class if a specific
/// path needs to be exercised.
class FakeCloudStorage implements CloudStorage {
  FakeCloudStorage({
    Map<String, List<CloudNode>>? children,
  }) : _children = <String, List<CloudNode>>{...?children};

  final Map<String, List<CloudNode>> _children;
  final Map<String, StreamController<List<CloudNode>>> _controllers = {};

  /// Programmatically replace a folder's contents and push the new list
  /// down the [watchFolder] stream. Tests use this to simulate live
  /// changes.
  void setChildren(String folderId, List<CloudNode> nodes) {
    _children[folderId] = List<CloudNode>.of(nodes);
    _controllers[folderId]?.add(List<CloudNode>.of(nodes));
  }

  // ── Reads ────────────────────────────────────────────────────────────

  @override
  Stream<List<CloudNode>> watchFolder(String folderId) {
    final controller = _controllers.putIfAbsent(
      folderId,
      () => StreamController<List<CloudNode>>.broadcast(),
    );
    // Emit the current snapshot asynchronously so listeners subscribe
    // first — matches Firestore's behavior of firing the first value
    // just after the caller attaches.
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(List<CloudNode>.of(_children[folderId] ?? const []));
      }
    });
    return controller.stream;
  }

  @override
  Future<List<CloudNode>> listFolder(String folderId) async =>
      List<CloudNode>.of(_children[folderId] ?? const []);

  @override
  Future<CloudNode> getNode(String nodeId) async {
    // Callers (notably CloudFolderBreadcrumb) resolve the root by id
    // even though it's not a "real" child of anything. Return a
    // synthetic root for the sentinel.
    if (nodeId == kRootFolderId) {
      return makeFolder('', id: kRootFolderId);
    }
    for (final entries in _children.values) {
      for (final node in entries) {
        if (node.id == nodeId) return node;
      }
    }
    throw NotFoundException('Node $nodeId not found');
  }

  // ── Mutations — stubbed to throw. Override per-test if needed. ───────

  @override
  Future<CloudFolder> createFolder({
    required String parentId,
    required String name,
  }) =>
      throw UnimplementedError('createFolder');

  @override
  Future<void> renameFolder(String folderId, String newName) =>
      throw UnimplementedError('renameFolder');

  @override
  Future<void> deleteFolder(String folderId, {bool recursive = false}) =>
      throw UnimplementedError('deleteFolder');

  @override
  Future<void> moveFolder(String folderId, {required String newParentId}) =>
      throw UnimplementedError('moveFolder');

  @override
  UploadTask upload({
    required String parentId,
    required String name,
    required Source source,
    String? mimeType,
    Source? thumbnail,
    Source? preview,
  }) =>
      throw UnimplementedError('upload');

  @override
  Future<File> download(String fileId, {bool useCache = true}) =>
      throw UnimplementedError('download');

  @override
  Future<Uint8List> downloadBytes(String fileId) =>
      throw UnimplementedError('downloadBytes');

  @override
  Future<void> deleteFile(String fileId) =>
      throw UnimplementedError('deleteFile');

  @override
  Future<void> renameFile(String fileId, String newName) =>
      throw UnimplementedError('renameFile');

  @override
  Future<void> moveFile(String fileId, {required String newParentId}) =>
      throw UnimplementedError('moveFile');

  @override
  Future<void> setThumbnail(
    String nodeId, {
    required Source thumbnail,
    Source? preview,
  }) =>
      throw UnimplementedError('setThumbnail');

  @override
  Future<CloudLink> createLink({
    required String parentId,
    required String name,
    required String url,
  }) =>
      throw UnimplementedError('createLink');

  @override
  Future<void> updateLinkUrl(String linkId, String newUrl) =>
      throw UnimplementedError('updateLinkUrl');

  @override
  Future<void> renameLink(String linkId, String newName) =>
      throw UnimplementedError('renameLink');

  @override
  Future<void> moveLink(String linkId, {required String newParentId}) =>
      throw UnimplementedError('moveLink');

  @override
  Future<void> deleteLink(String linkId) =>
      throw UnimplementedError('deleteLink');
}

// ── Node fixture factories ──────────────────────────────────────────────

final _epoch = DateTime.utc(2026, 1, 1);

CloudFolder makeFolder(String name, {String? id, String parentId = ''}) =>
    CloudFolder(
      id: id ?? 'F-$name',
      name: name,
      parentId: parentId,
      path: '/$name',
      createdAt: _epoch,
      updatedAt: _epoch,
    );

CloudFile makeFile(
  String name, {
  String? id,
  String parentId = '',
  String mimeType = 'application/pdf',
  int sizeBytes = 100,
}) =>
    CloudFile(
      id: id ?? 'f-$name',
      name: name,
      parentId: parentId,
      path: '/$name',
      createdAt: _epoch,
      updatedAt: _epoch,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      storagePath: '/$name',
      downloadUrl: 'https://example.com/$name',
    );

CloudLink makeLink(String name, {String? id, String parentId = ''}) =>
    CloudLink(
      id: id ?? 'l-$name',
      name: name,
      parentId: parentId,
      path: '/$name',
      createdAt: _epoch,
      updatedAt: _epoch,
      url: 'https://example.com/$name',
    );
