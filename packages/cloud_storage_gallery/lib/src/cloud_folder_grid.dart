import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

/// Live grid of a folder's contents — folders shown as folder tiles, files as
/// thumbnails (or generic icons until the Cloud Function generates a thumbnail).
class CloudFolderGrid extends StatelessWidget {
  const CloudFolderGrid({
    super.key,
    required this.storage,
    required this.folderId,
    this.onFolderTap,
    this.onFileTap,
    this.onFileLongPress,
    this.crossAxisCount = 3,
    this.spacing = 8,
    this.emptyBuilder,
  });

  final CloudStorage storage;
  final String folderId;
  final void Function(CloudFolder folder)? onFolderTap;
  final void Function(CloudFile file, List<CloudFile> mediaSiblings)? onFileTap;
  final void Function(CloudNode node)? onFileLongPress;
  final int crossAxisCount;
  final double spacing;
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CloudNode>>(
      stream: storage.watchFolder(folderId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final nodes = snap.data!;
        if (nodes.isEmpty) {
          return emptyBuilder?.call(context) ??
              const Center(child: Text('Empty folder'));
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
              onTap: () {
                if (node is CloudFolder) {
                  onFolderTap?.call(node);
                } else if (node is CloudFile) {
                  onFileTap?.call(node, mediaSiblings);
                }
              },
              onLongPress: onFileLongPress == null
                  ? null
                  : () => onFileLongPress!(node),
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
    required this.onLongPress,
  });

  final CloudNode node;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: switch (node) {
          CloudFolder() => _FolderTile(folder: node as CloudFolder),
          CloudFile() => _FileTile(file: node as CloudFile),
        },
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
        // PositionedDirectional + start:0/end:0 keeps the strip spanning the
        // whole width and respects the inherited text direction.
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Container(
            // Scrim is a theme token defined for overlays like this one.
            color: theme.colorScheme.scrim.withValues(alpha: 0.5),
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
