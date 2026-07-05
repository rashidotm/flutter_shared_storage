import 'package:cloud_storage/cloud_storage.dart';
import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:flutter/material.dart';

/// Presents a modal that lets the user navigate the folder tree and pick a
/// destination folder. Returns the selected folder's id, or `null` if the
/// user cancelled.
///
/// [excludeFolderId] hides one folder from the list — useful when moving a
/// folder, since you can't move a folder into itself or its descendants.
Future<String?> pickFolder(
  BuildContext context, {
  required CloudStorage storage,
  String? excludeFolderId,
  String startFolderId = kRootFolderId,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => _FolderPickerScreen(
        storage: storage,
        startFolderId: startFolderId,
        excludeFolderId: excludeFolderId,
      ),
      fullscreenDialog: true,
    ),
  );
}

class _FolderPickerScreen extends StatefulWidget {
  const _FolderPickerScreen({
    required this.storage,
    required this.startFolderId,
    required this.excludeFolderId,
  });

  final CloudStorage storage;
  final String startFolderId;
  final String? excludeFolderId;

  @override
  State<_FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<_FolderPickerScreen> {
  // Current folder shown in the picker. Navigation within the picker is
  // internal state — no extra Navigator routes get pushed. This keeps the
  // outer `pickFolder(...)` Future waiting on the SINGLE route that
  // Navigator.push added, and popping THIS screen with a value cleanly
  // resolves that Future regardless of how deep the user has navigated.
  late String _currentFolderId = widget.startFolderId;

  void _navigateTo(String folderId) {
    if (folderId == _currentFolderId) return;
    setState(() => _currentFolderId = folderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Move to…'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_currentFolderId),
            child: const Text('Move here'),
          ),
        ],
      ),
      body: Column(
        children: [
          CloudFolderBreadcrumb(
            storage: widget.storage,
            folderId: _currentFolderId,
            onNavigate: (node) => _navigateTo(node.id),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<CloudNode>>(
              // Key ensures the StreamBuilder rebuilds its subscription when
              // we navigate — otherwise the old folder's data would still be
              // visible on the first frame after setState.
              key: ValueKey(_currentFolderId),
              stream: widget.storage.watchFolder(_currentFolderId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final folders = snap.data!
                    .whereType<CloudFolder>()
                    .where((f) => f.id != widget.excludeFolderId)
                    .toList();
                if (folders.isEmpty) {
                  return const Center(
                    child: Text(
                      'No subfolders. Tap "Move here" to pick this one.',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, i) {
                    final folder = folders[i];
                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(folder.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _navigateTo(folder.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
