import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:test/test.dart';

void main() {
  test('all exceptions extend CloudStorageException (sealed hierarchy)', () {
    final exceptions = <CloudStorageException>[
      const NotFoundException('a'),
      const UnauthenticatedException('b'),
      const PermissionDeniedException('c'),
      const InvalidArgumentException('d'),
      const UploadFailedException('e'),
      const DownloadFailedException('f'),
    ];
    for (final e in exceptions) {
      expect(e, isA<CloudStorageException>());
      expect(e, isA<Exception>());
    }
  });

  test('message is preserved on all variants', () {
    expect(const NotFoundException('missing').message, 'missing');
    expect(const UploadFailedException('bad').message, 'bad');
  });

  test('toString() includes runtimeType and message', () {
    expect(
      const NotFoundException('missing').toString(),
      'NotFoundException: missing',
    );
    expect(
      const PermissionDeniedException('nope').toString(),
      'PermissionDeniedException: nope',
    );
  });

  test('UploadFailedException.cause is preserved when supplied', () {
    final cause = FormatException('bad byte');
    final e = UploadFailedException('wrapping', cause: cause);
    expect(e.cause, same(cause));
  });

  test('DownloadFailedException.cause defaults to null', () {
    expect(const DownloadFailedException('x').cause, isNull);
  });
}
