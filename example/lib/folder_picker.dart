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
        folderId: startFolderId,
        excludeFolderId: excludeFolderId,
      ),
      fullscreenDialog: true,
    ),
  );
}

class _FolderPickerScreen extends StatelessWidget {
  const _FolderPickerScreen({
    required this.storage,
    required this.folderId,
    required this.excludeFolderId,
  });

  final CloudStorage storage;
  final String folderId;
  final String? excludeFolderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Move to…'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(folderId),
            child: const Text('Move here'),
          ),
        ],
      ),
      body: Column(
        children: [
          CloudFolderBreadcrumb(
            storage: storage,
            folderId: folderId,
            onNavigate: (node) {
              if (node.id == folderId) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => _FolderPickerScreen(
                    storage: storage,
                    folderId: node.id,
                    excludeFolderId: excludeFolderId,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<CloudNode>>(
              stream: storage.watchFolder(folderId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final folders = snap.data!
                    .whereType<CloudFolder>()
                    .where((f) => f.id != excludeFolderId)
                    .toList();
                if (folders.isEmpty) {
                  return const Center(
                    child: Text('No subfolders. Tap "Move here" to pick this one.'),
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _FolderPickerScreen(
                              storage: storage,
                              folderId: folder.id,
                              excludeFolderId: excludeFolderId,
                            ),
                          ),
                        );
                      },
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
