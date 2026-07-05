import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

/// The bytes to upload. Use one of the concrete subtypes:
/// [FileSource], [BytesSource], or [XFileSource].
sealed class Source {
  const Source();

  /// Total size in bytes if known up front. Used for progress reporting.
  Future<int?> length();
}

class FileSource extends Source {
  const FileSource(this.file);
  final File file;

  @override
  Future<int?> length() => file.length();
}

class BytesSource extends Source {
  const BytesSource(this.bytes);
  final Uint8List bytes;

  @override
  Future<int?> length() async => bytes.lengthInBytes;
}

class XFileSource extends Source {
  const XFileSource(this.xfile);
  final XFile xfile;

  @override
  Future<int?> length() => xfile.length();
}
