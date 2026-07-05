sealed class CloudStorageException implements Exception {
  const CloudStorageException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NotFoundException extends CloudStorageException {
  const NotFoundException(super.message);
}

class UnauthenticatedException extends CloudStorageException {
  const UnauthenticatedException(super.message);
}

class PermissionDeniedException extends CloudStorageException {
  const PermissionDeniedException(super.message);
}

class InvalidArgumentException extends CloudStorageException {
  const InvalidArgumentException(super.message);
}

class UploadFailedException extends CloudStorageException {
  const UploadFailedException(super.message, {this.cause});
  final Object? cause;
}

class DownloadFailedException extends CloudStorageException {
  const DownloadFailedException(super.message, {this.cause});
  final Object? cause;
}
