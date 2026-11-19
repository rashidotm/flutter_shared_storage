import 'dart:io';

import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException, Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Stand-in for the native plugin. [onBytes] decides what
/// `saveThumbnailToBytes` does so each test can model success, "no frame"
/// (`null`) and a native failure (throw).
class _FakeThumbnailPlatform extends FcNativeVideoThumbnailPlatform
    with MockPlatformInterfaceMixin {
  _FakeThumbnailPlatform(this.onBytes);

  final Future<Uint8List?> Function() onBytes;
  final calls = <Map<String, Object?>>[];

  @override
  Future<Uint8List?> saveThumbnailToBytes({
    required String srcFile,
    required int width,
    required int height,
    String? format,
    bool? srcFileUri,
    FcVideoThumbnailTime? at,
    int? quality,
  }) {
    calls.add({
      'srcFile': srcFile,
      'width': width,
      'height': height,
      'quality': quality,
      'at': at?.toMap(),
    });
    return onBytes();
  }
}

Uint8List _jpeg(int width, int height) =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: width, height: height)));

void main() {
  late FcNativeVideoThumbnailPlatform original;

  setUp(() => original = FcNativeVideoThumbnailPlatform.instance);
  tearDown(() => FcNativeVideoThumbnailPlatform.instance = original);

  group('generateThumbnails — video', () {
    final video = File('does-not-need-to-exist.mp4');

    test('resizes the native frame to 256w thumb and 1024w preview', () async {
      final fake = _FakeThumbnailPlatform(() async => _jpeg(1920, 1080));
      FcNativeVideoThumbnailPlatform.instance = fake;

      final result = await generateThumbnails(video, mimeType: 'video/mp4');

      expect(result, isNotNull);
      expect(img.decodeJpg(result!.thumb)!.width, 256);
      expect(img.decodeJpg(result.preview)!.width, 1024);
      expect(fake.calls.single, {
        'srcFile': video.path,
        'width': 1024,
        // Only the width may limit the frame (see portrait test below).
        'height': 4096,
        'quality': 85,
        // First frame, matching the old video_thumbnail default.
        'at': {'atUs': 0},
      });
    });

    test('returns null when the plugin has no frame', () async {
      FcNativeVideoThumbnailPlatform.instance = _FakeThumbnailPlatform(
        () async => null,
      );

      expect(await generateThumbnails(video, mimeType: 'video/mp4'), isNull);
    });

    test('returns null (does not throw) when native decoding fails', () async {
      FcNativeVideoThumbnailPlatform.instance = _FakeThumbnailPlatform(
        () async => throw PlatformException(code: 'decode', message: 'boom'),
      );

      expect(await generateThumbnails(video, mimeType: 'video/mp4'), isNull);
    });

    test('lets setup errors (missing plugin) propagate', () async {
      FcNativeVideoThumbnailPlatform.instance = _FakeThumbnailPlatform(
        () async => throw MissingPluginException('not registered'),
      );

      await expectLater(
        generateThumbnails(video, mimeType: 'video/mp4'),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('portrait frames keep a 1024px-wide preview', () async {
      // What the plugin returns for a 1080x1920 clip fitted inside
      // 1024x4096: width-limited, aspect preserved.
      FcNativeVideoThumbnailPlatform.instance = _FakeThumbnailPlatform(
        () async => _jpeg(1024, 1820),
      );

      final result = await generateThumbnails(video, mimeType: 'video/mp4');

      final preview = img.decodeJpg(result!.preview)!;
      expect(preview.width, 1024);
      expect(preview.height, 1820);
      expect(img.decodeJpg(result.thumb)!.width, 256);
    });

    test('infers the video MIME type from the file extension', () async {
      final fake = _FakeThumbnailPlatform(() async => _jpeg(640, 360));
      FcNativeVideoThumbnailPlatform.instance = fake;

      final result = await generateThumbnails(video);

      expect(fake.calls, hasLength(1));
      // Thumb is downscaled to 256; the preview target (1024) is wider
      // than the frame, so it is kept as-is rather than upscaled.
      expect(img.decodeJpg(result!.thumb)!.width, 256);
      expect(img.decodeJpg(result.preview)!.width, 640);
    });
  });

  test(
    'returns null for non-media types without touching the plugin',
    () async {
      final fake = _FakeThumbnailPlatform(() async => _jpeg(10, 10));
      FcNativeVideoThumbnailPlatform.instance = fake;

      final result = await generateThumbnails(
        File('report.pdf'),
        mimeType: 'application/pdf',
      );

      expect(result, isNull);
      expect(fake.calls, isEmpty);
    },
  );
}
