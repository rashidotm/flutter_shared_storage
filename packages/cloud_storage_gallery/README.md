# cloud_storage_gallery

Optional widgets for browsing folders and viewing media from `cloud_storage`.

```dart
CloudFolderGrid(
  storage: storage,
  folderId: currentFolderId,
  onFolderTap: (f) => Navigator.push(...),
  onFileTap: (file, mediaSiblings) {
    if (file.isMedia) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CloudMediaViewer(
          files: mediaSiblings,
          initialIndex: mediaSiblings.indexOf(file),
        ),
      ));
    }
  },
)
```

Pulls in `photo_view`, `video_player`, `chewie`, `cached_network_image`. If you don't want those dependencies, just don't depend on this package — `cloud_storage` itself is headless.
