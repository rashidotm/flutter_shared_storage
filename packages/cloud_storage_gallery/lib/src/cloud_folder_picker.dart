import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

import 'cloud_breadcrumb.dart';
import 'localizations/cloud_gallery_localizations.dart';

/// Presents a modal that lets the user navigate the folder tree and pick a
/// destination folder. Returns the selected folder's id, or `null` if the
/// user cancelled.
///
/// [excludeFolderId] hides one folder from the list — pass the source
/// folder's id when moving a folder, since you can't move it into itself.
/// (Descendants of that folder are still shown; the caller should surface
/// any resulting error.)
Future<String?> pickCloudFolder(
  BuildContext context, {
  required CloudStorage storage,
  String? excludeFolderId,
  String startFolderId = kRootFolderId,
  String? title,
  String? moveHereLabel,
  String? rootLabel,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => _CloudFolderPickerScreen(
        storage: storage,
        startFolderId: startFolderId,
        excludeFolderId: excludeFolderId,
        title: title,
        moveHereLabel: moveHereLabel,
        rootLabel: rootLabel,
      ),
      fullscreenDialog: true,
    ),
  );
}

class _CloudFolderPickerScreen extends StatefulWidget {
  const _CloudFolderPickerScreen({
    required this.storage,
    required this.startFolderId,
    required this.excludeFolderId,
    required this.title,
    required this.moveHereLabel,
    required this.rootLabel,
  });

  final CloudStorage storage;
  final String startFolderId;
  final String? excludeFolderId;
  final String? title;
  final String? moveHereLabel;
  final String? rootLabel;

  @override
  State<_CloudFolderPickerScreen> createState() =>
      _CloudFolderPickerScreenState();
}

class _CloudFolderPickerScreenState extends State<_CloudFolderPickerScreen> {
  // Navigation is internal state — no extra Navigator routes get pushed.
  // The outer `pickCloudFolder(...)` Future waits on the SINGLE route the
  // caller pushed, so popping THIS screen with a value cleanly resolves
  // that Future regardless of how deep the user has navigated.
  late String _currentFolderId = widget.startFolderId;

  void _navigateTo(String folderId) {
    if (folderId == _currentFolderId) return;
    setState(() => _currentFolderId = folderId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CloudGalleryLocalizations.of(context);
    final title = widget.title ?? l10n.moveToTitle;
    final moveHereLabel = widget.moveHereLabel ?? l10n.buttonMoveHere;
    final rootLabel = widget.rootLabel ?? l10n.rootLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_currentFolderId),
            child: Text(moveHereLabel),
          ),
        ],
      ),
      body: Column(
        children: [
          CloudFolderBreadcrumb(
            storage: widget.storage,
            folderId: _currentFolderId,
            rootLabel: rootLabel,
            onNavigate: (node) => _navigateTo(node.id),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<CloudNode>>(
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
                  return Center(
                    child: Text(l10n.moveHereEmptyHint(moveHereLabel)),
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
