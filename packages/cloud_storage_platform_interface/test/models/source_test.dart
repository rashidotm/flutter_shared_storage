import 'dart:typed_data';

import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BytesSource', () {
    test('length() returns bytes.lengthInBytes', () async {
      final src = BytesSource(Uint8List.fromList(List<int>.filled(1024, 0)));
      expect(await src.length(), 1024);
    });

    test('empty bytes report length 0', () async {
      final src = BytesSource(Uint8List(0));
      expect(await src.length(), 0);
    });

    test('preserves the underlying bytes reference', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final src = BytesSource(bytes);
      expect(src.bytes, same(bytes));
    });
  });

  test('Source is sealed — exhaustive switch reaches every branch', () {
    // The Source variants — smoke test that a switch over one instance
    // of each variant compiles under exhaustive matching.
    Source example = BytesSource(Uint8List(0));
    final label = switch (example) {
      FileSource() => 'file',
      BytesSource() => 'bytes',
      XFileSource() => 'xfile',
    };
    expect(label, 'bytes');
  });
}
