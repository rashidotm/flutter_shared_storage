import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixture factories ──────────────────────────────────────────────────

final _epoch = DateTime.utc(2026, 1, 1);

CloudFolder _folder(String name, {DateTime? at}) => CloudFolder(
      id: 'F-$name',
      name: name,
      parentId: '',
      path: '/$name',
      createdAt: at ?? _epoch,
      updatedAt: at ?? _epoch,
    );

CloudFile _file(String name, {int size = 0, DateTime? at}) => CloudFile(
      id: 'f-$name',
      name: name,
      parentId: '',
      path: '/$name',
      createdAt: at ?? _epoch,
      updatedAt: at ?? _epoch,
      mimeType: 'application/octet-stream',
      sizeBytes: size,
      storagePath: '/$name',
      downloadUrl: 'https://example.com/$name',
    );

CloudLink _link(String name, {DateTime? at}) => CloudLink(
      id: 'l-$name',
      name: name,
      parentId: '',
      path: '/$name',
      createdAt: at ?? _epoch,
      updatedAt: at ?? _epoch,
      url: 'https://example.com/$name',
    );

List<String> _names(List<CloudNode> nodes) =>
    nodes.map((n) => n.name).toList();

void main() {
  group('sortCloudNodes — name field', () {
    test('ascending is case-insensitive alphabetical', () {
      final sorted = sortCloudNodes(
        [_file('banana'), _file('Apple'), _file('cherry')],
        const CloudNodeSort(),
      );
      expect(_names(sorted), ['Apple', 'banana', 'cherry']);
    });

    test('descending reverses the order', () {
      final sorted = sortCloudNodes(
        [_file('a'), _file('b'), _file('c')],
        const CloudNodeSort(ascending: false),
      );
      expect(_names(sorted), ['c', 'b', 'a']);
    });
  });

  group('sortCloudNodes — foldersFirst', () {
    test('true (default) groups folders before files/links', () {
      final sorted = sortCloudNodes(
        [_file('a'), _folder('b'), _link('c'), _folder('a')],
        const CloudNodeSort(),
      );
      // Folders first ascending → 'a' (folder), 'b' (folder), then
      // links + files by name — 'a' (file), 'c' (link).
      expect(_names(sorted), ['a', 'b', 'a', 'c']);
    });

    test('false interleaves folders / files / links by the sort field', () {
      final sorted = sortCloudNodes(
        [_file('c'), _folder('a'), _link('b')],
        const CloudNodeSort(foldersFirst: false),
      );
      expect(_names(sorted), ['a', 'b', 'c']);
    });
  });

  group('sortCloudNodes — date fields', () {
    test('createdAt ascending is oldest-first', () {
      final oldA = _file('old', at: DateTime.utc(2020));
      final newB = _file('new', at: DateTime.utc(2026));
      final sorted = sortCloudNodes(
        [newB, oldA],
        const CloudNodeSort(field: CloudNodeSortField.createdAt),
      );
      expect(_names(sorted), ['old', 'new']);
    });

    test('createdAt descending is newest-first', () {
      final oldA = _file('old', at: DateTime.utc(2020));
      final newB = _file('new', at: DateTime.utc(2026));
      final sorted = sortCloudNodes(
        [oldA, newB],
        const CloudNodeSort(
          field: CloudNodeSortField.createdAt,
          ascending: false,
        ),
      );
      expect(_names(sorted), ['new', 'old']);
    });
  });

  group('sortCloudNodes — size field', () {
    test('files sort by sizeBytes; folders/links compare as 0', () {
      final sorted = sortCloudNodes(
        [
          _file('big', size: 1000),
          _file('small', size: 10),
          _folder('folder'),
          _link('link'),
        ],
        const CloudNodeSort(
          field: CloudNodeSortField.size,
          foldersFirst: false,
        ),
      );
      // Folder/link both have size 0, sorted by name tiebreak
      // ('folder' < 'link'), then the two files by size ascending.
      expect(_names(sorted), ['folder', 'link', 'small', 'big']);
    });
  });

  group('sortCloudNodes — type field', () {
    test('groups folders → links → files, tiebreak by name', () {
      final sorted = sortCloudNodes(
        [
          _file('zed-file'),
          _link('bee-link'),
          _folder('yak-folder'),
          _file('apple-file'),
        ],
        const CloudNodeSort(
          field: CloudNodeSortField.type,
          foldersFirst: false,
        ),
      );
      expect(_names(sorted), [
        'yak-folder',
        'bee-link',
        'apple-file',
        'zed-file',
      ]);
    });
  });

  group('sortCloudNodes — properties', () {
    test('does not mutate the input list', () {
      final original = [_file('c'), _file('a'), _file('b')];
      final beforeCopy = List.of(original);
      sortCloudNodes(original, const CloudNodeSort());
      expect(original, orderedEquals(beforeCopy));
    });

    test('is stable — ties break by name deterministically', () {
      // Three files with identical sizes → tiebreak by name ascending.
      final sorted = sortCloudNodes(
        [
          _file('c', size: 100),
          _file('a', size: 100),
          _file('b', size: 100),
        ],
        const CloudNodeSort(field: CloudNodeSortField.size),
      );
      expect(_names(sorted), ['a', 'b', 'c']);
    });

    test('empty input returns empty output', () {
      expect(sortCloudNodes([], const CloudNodeSort()), isEmpty);
    });
  });

  group('CloudNodeSort value semantics', () {
    test('== and hashCode use all three fields', () {
      const a = CloudNodeSort();
      const b = CloudNodeSort();
      const c = CloudNodeSort(ascending: false);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('copyWith overrides only the specified fields', () {
      const base = CloudNodeSort();
      final copy = base.copyWith(ascending: false);
      expect(copy.field, base.field);
      expect(copy.ascending, isFalse);
      expect(copy.foldersFirst, base.foldersFirst);
    });
  });
}
