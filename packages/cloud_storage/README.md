# cloud_storage

Cloud file/folder storage for Flutter. Umbrella package — depend on this from app code.

```dart
import 'package:cloud_storage/cloud_storage.dart';

final storage = defaultCloudStorage(
  firestorePath: 'users/$uid/nodes',
  storagePath: 'users/$uid/blobs',
);
```

The package is auth-agnostic and makes no assumption about where in Firestore / Storage your data lives — you supply both paths.

See the [monorepo README](../../README.md) for the full architecture and the [Firebase implementation](../cloud_storage_firebase) for setup and security rules.
