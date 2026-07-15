import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

import 'cloud_node_sort.dart';
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
///
/// **Pinch-to-zoom** — two-finger pinch changes the number of columns
/// between [minCrossAxisCount] and [maxCrossAxisCount]. Column-count
/// changes fade-through-scale via an [AnimatedSwitcher]. Single-finger
/// scroll is not intercepted — only gestures with two or more pointers
/// resize.
class CloudFolderGrid extends StatefulWidget {
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
    this.minCrossAxisCount = 2,
    this.maxCrossAxisCount = 5,
    this.spacing = 8,
    this.sort = const CloudNodeSort(),
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

  /// Initial column count. After the user pinches to change it, the
  /// grid's internal state takes over — subsequent rebuilds with a
  /// different [crossAxisCount] value are ignored.
  final int crossAxisCount;

  /// Lower bound for pinch-to-zoom. Two-finger zoom in past this stops.
  final int minCrossAxisCount;

  /// Upper bound for pinch-to-zoom. Two-finger zoom out past this stops.
  final int maxCrossAxisCount;

  final double spacing;

  /// How to order the children in this folder. Applied client-side —
  /// no backend index needed. See [CloudNodeSort] for options.
  final CloudNodeSort sort;

  final WidgetBuilder? emptyBuilder;

  @override
  State<CloudFolderGrid> createState() => _CloudFolderGridState();
}

class _CloudFolderGridState extends State<CloudFolderGrid> {
  late int _crossAxisCount = widget.crossAxisCount
      .clamp(widget.minCrossAxisCount, widget.maxCrossAxisCount);

  /// Column count when the current pinch gesture began. Continuous
  /// scale updates divide this by `details.scale` to derive the target
  /// count — that way the gesture is anchored to the finger positions
  /// at start, not to the last frame.
  int _pinchBaseCount = 0;

  bool get _selectionMode =>
      widget.selectionMode && widget.onNodeToggleSelection != null;

  void _onScaleStart(ScaleStartDetails details) {
    _pinchBaseCount = _crossAxisCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Ignore single-finger drags — those belong to the underlying
    // scrollable. Only true pinches (2+ pointers) resize.
    if (details.pointerCount < 2) return;
    // scale > 1 → fingers spreading → user wants bigger tiles, i.e.
    // fewer columns.
    // scale < 1 → fingers pinching in → smaller tiles, more columns.
    final target = (_pinchBaseCount / details.scale)
        .round()
        .clamp(widget.minCrossAxisCount, widget.maxCrossAxisCount);
    if (target != _crossAxisCount) {
      setState(() => _crossAxisCount = target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CloudGalleryLocalizations.of(context);
    return StreamBuilder<List<CloudNode>>(
      stream: widget.storage.watchFolder(widget.folderId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text(l10n.gridErrorLabel(snap.error!)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rawNodes = snap.data!;
        if (rawNodes.isEmpty) {
          return widget.emptyBuilder?.call(context) ??
              Center(child: Text(l10n.emptyFolder));
        }
        // Client-side sort — the Firestore query returns the folder's
        // children unordered (creation order in practice); we order in
        // Dart so no composite index is needed on the consumer's side.
        final nodes = sortCloudNodes(rawNodes, widget.sort);
        final mediaSiblings =
            nodes.whereType<CloudFile>().where((f) => f.isMedia).toList();
        // GestureDetector for pinch-to-zoom. HitTestBehavior.opaque
        // means the whole grid area receives pointer events, but
        // single-finger drags fall through to the GridView's scroll
        // recognizer thanks to the pointerCount gate in
        // _onScaleUpdate.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          // AnimatedSwitcher keyed on the column count triggers a
          // scale + fade transition each time the count changes.
          // Between counts the grid renders normally; only the
          // discrete jumps animate.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: GridView.builder(
              key: ValueKey<int>(_crossAxisCount),
              // Extra bottom padding leaves the last row visible above any
              // floating action button (or other bottom-anchored chrome).
              // Standard FAB is 56 dp + 16 dp margin from the edge; 80 dp
              // gives one row of breathing room on top of that.
              padding: EdgeInsets.fromLTRB(
                widget.spacing,
                widget.spacing,
                widget.spacing,
                widget.spacing + 80,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                crossAxisSpacing: widget.spacing,
                mainAxisSpacing: widget.spacing,
              ),
              itemCount: nodes.length,
              itemBuilder: (context, i) {
                final node = nodes[i];
                return _NodeTile(
                  node: node,
                  selected: widget.selectedNodeIds.contains(node.id),
                  onTap: () {
                    if (_selectionMode) {
                      widget.onNodeToggleSelection!(node);
                      return;
                    }
                    if (node is CloudFolder) {
                      widget.onFolderTap?.call(node);
                    } else if (node is CloudFile) {
                      widget.onFileTap?.call(node, mediaSiblings);
                    } else if (node is CloudLink) {
                      widget.onLinkTap?.call(node);
                    }
                  },
                  onLongPressStart: widget.onNodeLongPress == null
                      ? null
                      : (details) => widget.onNodeLongPress!(node, details),
                );
              },
            ),
          ),
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
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const Center(child: Icon(Icons.folder, size: 56)),
        // Name strip is a bottom overlay — same pattern as _FileTile /
        // _LinkTile. Being positioned means it can't push the tile's
        // main-axis bounds, so no overflow errors when the pinch takes
        // the tile smaller than icon+label would fit in a Column.
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Container(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
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
