# cloud_storage_firebase

Firebase Storage + Firestore implementation of [`cloud_storage_platform_interface`](../cloud_storage_platform_interface).

## Setup

1. Configure Firebase in your app (`flutterfire configure` and `Firebase.initializeApp()`).
2. Sign in however you want — the package itself is auth-agnostic and does not read `FirebaseAuth.currentUser`. Access control is enforced by your security rules.
3. Deploy the [Cloud Functions](../../functions) for thumbnail generation, with the same prefixes you pass to the package.
4. Deploy security rules that fit your chosen layout (see below).

## Storage layout

The bucket layout is flat: every file's bytes live directly under `storagePath`, keyed by nodeId. Thumbnails and previews (written by the Cloud Function) go in sibling `thumbs/` and `previews/` subfolders. The Firestore folder hierarchy is entirely independent — renaming or moving a file in Firestore never touches Storage.

```
{storagePath}/{nodeId}.{ext}          ← original bytes
{storagePath}/thumbs/{nodeId}.jpg     ← generated
{storagePath}/previews/{nodeId}.jpg   ← generated
```

## Usage

```dart
final storage = FirebaseCloudStorage(
  firestorePath: 'files',    // any Firestore collection path
  storagePath: 'files',      // any bucket prefix
);

final folder = await storage.createFolder(
  parentId: kRootFolderId,
  name: 'Photos',
);

final task = storage.upload(
  parentId: folder.id,
  name: 'beach.jpg',
  source: FileSource(File('/path/beach.jpg')),
);
task.progress.listen((p) => print('${p.fraction}'));
final file = await task.result;
```

`firestorePath` and `storagePath` are validated at construction — empty values or paths containing leading/trailing slashes throw `InvalidArgumentException`.

## Security rules

Rules depend on the paths you choose. The example below scopes each user to their own `users/{uid}/...` prefix.

**Firestore (`firestore.rules`):**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /users/{uid}/nodes/{nodeId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

**Storage (`storage.rules`):**
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{uid}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

For multi-tenant apps (orgs, workspaces, etc.), structure the rules around your tenant boundary instead — the package has no opinion.
