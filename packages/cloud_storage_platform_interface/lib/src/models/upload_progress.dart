import 'package:meta/meta.dart';

enum UploadStatus { running, paused, success, canceled, error }

@immutable
class UploadProgress {
  const UploadProgress({
    required this.bytesTransferred,
    required this.totalBytes,
    required this.status,
    this.error,
  });

  final int bytesTransferred;

  /// `null` if total size is unknown (e.g. streaming source).
  final int? totalBytes;
  final UploadStatus status;
  final Object? error;

  /// 0.0 .. 1.0, or `null` when [totalBytes] is unknown.
  double? get fraction {
    final total = totalBytes;
    if (total == null || total == 0) return null;
    return bytesTransferred / total;
  }

  bool get isTerminal =>
      status == UploadStatus.success ||
      status == UploadStatus.canceled ||
      status == UploadStatus.error;
}
