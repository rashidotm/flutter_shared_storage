import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_storage_firebase/src/firestore_schema.dart';
import 'package:cloud_storage_firebase/src/name_resolver.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seeds a node record with the given parent + name so name-resolution
/// can detect the conflict.
Future<void> _seed(
  FakeFirebaseFirestore fs, {
  required String parentId,
  required String name,
}) async {
  await fs.collection('nodes').add({
    kFieldParentId: parentId,
    kFieldName: name,
    kFieldType: kTypeFile,
  });
}

void main() {
  late FakeFirebaseFirestore firestore;
  late CollectionReference<Map<String, dynamic>> nodes;
  late NameResolver resolver;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    nodes = firestore.collection('nodes');
    resolver = NameResolver(nodes);
  });

  test('returns the desired name verbatim when no conflict exists',
      () async {
    final resolved = await resolver.resolve(
      parentId: 'p1',
      desiredName: 'report.pdf',
    );
    expect(resolved, 'report.pdf');
  });

  test('appends " (1)" before the extension on first conflict',
      () async {
    await _seed(firestore, parentId: 'p1', name: 'report.pdf');
    final resolved = await resolver.resolve(
      parentId: 'p1',
      desiredName: 'report.pdf',
    );
    expect(resolved, 'report (1).pdf');
  });

  test('increments to (2) when (1) is also taken', () async {
    await _seed(firestore, parentId: 'p1', name: 'report.pdf');
    await _seed(firestore, parentId: 'p1', name: 'report (1).pdf');
    final resolved = await resolver.resolve(
      parentId: 'p1',
      desiredName: 'report.pdf',
    );
    expect(resolved, 'report (2).pdf');
  });

  test('handles names with no extension', () async {
    await _seed(firestore, parentId: 'p1', name: 'notes');
    final resolved = await resolver.resolve(
      parentId: 'p1',
      desiredName: 'notes',
    );
    expect(resolved, 'notes (1)');
  });

  test('scopes conflict detection to the given parentId', () async {
    // Same name in a different parent must NOT count as a conflict.
    await _seed(firestore, parentId: 'other-parent', name: 'report.pdf');
    final resolved = await resolver.resolve(
      parentId: 'p1',
      desiredName: 'report.pdf',
    );
    expect(resolved, 'report.pdf');
  });

  test('handles multi-dot extensions by preserving only the last', () async {
    // p.extension('archive.tar.gz') returns '.gz', so the numeric suffix
    // goes right before it: `archive.tar (1).gz`.
    await _seed(firestore, parentId: 'p1', name: 'archive.tar.gz');
    final resolved = await resolver.resolve(
      parentId: 'p1',
      desiredName: 'archive.tar.gz',
    );
    expect(resolved, 'archive.tar (1).gz');
  });
}
