import 'dart:io';
import 'dart:typed_data';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
// FcVideoThumbnailTime isn't re-exported by the main library.
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart'
    show FcVideoThumbnailTime, FcVideoThumbnailTimeUnit;
import 'package:flutter/services.dart' show PlatformException;
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
/// the 1024px width constraint applies for any realistic aspect ratio.
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
  // native decoder; we then resize with `image` to get consistent widths
  // across images and videos.
  final tmpDir = await getTemporaryDirectory();
  final framePath = p.join(
    tmpDir.path,
    'thumb-${p.basenameWithoutExtension(file.path)}.jpg',
  );
  final bool created;
  try {
    created = await _videoThumbnailer.saveThumbnailToFile(
      srcFile: file.path,
      destFile: framePath,
      // The plugin fits the frame inside width x height (aspect preserved,
      // never upscaled). Only the width should limit it, as with
      // video_thumbnail's `maxWidth: 1024`, so give the height plenty of
      // room: a 1080x1920 portrait clip must come back 1024 wide, not 576.
      width: 1024,
      height: _maxFrameHeight,
      format: 'jpeg',
      quality: 85,
      // The first frame, like video_thumbnail's default (timeMs: 0).
      // Without `at`, Android asks MediaMetadataRetriever for an
      // arbitrary "representative" frame.
      at: FcVideoThumbnailTime(0, FcVideoThumbnailTimeUnit.microseconds),
    );
  } on PlatformException {
    // Native decode failure. video_thumbnail returned null here; keep
    // that contract ("no variants, upload the original as-is").
    return null;
  }
  if (!created) return null;
  final frame = File(framePath);
  final frameBytes = await frame.readAsBytes();
  try {
    await frame.delete();
  } catch (_) {
    // ignored — leaking a tempfile is fine
  }
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
