import 'package:cloud_storage/cloud_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test: the umbrella must re-export the platform interface types
/// and the default Firebase implementation entry point.
void main() {
  test('re-exports the platform interface types', () {
    // The following are typedef/class references that must resolve
    // through `package:cloud_storage/cloud_storage.dart`.
    expect(kRootFolderId, '');
    expect(CloudNode, isNotNull);
    expect(CloudFolder, isNotNull);
    expect(CloudFile, isNotNull);
    expect(CloudLink, isNotNull);
    expect(UploadStatus.values, isNotEmpty);
  });

  test('exposes defaultCloudStorage factory', () {
    // Just ensure the symbol is reachable and is a Function — we don't
    // actually construct one (that would require Firebase.initializeApp).
    expect(defaultCloudStorage, isA<Function>());
  });
}
