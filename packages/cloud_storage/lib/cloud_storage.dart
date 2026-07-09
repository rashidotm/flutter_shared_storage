/// Cloud file/folder storage for Flutter.
///
/// Umbrella package: re-exports the platform interface plus the default
/// Firebase implementation, and provides a [defaultCloudStorage] factory.
library;

// `cloud_storage_firebase` already re-exports the platform interface, so
// importing it here directly would be redundant. We still re-export it
// explicitly so the umbrella's public surface doesn't depend on the impl
// continuing to forward it.
import 'package:cloud_storage_firebase/cloud_storage_firebase.dart';

export 'package:cloud_storage_firebase/cloud_storage_firebase.dart';
export 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';

/// Convenience factory for the default backend (Firebase).
///
/// Both [firestorePath] and [storagePath] are required — the package makes
/// no assumption about where your data lives. See [FirebaseCloudStorage]
/// for the path contract.
CloudStorage defaultCloudStorage({
  required String firestorePath,
  required String storagePath,
}) => FirebaseCloudStorage(
      firestorePath: firestorePath,
      storagePath: storagePath,
    );
