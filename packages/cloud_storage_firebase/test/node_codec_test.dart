import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_storage_firebase/src/firestore_schema.dart';
import 'package:cloud_storage_firebase/src/node_codec.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writes [data] to a fake Firestore under `nodes/{id}` and returns the
/// resulting document snapshot ready to be passed to [nodeFromSnapshot].
Future<DocumentSnapshot<Map<String, dynamic>>> _seed(
  FakeFirebaseFirestore firestore,
  String id,
  Map<String, dynamic> data,
) async {
  final ref = firestore.collection('nodes').doc(id);
  await ref.set(data);
  return ref.get();
}

void main() {
  final t0 = Timestamp.fromDate(DateTime.utc(2026, 1, 2, 3, 4, 5));
  final t1 = Timestamp.fromDate(DateTime.utc(2026, 6, 7, 8, 9, 10));

  group('nodeFromSnapshot — folders', () {
    test('decodes a folder document with all fields populated', () async {
      final fs = FakeFirebaseFirestore();
      final snap = await _seed(fs, 'folder-1', {
        kFieldType: kTypeFolder,
        kFieldName: 'Photos',
        kFieldParentId: '',
        kFieldPath: '/photos',
        kFieldCreatedAt: t0,
        kFieldUpdatedAt: t1,
      });
      final node = nodeFromSnapshot(snap);
      expect(node, isA<CloudFolder>());
      expect(node.id, 'folder-1');
      expect(node.name, 'Photos');
      expect(node.parentId, '');
      expect(node.path, '/photos');
      expect(node.createdAt, t0.toDate());
      expect(node.updatedAt, t1.toDate());
    });

    test('updatedAt falls back to createdAt when missing', () async {
      final fs = FakeFirebaseFirestore();
      final snap = await _seed(fs, 'folder-2', {
        kFieldType: kTypeFolder,
        kFieldName: 'X',
        kFieldCreatedAt: t0,
      });
      final node = nodeFromSnapshot(snap);
      expect(node.updatedAt, t0.toDate());
    });
  });

  group('nodeFromSnapshot — files', () {
    test('decodes a file document with all fields populated', () async {
      final fs = FakeFirebaseFirestore();
      final snap = await _seed(fs, 'file-1', {
        kFieldType: kTypeFile,
        kFieldName: 'photo.jpg',
        kFieldParentId: 'folder-1',
        kFieldPath: '/photos/photo.jpg',
        kFieldCreatedAt: t0,
        kFieldUpdatedAt: t1,
        kFieldMimeType: 'image/jpeg',
        kFieldSizeBytes: 12345,
        kFieldStoragePath: 'root/file-1.jpg',
        kFieldDownloadUrl: 'https://example.com/file-1.jpg',
        kFieldThumbnailUrl: 'https://example.com/file-1_thumb.jpg',
        kFieldPreviewUrl: 'https://example.com/file-1_preview.jpg',
      });
      final node = nodeFromSnapshot(snap);
      expect(node, isA<CloudFile>());
      final f = node as CloudFile;
      expect(f.mimeType, 'image/jpeg');
      expect(f.sizeBytes, 12345);
      expect(f.storagePath, 'root/file-1.jpg');
      expect(f.downloadUrl, 'https://example.com/file-1.jpg');
      expect(f.thumbnailUrl, 'https://example.com/file-1_thumb.jpg');
      expect(f.previewUrl, 'https://example.com/file-1_preview.jpg');
    });

    test('sizeBytes coerces from num (e.g. Firestore returns a double)',
        () async {
      final fs = FakeFirebaseFirestore();
      final snap = await _seed(fs, 'file-2', {
        kFieldType: kTypeFile,
        kFieldSizeBytes: 42.0,
      });
      expect((nodeFromSnapshot(snap) as CloudFile).sizeBytes, 42);
    });

    test('defaults to file type when type field is missing', () async {
      final fs = FakeFirebaseFirestore();
      final snap = await _seed(fs, 'file-3', {
        kFieldName: 'orphan',
      });
      expect(nodeFromSnapshot(snap), isA<CloudFile>());
    });

    test(
      'mimeType defaults to application/octet-stream when missing',
      () async {
        final fs = FakeFirebaseFirestore();
        final snap = await _seed(fs, 'file-4', {
          kFieldType: kTypeFile,
        });
        expect(
          (nodeFromSnapshot(snap) as CloudFile).mimeType,
          'application/octet-stream',
        );
      },
    );

    test('optional thumbnail / preview URLs decode to null when missing',
        () async {
      final fs = FakeFirebaseFirestore();
      final snap = await _seed(fs, 'file-5', {
        kFieldType: kTypeFile,
        kFieldMimeType: 'image/png',
      });
      final f = nodeFromSnapshot(snap) as CloudFile;
      expect(f.thumbnailUrl, isNull);
      expect(f.previewUrl, isNull);
    });
  });

  group('nodeFromSnapshot — links', () {
    test('decodes a link document', () async {
      final fs = FakeFirebaseFirestore();
      final snap = await _seed(fs, 'link-1', {
        kFieldType: kTypeLink,
        kFieldName: 'Docs',
        kFieldParentId: 'folder-1',
        kFieldPath: '/photos/Docs',
        kFieldCreatedAt: t0,
        kFieldUrl: 'https://example.com',
        kFieldThumbnailUrl: 'https://example.com/logo.png',
      });
      final node = nodeFromSnapshot(snap);
      expect(node, isA<CloudLink>());
      final l = node as CloudLink;
      expect(l.url, 'https://example.com');
      expect(l.thumbnailUrl, 'https://example.com/logo.png');
      expect(l.previewUrl, isNull);
    });
  });

  test('nodeFromSnapshot throws NotFoundException when the doc is missing',
      () async {
    final fs = FakeFirebaseFirestore();
    final missing = await fs.collection('nodes').doc('never-existed').get();
    expect(
      () => nodeFromSnapshot(missing),
      throwsA(isA<NotFoundException>()),
    );
  });
}
