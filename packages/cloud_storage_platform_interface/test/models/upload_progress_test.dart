import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:test/test.dart';

void main() {
  group('UploadProgress.fraction', () {
    test('returns bytesTransferred / totalBytes when total is known', () {
      final p = UploadProgress(
        bytesTransferred: 30,
        totalBytes: 120,
        status: UploadStatus.running,
      );
      expect(p.fraction, closeTo(0.25, 1e-9));
    });

    test('returns null when totalBytes is null (streaming source)', () {
      const p = UploadProgress(
        bytesTransferred: 42,
        totalBytes: null,
        status: UploadStatus.running,
      );
      expect(p.fraction, isNull);
    });

    test('returns null when totalBytes is 0 to avoid divide-by-zero', () {
      const p = UploadProgress(
        bytesTransferred: 0,
        totalBytes: 0,
        status: UploadStatus.running,
      );
      expect(p.fraction, isNull);
    });
  });

  group('UploadProgress.isTerminal', () {
    UploadProgress ofStatus(UploadStatus s) => UploadProgress(
          bytesTransferred: 0,
          totalBytes: 100,
          status: s,
        );

    test('success is terminal', () {
      expect(ofStatus(UploadStatus.success).isTerminal, isTrue);
    });

    test('canceled is terminal', () {
      expect(ofStatus(UploadStatus.canceled).isTerminal, isTrue);
    });

    test('error is terminal', () {
      expect(ofStatus(UploadStatus.error).isTerminal, isTrue);
    });

    test('running is NOT terminal', () {
      expect(ofStatus(UploadStatus.running).isTerminal, isFalse);
    });

    test('paused is NOT terminal', () {
      expect(ofStatus(UploadStatus.paused).isTerminal, isFalse);
    });
  });

  test('UploadStatus enum covers exactly the documented states', () {
    expect(UploadStatus.values, {
      UploadStatus.running,
      UploadStatus.paused,
      UploadStatus.success,
      UploadStatus.canceled,
      UploadStatus.error,
    });
  });
}
