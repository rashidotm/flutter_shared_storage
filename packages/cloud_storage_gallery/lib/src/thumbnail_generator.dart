import 'dart:io';
import 'dart:typed_data';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
// FcVideoThumbnailTime isn't re-exported by the main library.
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart'
    show FcVideoThumbnailTime, FcVideoThumbnailTimeUnit;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';

/// Two JPEG variants produced from a source media file.
class MediaThumbnails {
  const MediaThumbnails({required this.thumb, required this.preview});

  /// ~256px wide JPEG. Suitable for grid tiles.
  final Uint8List thumb;

  /// ~1024px wide JPEG. Suitable for full-screen previews.
  final Uint8List preview;
}

final _videoThumbnailer = FcNativeVideoThumbnail();

/// Height bound passed to the native thumbnailer. Large enough that only
/// the 1024px width constraint applies for any realistic aspect ratio
/// (up to ~1:4).
const _maxFrameHeight = 4096;

/// Generates a thumb (256w) and preview (1024w) JPEG for [file] if the
/// MIME type is a supported image or video. Returns `null` for unsupported
/// types (PDFs, docs, etc.) — pass those to `upload()` without variants.
Future<MediaThumbnails?> generateThumbnails(
  File file, {
  String? mimeType,
}) async {
  final mime = mimeType ?? lookupMimeType(file.path) ?? '';
  if (mime.startsWith('image/')) {
    return _fromImageBytes(await file.readAsBytes());
  }
  if (mime.startsWith('video/')) {
    return _fromVideoFile(file);
  }
  return null;
}

Future<MediaThumbnails?> _fromImageBytes(Uint8List bytes) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  // `bakeOrientation` honors EXIF rotation so thumbnails aren't sideways.
  final oriented = img.bakeOrientation(decoded);
  return MediaThumbnails(
    thumb: Uint8List.fromList(
      img.encodeJpg(_resizeToWidth(oriented, 256), quality: 75),
    ),
    preview: Uint8List.fromList(
      img.encodeJpg(_resizeToWidth(oriented, 1024), quality: 80),
    ),
  );
}

Future<MediaThumbnails?> _fromVideoFile(File file) async {
  // fc_native_video_thumbnail extracts a single frame with the platform's
  // native decoder (MediaMetadataRetriever / AVFoundation / ...). We then
  // resize with `image` to get consistent widths across images and videos.
  //
  // Unlike the old `video_thumbnail`, the plugin reports a native decode
  // failure as a PlatformException instead of returning null. Map that to
  // null so callers keep the documented contract: `null` means "no
  // variants, upload the original as-is". Anything else (e.g. a
  // MissingPluginException when the plugin isn't registered) is a setup
  // bug and is left to propagate rather than silently dropping thumbnails.
  final Uint8List? frameBytes;
  try {
    frameBytes = await _videoThumbnailer.saveThumbnailToBytes(
      srcFile: file.path,
      // The plugin fits the frame inside width x height, preserving aspect
      // ratio, and never upscales. Only the width should limit it (like
      // video_thumbnail's maxWidth), so give height plenty of room:
      // a 1080x1920 portrait clip must come back 1024 wide, not 576.
      width: 1024,
      height: _maxFrameHeight,
      quality: 85,
      // Explicitly the first frame, like video_thumbnail's default
      // (timeMs: 0). Without `at`, Android asks MediaMetadataRetriever
      // for an arbitrary "representative" frame.
      at: FcVideoThumbnailTime(0, FcVideoThumbnailTimeUnit.microseconds),
    );
  } on PlatformException catch (e) {
    debugPrint(
      'cloud_storage_gallery: no video thumbnail for '
      '${file.path}: ${e.code} ${e.message}',
    );
    return null;
  }
  if (frameBytes == null) return null;
  final decoded = img.decodeImage(frameBytes);
  if (decoded == null) return null;
  return MediaThumbnails(
    thumb: Uint8List.fromList(
      img.encodeJpg(_resizeToWidth(decoded, 256), quality: 75),
    ),
    preview: Uint8List.fromList(
      img.encodeJpg(_resizeToWidth(decoded, 1024), quality: 80),
    ),
  );
}

img.Image _resizeToWidth(img.Image src, int width) {
  if (src.width <= width) return src;
  return img.copyResize(src, width: width);
}
