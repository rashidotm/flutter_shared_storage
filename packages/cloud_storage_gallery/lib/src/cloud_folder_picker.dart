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

  // Ancestor chain (root → ... → current) maintained in-memory so the
  // breadcrumb can render immediately on every navigation. Without
  // this the breadcrumb would fall back to walking `parentId` via
  // sequential `storage.getNode` calls, which introduces visible
  // latency between tapping a folder and the address bar updating.
  //
  // Seeded with a synthetic root for the common startFolderId ==
  // kRootFolderId case. For the (rare) non-root start we leave it
  // null; the breadcrumb will self-load once as before.
  late List<CloudNode>? _chain = widget.startFolderId == kRootFolderId
      ? <CloudNode>[_syntheticRoot()]
      : null;

  static CloudFolder _syntheticRoot() => CloudFolder(
        id: kRootFolderId,
        name: '',
        parentId: '',
        path: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Tap on a subfolder in the list — extend the chain by one.
  void _navigateInto(CloudFolder folder) {
    if (folder.id == _currentFolderId) return;
    setState(() {
      _currentFolderId = folder.id;
      final chain = _chain;
      _chain = chain == null ? null : <CloudNode>[...chain, folder];
    });
  }

  /// Tap on any ancestor in the breadcrumb — truncate the chain to
  /// that segment. Falls back to just switching the folder id if we
  /// somehow don't have a chain (non-root start case).
  void _jumpToAncestor(CloudNode node) {
    if (node.id == _currentFolderId) return;
    final chain = _chain;
    if (chain == null) {
      setState(() => _currentFolderId = node.id);
      return;
    }
    final idx = chain.indexWhere((n) => n.id == node.id);
    if (idx < 0) {
      setState(() => _currentFolderId = node.id);
      return;
    }
    setState(() {
      _currentFolderId = node.id;
      _chain = chain.sublist(0, idx + 1);
    });
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
                chain: _chain,
                rootLabel: rootLabel,
                onNavigate: _jumpToAncestor,
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
                  // The list area is ALWAYS painted with primary,
                  // whether or not the folder has children — otherwise
                  // navigating into an empty subfolder would flash
                  // the primary strip back to the ambient scaffold
                  // background, then flash it back on the next
                  // non-empty folder. Content varies; wrapper doesn't.
                  final Widget body = folders.isEmpty
                      ? Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 50),
                            child: Text(
                              l10n.moveHereEmptyHint(moveHereLabel),
                              style: TextStyle(color: scheme.onPrimary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
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
                              onTap: () => _navigateInto(folder),
                            );
                          },
                        );
                  return ColoredBox(color: scheme.primary, child: body);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
