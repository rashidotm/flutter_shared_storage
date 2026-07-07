import 'package:meta/meta.dart';

/// A node in the cloud storage tree — either a [CloudFolder] or a [CloudFile].
sealed class CloudNode {
  const CloudNode({
    required this.id,
    required this.name,
    required this.parentId,
    required this.path,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// Empty string for the root folder.
  final String parentId;

  /// Absolute logical path, e.g. `/photos/2025/summer`.
  final String path;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFolder => this is CloudFolder;
  bool get isFile => this is CloudFile;
  bool get isLink => this is CloudLink;
}

@immutable
class CloudFolder extends CloudNode {
  const CloudFolder({
    required super.id,
    required super.name,
    required super.parentId,
    required super.path,
    required super.createdAt,
    required super.updatedAt,
  });
}

@immutable
class CloudFile extends CloudNode {
  const CloudFile({
    required super.id,
    required super.name,
    required super.parentId,
    required super.path,
    required super.createdAt,
    required super.updatedAt,
    required this.mimeType,
    required this.sizeBytes,
    required this.storagePath,
    required this.downloadUrl,
    this.thumbnailUrl,
    this.previewUrl,
  });

  final String mimeType;
  final int sizeBytes;

  /// Path inside the storage bucket, e.g. `users/{uid}/{nodeId}/original.jpg`.
  final String storagePath;
  final String downloadUrl;

  /// Set by the thumbnail Cloud Function once generated. May be `null` until then.
  final String? thumbnailUrl;

  /// Larger preview (e.g. video poster, full-res image preview).
  final String? previewUrl;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isMedia => isImage || isVideo;
}

/// A URL bookmark. Rendered as an entry in the folder grid alongside files
/// and folders, but the payload is just a [url] — no storage bytes. Tapping
/// a link opens the URL in an external browser / app.
///
/// Links may carry an optional user-supplied thumbnail (and preview) —
/// useful because links have no content the client can auto-derive a
/// thumbnail from.
@immutable
class CloudLink extends CloudNode {
  const CloudLink({
    required super.id,
    required super.name,
    required super.parentId,
    required super.path,
    required super.createdAt,
    required super.updatedAt,
    required this.url,
    this.thumbnailUrl,
    this.previewUrl,
  });

  /// The URL this link points to. May be missing a scheme — consumers
  /// should normalize as needed.
  final String url;

  /// Optional user-supplied thumbnail, set via [CloudStorage.setThumbnail].
  final String? thumbnailUrl;

  /// Optional user-supplied preview (larger variant).
  final String? previewUrl;
}
