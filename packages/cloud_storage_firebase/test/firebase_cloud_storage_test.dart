import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_storage_firebase/cloud_storage_firebase.dart';
import 'package:cloud_storage_firebase/src/firestore_schema.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as fcm;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Cache manager stub. Mocktail returns null for anything we don't
/// explicitly stub — good enough since [FirebaseCloudStorage] wraps
/// every cache-manager call in a fire-and-forget or `.catchError`.
class _MockCache extends Mock implements fcm.BaseCacheManager {}

FirebaseCloudStorage _newStorage(
  FakeFirebaseFirestore firestore,
  MockFirebaseStorage storage,
  fcm.BaseCacheManager cache,
) =>
    FirebaseCloudStorage(
      firestorePath: 'nodes',
      storagePath: 'blobs',
      firestore: firestore,
      storage: storage,
      cacheManager: cache,
    );

/// Directly seeds a node document — bypasses the public API so tests
/// can set up preconditions without side effects.
Future<String> _seedNode(
  FakeFirebaseFirestore fs, {
  required String type,
  required String name,
  String parentId = '',
  String path = '',
  Map<String, dynamic> extra = const {},
}) async {
  final doc = fs.collection('nodes').doc();
  await doc.set({
    kFieldType: type,
    kFieldName: name,
    kFieldParentId: parentId,
    kFieldPath: path.isEmpty ? '/$name' : path,
    kFieldCreatedAt: FieldValue.serverTimestamp(),
    kFieldUpdatedAt: FieldValue.serverTimestamp(),
    ...extra,
  });
  return doc.id;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;
  late _MockCache cache;
  late FirebaseCloudStorage cs;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
    cache = _MockCache();
    when(() => cache.removeFile(any())).thenAnswer((_) async {});
    cs = _newStorage(firestore, storage, cache);
  });

  // ── Constructor path validation ─────────────────────────────────────

  group('constructor validation', () {
    test('rejects empty firestorePath', () {
      expect(
        () => FirebaseCloudStorage(
          firestorePath: '   ',
          storagePath: 'blobs',
          firestore: firestore,
          storage: storage,
          cacheManager: cache,
        ),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('rejects storagePath with leading slash', () {
      expect(
        () => FirebaseCloudStorage(
          firestorePath: 'nodes',
          storagePath: '/blobs',
          firestore: firestore,
          storage: storage,
          cacheManager: cache,
        ),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('rejects storagePath with consecutive slashes', () {
      expect(
        () => FirebaseCloudStorage(
          firestorePath: 'nodes',
          storagePath: 'blobs//files',
          firestore: firestore,
          storage: storage,
          cacheManager: cache,
        ),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('trims whitespace from valid paths', () async {
      final ok = FirebaseCloudStorage(
        firestorePath: '  nodes  ',
        storagePath: '  blobs  ',
        firestore: firestore,
        storage: storage,
        cacheManager: cache,
      );
      final folder = await ok.createFolder(
        parentId: kRootFolderId,
        name: 'Trim',
      );
      expect(folder.name, 'Trim');
    });
  });

  // ── Folders ─────────────────────────────────────────────────────────

  group('createFolder', () {
    test('creates a folder at root with path /name', () async {
      final folder = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Photos',
      );
      expect(folder.name, 'Photos');
      expect(folder.parentId, '');
      expect(folder.path, '/Photos');
      // Firestore has the doc.
      final doc = await firestore.collection('nodes').doc(folder.id).get();
      expect(doc.data()![kFieldType], kTypeFolder);
    });

    test('nested folder gets the parent path prepended', () async {
      final parent = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Photos',
      );
      final child = await cs.createFolder(
        parentId: parent.id,
        name: '2026',
      );
      expect(child.path, '/Photos/2026');
    });

    test('auto-renames on sibling name conflict', () async {
      await cs.createFolder(parentId: kRootFolderId, name: 'Photos');
      final second =
          await cs.createFolder(parentId: kRootFolderId, name: 'Photos');
      expect(second.name, 'Photos (1)');
    });
  });

  group('renameFolder', () {
    test('updates the name on the folder document', () async {
      final folder = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Old',
      );
      await cs.renameFolder(folder.id, 'New');
      final fetched = await cs.getNode(folder.id);
      expect(fetched.name, 'New');
    });

    test('rewrites descendant paths', () async {
      final parent = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Old',
      );
      final child = await cs.createFolder(
        parentId: parent.id,
        name: 'Inner',
      );
      await cs.renameFolder(parent.id, 'Renamed');
      final childAfter = await cs.getNode(child.id);
      expect(childAfter.path, '/Renamed/Inner');
    });
  });

  group('deleteFolder', () {
    test('deletes an empty folder', () async {
      final folder = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Empty',
      );
      await cs.deleteFolder(folder.id);
      expect(
        () => cs.getNode(folder.id),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('rejects non-empty folder unless recursive is true', () async {
      final parent = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Parent',
      );
      await cs.createFolder(parentId: parent.id, name: 'Child');
      expect(
        () => cs.deleteFolder(parent.id),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('recursively deletes children when recursive: true', () async {
      final parent = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Parent',
      );
      final child = await cs.createFolder(
        parentId: parent.id,
        name: 'Child',
      );
      await cs.createLink(
        parentId: parent.id,
        name: 'Bookmark',
        url: 'https://example.com',
      );
      await cs.deleteFolder(parent.id, recursive: true);
      expect(
        () => cs.getNode(parent.id),
        throwsA(isA<NotFoundException>()),
      );
      expect(
        () => cs.getNode(child.id),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('moveFolder', () {
    test('updates parentId and path', () async {
      final src = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Src',
      );
      final dest = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Dest',
      );
      await cs.moveFolder(src.id, newParentId: dest.id);
      final after = await cs.getNode(src.id);
      expect(after.parentId, dest.id);
      expect(after.path, '/Dest/Src');
    });

    test('rewrites descendant paths recursively', () async {
      final src = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Src',
      );
      final child = await cs.createFolder(
        parentId: src.id,
        name: 'Inner',
      );
      final dest = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Dest',
      );
      await cs.moveFolder(src.id, newParentId: dest.id);
      final childAfter = await cs.getNode(child.id);
      expect(childAfter.path, '/Dest/Src/Inner');
    });
  });

  // ── Links ───────────────────────────────────────────────────────────

  group('createLink', () {
    test('creates a link document with the given URL', () async {
      final link = await cs.createLink(
        parentId: kRootFolderId,
        name: 'Docs',
        url: 'https://example.com',
      );
      expect(link.name, 'Docs');
      expect(link.url, 'https://example.com');
      expect(link.path, '/Docs');
    });

    test('auto-renames link on name conflict', () async {
      await cs.createLink(
        parentId: kRootFolderId,
        name: 'Docs',
        url: 'https://a',
      );
      final second = await cs.createLink(
        parentId: kRootFolderId,
        name: 'Docs',
        url: 'https://b',
      );
      expect(second.name, 'Docs (1)');
    });
  });

  group('updateLinkUrl', () {
    test('replaces the URL field', () async {
      final link = await cs.createLink(
        parentId: kRootFolderId,
        name: 'Docs',
        url: 'https://old',
      );
      await cs.updateLinkUrl(link.id, 'https://new');
      final after = await cs.getNode(link.id) as CloudLink;
      expect(after.url, 'https://new');
    });
  });

  group('renameLink / moveLink / deleteLink', () {
    test('renameLink updates the name', () async {
      final link = await cs.createLink(
        parentId: kRootFolderId,
        name: 'Old',
        url: 'https://x',
      );
      await cs.renameLink(link.id, 'New');
      expect((await cs.getNode(link.id)).name, 'New');
    });

    test('moveLink updates parentId and path', () async {
      final link = await cs.createLink(
        parentId: kRootFolderId,
        name: 'Bookmark',
        url: 'https://x',
      );
      final dest = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Dest',
      );
      await cs.moveLink(link.id, newParentId: dest.id);
      final after = await cs.getNode(link.id);
      expect(after.parentId, dest.id);
      expect(after.path, '/Dest/Bookmark');
    });

    test('deleteLink removes the doc', () async {
      final link = await cs.createLink(
        parentId: kRootFolderId,
        name: 'X',
        url: 'https://x',
      );
      await cs.deleteLink(link.id);
      expect(
        () => cs.getNode(link.id),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  // ── Files (mutations that don't need real bytes) ────────────────────

  group('renameFile / moveFile', () {
    test('renameFile updates the name', () async {
      final fileId = await _seedNode(
        firestore,
        type: kTypeFile,
        name: 'old.pdf',
        path: '/old.pdf',
        extra: {kFieldMimeType: 'application/pdf'},
      );
      await cs.renameFile(fileId, 'new.pdf');
      expect((await cs.getNode(fileId)).name, 'new.pdf');
    });

    test('moveFile updates parentId and path', () async {
      final fileId = await _seedNode(
        firestore,
        type: kTypeFile,
        name: 'report.pdf',
        path: '/report.pdf',
        extra: {kFieldMimeType: 'application/pdf'},
      );
      final dest = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'Docs',
      );
      await cs.moveFile(fileId, newParentId: dest.id);
      final after = await cs.getNode(fileId);
      expect(after.parentId, dest.id);
      expect(after.path, '/Docs/report.pdf');
    });
  });

  group('deleteFile', () {
    test('removes the Firestore doc and drops cache entry', () async {
      final fileId = await _seedNode(
        firestore,
        type: kTypeFile,
        name: 'gone.pdf',
        extra: {
          kFieldMimeType: 'application/pdf',
          kFieldStoragePath: 'blobs/gone.pdf',
        },
      );
      await cs.deleteFile(fileId);
      expect(
        () => cs.getNode(fileId),
        throwsA(isA<NotFoundException>()),
      );
      verify(() => cache.removeFile(fileId)).called(1);
    });

    test('throws InvalidArgumentException when node is a folder', () async {
      final folder = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'x',
      );
      expect(
        () => cs.deleteFile(folder.id),
        throwsA(isA<InvalidArgumentException>()),
      );
    });
  });

  // ── Reads ───────────────────────────────────────────────────────────

  group('getNode / listFolder / watchFolder', () {
    test('getNode returns the node for a valid id', () async {
      final folder = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'X',
      );
      expect((await cs.getNode(folder.id)).name, 'X');
    });

    test('getNode throws NotFoundException for a missing id', () async {
      expect(
        () => cs.getNode('never-existed'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('listFolder returns direct children only', () async {
      final a = await cs.createFolder(parentId: kRootFolderId, name: 'A');
      await cs.createFolder(parentId: kRootFolderId, name: 'B');
      await cs.createFolder(parentId: a.id, name: 'A-child');
      final rootKids = await cs.listFolder(kRootFolderId);
      expect(rootKids.map((n) => n.name).toList()..sort(), ['A', 'B']);
    });

    test('watchFolder emits updates as children change', () async {
      final events = <List<String>>[];
      final sub = cs.watchFolder(kRootFolderId).listen(
            (nodes) => events.add(nodes.map((n) => n.name).toList()..sort()),
          );
      await cs.createFolder(parentId: kRootFolderId, name: 'First');
      await Future<void>.delayed(Duration.zero);
      await cs.createFolder(parentId: kRootFolderId, name: 'Second');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      // Should include at least the [First] and [First, Second]
      // snapshots — wrapped in `orderedEquals` because Dart lists
      // compare by identity, not structure.
      expect(events, contains(orderedEquals(['First'])));
      expect(events, contains(orderedEquals(['First', 'Second'])));
    });
  });

  // ── setThumbnail ────────────────────────────────────────────────────

  group('setThumbnail', () {
    test('rejects folders', () async {
      final folder = await cs.createFolder(
        parentId: kRootFolderId,
        name: 'x',
      );
      expect(
        () => cs.setThumbnail(
          folder.id,
          thumbnail: BytesSource(Uint8List.fromList([1, 2, 3])),
        ),
        throwsA(isA<InvalidArgumentException>()),
      );
    });
  });

  // Note on upload / download / setThumbnail(non-folder) coverage:
  // firebase_storage_mocks 0.8.1's MockTaskSnapshot doesn't implement
  // `bytesTransferred` / `totalBytes` / etc., which our
  // FirebaseUploadTask reads on every snapshot event. A full end-to-end
  // upload test would require a hand-rolled FirebaseStorage double
  // implementing the entire snapshotEvents lifecycle — a big investment
  // for narrow return. The 29 CRUD tests above cover the code paths
  // that don't touch Storage; upload / download flows are validated by
  // the example app in real integration use.
}
