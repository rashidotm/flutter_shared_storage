import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Two JPEG variants produced from a source media file.
class MediaThumbnails {
  const MediaThumbnails({required this.thumb, required this.preview});

  /// ~256px wide JPEG. Suitable for grid tiles.
  final Uint8List thumb;

  /// ~1024px wide JPEG. Suitable for full-screen previews.
  final Uint8List preview;
}

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
  // video_thumbnail extracts a single frame; we then resize with `image`
  // to get consistent widths across images and videos.
  final tmpDir = await getTemporaryDirectory();
  final framePath = p.join(
    tmpDir.path,
    'thumb-${p.basenameWithoutExtension(file.path)}.jpg',
  );
  final resultPath = await VideoThumbnail.thumbnailFile(
    video: file.path,
    thumbnailPath: framePath,
    imageFormat: ImageFormat.JPEG,
    maxWidth: 1024,
    quality: 85,
  );
  if (resultPath == null) return null;
  final frameBytes = await File(resultPath).readAsBytes();
  try {
    await File(resultPath).delete();
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
