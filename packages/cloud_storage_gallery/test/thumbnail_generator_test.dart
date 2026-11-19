import 'dart:io';

import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart';
import 'package:flutter/services.dart' show PlatformException, Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Stand-in for the native thumbnailer. [onSave] decides what
/// `saveThumbnailToFile` does (write a frame and return true, return false,
/// or throw) so each test can model one native outcome.
class _FakeThumbnailPlatform extends FcNativeVideoThumbnailPlatform
    with MockPlatformInterfaceMixin {
  _FakeThumbnailPlatform(this.onSave);

  final Future<bool> Function(String destFile) onSave;
  final calls = <Map<String, Object?>>[];

  @override
  Future<bool> saveThumbnailToFile({
    required String srcFile,
    required String destFile,
    required int width,
    required int height,
    String? format,
    bool? srcFileUri,
    FcVideoThumbnailTime? at,
    int? quality,
  }) {
    calls.add({
      'srcFile': srcFile,
      'destFile': destFile,
      'width': width,
      'height': height,
      'format': format,
      'quality': quality,
      'at': at?.toMap(),
    });
    return onSave(destFile);
  }
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

Uint8List _jpeg(int width, int height) =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: width, height: height)));

/// Writes a [width]x[height] JPEG to the requested destination, like the
/// real plugin does on success.
Future<bool> Function(String) _writes(int width, int height) =>
    (dest) async {
      await File(dest).writeAsBytes(_jpeg(width, height));
      return true;
    };

void main() {
  late FcNativeVideoThumbnailPlatform originalThumbnailer;
  late PathProviderPlatform originalPathProvider;
  late Directory tmp;

  setUp(() {
    originalThumbnailer = FcNativeVideoThumbnailPlatform.instance;
    originalPathProvider = PathProviderPlatform.instance;
    tmp = Directory.systemTemp.createTempSync('thumbs_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() {
    FcNativeVideoThumbnailPlatform.instance = originalThumbnailer;
    PathProviderPlatform.instance = originalPathProvider;
    tmp.deleteSync(recursive: true);
  });

  group('generateThumbnails — video', () {
    final video = File('clip.mp4');

    test('extracts one JPEG frame into the temp dir, resizes, deletes it',
        () async {
      final fake = _FakeThumbnailPlatform(_writes(1920, 1080));
      FcNativeVideoThumbnailPlatform.instance = fake;

      final result = await generateThumbnails(video, mimeType: 'video/mp4');

      expect(img.decodeJpg(result!.thumb)!.width, 256);
      expect(img.decodeJpg(result.preview)!.width, 1024);
      final call = fake.calls.single;
      expect(call['srcFile'], video.path);
      expect(p(call['destFile']! as String), startsWith(p(tmp.path)));
      expect(call['width'], 1024);
      // Only the width limits the frame (see the portrait test).
      expect(call['height'], 4096);
      expect(call['format'], 'jpeg');
      expect(call['quality'], 85);
      // First frame, matching video_thumbnail's default.
      expect(call['at'], {'atUs': 0});
      expect(File(call['destFile']! as String).existsSync(), isFalse,
          reason: 'temp frame should be deleted');
    });

    test('portrait frames keep a 1024px-wide preview', () async {
      // What the plugin produces for a 1080x1920 clip fitted inside
      // 1024x4096: width-limited, aspect preserved.
      FcNativeVideoThumbnailPlatform.instance =
          _FakeThumbnailPlatform(_writes(1024, 1820));

      final result = await generateThumbnails(video, mimeType: 'video/mp4');

      final preview = img.decodeJpg(result!.preview)!;
      expect(preview.width, 1024);
      expect(preview.height, 1820);
    });

    test('returns null when the plugin creates no frame', () async {
      FcNativeVideoThumbnailPlatform.instance =
          _FakeThumbnailPlatform((_) async => false);

      expect(await generateThumbnails(video, mimeType: 'video/mp4'), isNull);
    });

    test('returns null when native decoding fails', () async {
      FcNativeVideoThumbnailPlatform.instance = _FakeThumbnailPlatform(
        (_) async => throw PlatformException(code: 'decode'),
      );

      expect(await generateThumbnails(video, mimeType: 'video/mp4'), isNull);
    });
  });

  test('non-media types return null without touching the plugin', () async {
    final fake = _FakeThumbnailPlatform(_writes(10, 10));
    FcNativeVideoThumbnailPlatform.instance = fake;

    expect(
      await generateThumbnails(File('a.pdf'), mimeType: 'application/pdf'),
      isNull,
    );
    expect(fake.calls, isEmpty);
  });
}

/// Normalises separators so the temp-dir prefix check works on Windows too.
String p(String path) => path.replaceAll(r'\', '/');
