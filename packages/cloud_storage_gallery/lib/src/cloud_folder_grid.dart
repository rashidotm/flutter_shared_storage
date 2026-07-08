import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

import 'localizations/cloud_gallery_localizations.dart';

/// Live grid of a folder's contents — folders shown as folder tiles, files as
/// thumbnails (or generic icons until the Cloud Function generates a thumbnail).
/// Signature for a long-press on a node in [CloudFolderGrid]. Exposes
/// the tap details so consumers can position a menu at the touch point.
typedef CloudNodeLongPressCallback = void Function(
  CloudNode node,
  LongPressStartDetails details,
);

/// Live grid of a folder's contents — folders shown as folder tiles, files as
/// thumbnails (or generic icons until the Cloud Function generates a thumbnail).
///
/// Supports **selection mode**: when [selectedNodeIds] is non-empty and
/// [onNodeToggleSelection] is provided, tap toggles selection instead of
/// opening. Selected tiles show a filled check-circle overlay.
class CloudFolderGrid extends StatelessWidget {
  const CloudFolderGrid({
    super.key,
    required this.storage,
    required this.folderId,
    this.onFolderTap,
    this.onFileTap,
    this.onLinkTap,
    this.onNodeLongPress,
    this.selectionMode = false,
    this.selectedNodeIds = const <String>{},
    this.onNodeToggleSelection,
    this.crossAxisCount = 3,
    this.spacing = 8,
    this.emptyBuilder,
  });

  final CloudStorage storage;
  final String folderId;
  final void Function(CloudFolder folder)? onFolderTap;
  final void Function(CloudFile file, List<CloudFile> mediaSiblings)? onFileTap;
  final void Function(CloudLink link)? onLinkTap;

  /// Fires for both files and folders. [LongPressStartDetails.globalPosition]
  /// is where the user's finger is — use it to anchor a context menu.
  final CloudNodeLongPressCallback? onNodeLongPress;

  /// When true the grid is in selection mode: tap fires
  /// [onNodeToggleSelection] instead of the open callbacks. Selected
  /// tiles (listed in [selectedNodeIds]) get a check-circle overlay.
  /// Can be true even with an empty [selectedNodeIds] — that's the
  /// "just entered selection mode, waiting for the first pick" case.
  final bool selectionMode;

  /// Ids currently selected — rendered with a check-circle overlay.
  final Set<String> selectedNodeIds;

  /// Called when the user taps a tile while [selectionMode] is active.
  final void Function(CloudNode node)? onNodeToggleSelection;
  final int crossAxisCount;
  final double spacing;
  final WidgetBuilder? emptyBuilder;

  bool get _selectionMode =>
      selectionMode && onNodeToggleSelection != null;

  @override
  Widget build(BuildContext context) {
    final l10n = CloudGalleryLocalizations.of(context);
    return StreamBuilder<List<CloudNode>>(
      stream: storage.watchFolder(folderId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text(l10n.gridErrorLabel(snap.error!)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final nodes = snap.data!;
        if (nodes.isEmpty) {
          return emptyBuilder?.call(context) ??
              Center(child: Text(l10n.emptyFolder));
        }
        final mediaSiblings = nodes.whereType<CloudFile>().where((f) => f.isMedia).toList();
        return GridView.builder(
          padding: EdgeInsets.all(spacing),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: nodes.length,
          itemBuilder: (context, i) {
            final node = nodes[i];
            return _NodeTile(
              node: node,
              selected: selectedNodeIds.contains(node.id),
              onTap: () {
                if (_selectionMode) {
                  onNodeToggleSelection!(node);
                  return;
                }
                if (node is CloudFolder) {
                  onFolderTap?.call(node);
                } else if (node is CloudFile) {
                  onFileTap?.call(node, mediaSiblings);
                } else if (node is CloudLink) {
                  onLinkTap?.call(node);
                }
              },
              onLongPressStart: onNodeLongPress == null
                  ? null
                  : (details) => onNodeLongPress!(node, details),
            );
          },
        );
      },
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.onTap,
    required this.onLongPressStart,
    required this.selected,
  });

  final CloudNode node;
  final bool selected;
  final VoidCallback onTap;

  /// Signature matches GestureDetector so we can surface the tap position
  /// to consumers.
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      // InkWell provides the ripple; a GestureDetector wraps it so we can
      // capture LongPressStartDetails (InkWell.onLongPress is positionless).
      child: GestureDetector(
        onLongPressStart: onLongPressStart,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              switch (node) {
                CloudFolder() => _FolderTile(folder: node as CloudFolder),
                CloudFile() => _FileTile(file: node as CloudFile),
                CloudLink() => _LinkTile(link: node as CloudLink),
              },
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              if (selected)
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder});
  final CloudFolder folder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.folder, size: 56),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            folder.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file});
  final CloudFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = file.thumbnailUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb != null && thumb.isNotEmpty)
          CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            placeholder: (_, __) => ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            errorWidget: (_, __, ___) => const _GenericFileIcon(),
          )
        else
          _PlaceholderForMime(file: file),
        if (file.isVideo)
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.play_circle_fill, size: 48),
          ),
        // Filename strip: shown for non-media files (PDFs, docs, audio,
        // generic icons) where a name is the only identifier. Hidden for
        // images and videos — the thumbnail already communicates what the
        // file is, so overlaying text just obscures the visual.
        // PositionedDirectional keeps the strip spanning the tile width
        // and respects the inherited text direction.
        if (!file.isMedia)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: Container(
              // Semi-transparent surface — high contrast with `onSurface`
              // (default color of labelSmall) in both light and dark
              // themes.
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaceholderForMime extends StatelessWidget {
  const _PlaceholderForMime({required this.file});
  final CloudFile file;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    if (file.isImage) {
      icon = Icons.image_outlined;
    } else if (file.isVideo) {
      icon = Icons.movie_outlined;
    } else if (file.mimeType.startsWith('audio/')) {
      icon = Icons.audiotrack_outlined;
    } else if (file.mimeType == 'application/pdf') {
      icon = Icons.picture_as_pdf_outlined;
    } else {
      icon = Icons.insert_drive_file_outlined;
    }
    return Center(child: Icon(icon, size: 48));
  }
}

class _GenericFileIcon extends StatelessWidget {
  const _GenericFileIcon();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.broken_image_outlined, size: 48));
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link});
  final CloudLink link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = link.thumbnailUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb != null && thumb.isNotEmpty)
          CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            placeholder: (_, __) => ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.link, size: 48),
            ),
          )
        else
          const Center(child: Icon(Icons.link, size: 48)),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Container(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              link.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }
}
