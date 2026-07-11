import 'models/cloud_node.dart';
import 'models/upload_progress.dart';

/// Handle to an in-flight upload.
abstract class UploadTask {
  /// Live progress updates. Emits at least one terminal event
  /// (`success`, `canceled`, or `error`) before closing.
  Stream<UploadProgress> get progress;

  /// Resolves with the created [CloudFile] on success, or throws on failure.
  Future<CloudFile> get result;

  /// Human-readable filename for progress UIs. Defaults to an empty
  /// string so existing implementations remain source-compatible;
  /// backends should override with the actual filename.
  String get name => '';

  Future<void> cancel();
}
