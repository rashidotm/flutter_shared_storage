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
    final scheme = Theme.of(context).colorScheme;
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
      // SafeArea keeps the picker list clear of the bottom gesture bar
      // and curved edges. AppBar handles top → `top: false`.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Breadcrumb sits on a primary strip so it visually
            // continues into the primary-painted list below. Container
            // is used instead of ColoredBox specifically because
            // Column doesn't stretch its children by default (its
            // crossAxisAlignment defaults to center) — the width:
            // infinity forces the coloured strip to span the whole
            // row rather than shrink to the breadcrumb's content.
            //
            // scrollToCurrent is disabled so the root segment is
            // always pinned to the row's leading edge; deep chains
            // extend to the trailing edge and remain horizontally
            // scrollable.
            Container(
              width: double.infinity,
              color: scheme.primary,
              child: CloudFolderBreadcrumb(
                storage: widget.storage,
                folderId: _currentFolderId,
                rootLabel: rootLabel,
                onNavigate: (node) => _navigateTo(node.id),
                foregroundColor: scheme.onPrimary,
                scrollToCurrent: false,
              ),
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
                    // Same primary/onPrimary card treatment as the
                    // empty-folder label in CloudFolderGrid — visible
                    // regardless of the ambient scaffold background or
                    // any color baked into the consumer's textTheme.
                    // The outer Padding guarantees at least 50 px
                    // between the card and each screen edge; on a
                    // long hint the text wraps to fit the available
                    // width.
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 50),
                        child: Card(
                          color: scheme.primary,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Text(
                              l10n.moveHereEmptyHint(moveHereLabel),
                              style: TextStyle(color: scheme.onPrimary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  // Whole list area is painted with primary; text and
                  // icons on top read as onPrimary. Matches the empty-
                  // state card visually and sidesteps any custom
                  // ListTileTheme the consumer may have installed.
                  return ColoredBox(
                    color: scheme.primary,
                    child: ListView.builder(
                      itemCount: folders.length,
                      itemBuilder: (context, i) {
                        final folder = folders[i];
                        return ListTile(
                          leading: Icon(
                            Icons.folder,
                            color: scheme.onPrimary,
                          ),
                          title: Text(
                            folder.name,
                            style: TextStyle(color: scheme.onPrimary),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: scheme.onPrimary,
                          ),
                          onTap: () => _navigateTo(folder.id),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
