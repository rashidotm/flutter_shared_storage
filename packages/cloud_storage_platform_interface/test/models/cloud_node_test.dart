import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  group('CloudFolder', () {
    final folder = CloudFolder(
      id: 'f1',
      name: 'Photos',
      parentId: '',
      path: '/photos',
      createdAt: now,
      updatedAt: now,
    );

    test('isFolder is true; isFile / isLink are false', () {
      expect(folder.isFolder, isTrue);
      expect(folder.isFile, isFalse);
      expect(folder.isLink, isFalse);
    });

    test('type narrowing via sealed switch reaches the folder branch', () {
      final label = switch (folder as CloudNode) {
        CloudFolder() => 'folder',
        CloudFile() => 'file',
        CloudLink() => 'link',
      };
      expect(label, 'folder');
    });
  });

  group('CloudFile', () {
    CloudFile fileOf(String mime) => CloudFile(
          id: 'x',
          name: 'x',
          parentId: '',
          path: '/x',
          createdAt: now,
          updatedAt: now,
          mimeType: mime,
          sizeBytes: 100,
          storagePath: '/x',
          downloadUrl: 'https://example.com/x',
        );

    test('isFile is true; isFolder / isLink are false', () {
      final f = fileOf('application/pdf');
      expect(f.isFile, isTrue);
      expect(f.isFolder, isFalse);
      expect(f.isLink, isFalse);
    });

    test('isImage / isMedia when mime starts with image/', () {
      final f = fileOf('image/jpeg');
      expect(f.isImage, isTrue);
      expect(f.isVideo, isFalse);
      expect(f.isMedia, isTrue);
    });

    test('isVideo / isMedia when mime starts with video/', () {
      final f = fileOf('video/mp4');
      expect(f.isImage, isFalse);
      expect(f.isVideo, isTrue);
      expect(f.isMedia, isTrue);
    });

    test('isMedia false for non-media mime types', () {
      expect(fileOf('application/pdf').isMedia, isFalse);
      expect(fileOf('text/plain').isMedia, isFalse);
      expect(fileOf('audio/mpeg').isMedia, isFalse);
    });

    test('thumbnail / preview URLs are optional and default to null', () {
      final f = fileOf('image/jpeg');
      expect(f.thumbnailUrl, isNull);
      expect(f.previewUrl, isNull);
    });
  });

  group('CloudLink', () {
    final link = CloudLink(
      id: 'l1',
      name: 'Docs',
      parentId: '',
      path: '/docs',
      createdAt: now,
      updatedAt: now,
      url: 'https://example.com',
    );

    test('isLink is true; isFile / isFolder are false', () {
      expect(link.isLink, isTrue);
      expect(link.isFile, isFalse);
      expect(link.isFolder, isFalse);
    });

    test('url is preserved verbatim', () {
      expect(link.url, 'https://example.com');
    });
  });

  test('kRootFolderId is the empty string sentinel', () {
    expect(kRootFolderId, '');
  });
}
