import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';

import 'firestore_schema.dart';

/// Decodes a Firestore document into a [CloudNode].
CloudNode nodeFromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
  final data = snap.data();
  if (data == null) {
    throw NotFoundException('Node ${snap.id} not found');
  }
  return _nodeFromData(snap.id, data);
}

CloudNode nodeFromQueryDoc(QueryDocumentSnapshot<Map<String, dynamic>> snap) {
  return _nodeFromData(snap.id, snap.data());
}

CloudNode _nodeFromData(String id, Map<String, dynamic> data) {
  final type = data[kFieldType] as String? ?? kTypeFile;
  final createdAt = (data[kFieldCreatedAt] as Timestamp?)?.toDate() ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final updatedAt =
      (data[kFieldUpdatedAt] as Timestamp?)?.toDate() ?? createdAt;

  if (type == kTypeFolder) {
    return CloudFolder(
      id: id,
      name: data[kFieldName] as String? ?? '',
      parentId: data[kFieldParentId] as String? ?? '',
      path: data[kFieldPath] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  if (type == kTypeLink) {
    return CloudLink(
      id: id,
      name: data[kFieldName] as String? ?? '',
      parentId: data[kFieldParentId] as String? ?? '',
      path: data[kFieldPath] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      url: data[kFieldUrl] as String? ?? '',
      thumbnailUrl: data[kFieldThumbnailUrl] as String?,
      previewUrl: data[kFieldPreviewUrl] as String?,
    );
  }

  return CloudFile(
    id: id,
    name: data[kFieldName] as String? ?? '',
    parentId: data[kFieldParentId] as String? ?? '',
    path: data[kFieldPath] as String? ?? '',
    createdAt: createdAt,
    updatedAt: updatedAt,
    mimeType: data[kFieldMimeType] as String? ?? 'application/octet-stream',
    sizeBytes: (data[kFieldSizeBytes] as num?)?.toInt() ?? 0,
    storagePath: data[kFieldStoragePath] as String? ?? '',
    downloadUrl: data[kFieldDownloadUrl] as String? ?? '',
    thumbnailUrl: data[kFieldThumbnailUrl] as String?,
    previewUrl: data[kFieldPreviewUrl] as String?,
  );
}
