# cloud_storage_gallery

Optional widgets for browsing folders and viewing media from `cloud_storage`.

All widgets are headless (no `Scaffold` / `AppBar`) — you own the surrounding chrome. Everything inherits from the app's `Theme` and respects `Directionality.of(context)` for RTL/LTR.

## Grid + navigation

```dart
CloudFolderGrid(
  storage: storage,
  folderId: currentFolderId,
  onFolderTap: (f) => Navigator.push(...),
  onFileTap: (file, mediaSiblings) {
    if (file.isMedia) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(file.name)),
          body: CloudMediaViewer(
            files: mediaSiblings,
            initialIndex: mediaSiblings.indexOf(file),
          ),
        ),
      ));
    }
  },
)
```

## Media viewer

`CloudMediaViewer` returns just the swipeable `PageView` of images/videos. You supply the `Scaffold` and any app bar. Wrapping in a `Scaffold` with an `AppBar` gives you the platform back button automatically. If you want the title to update as the user swipes, listen to `onPageChanged`:

```dart
class _ViewerScreen extends StatefulWidget { /* ... */ }

class _ViewerScreenState extends State<_ViewerScreen> {
  late CloudFile current = widget.files[widget.initialIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(current.name)),
      body: CloudMediaViewer(
        files: widget.files,
        initialIndex: widget.initialIndex,
        onPageChanged: (i, file) => setState(() => current = file),
      ),
    );
  }
}
```

## Dependencies

Pulls in `photo_view`, `video_player`, `chewie`, `cached_network_image`. If you don't want those dependencies, just don't depend on this package — `cloud_storage` itself is headless.
