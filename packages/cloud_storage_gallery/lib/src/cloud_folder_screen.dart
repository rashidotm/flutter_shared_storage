import 'dart:async';
import 'dart:io';

import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'cloud_batch_upload_dialog.dart';
import 'cloud_breadcrumb.dart';
import 'cloud_bulk_progress_dialog.dart';
import 'cloud_folder_grid.dart';
import 'cloud_folder_picker.dart';
import 'cloud_media_viewer.dart';
import 'cloud_upload_dialog.dart';
import 'localizations/cloud_gallery_localizations.dart';
import 'thumbnail_generator.dart';

/// A ready-to-use, full-featured folder browser backed by [CloudStorage].
///
/// Ships with everything a typical file-manager screen needs:
///
///   * Breadcrumb in the app bar
///   * Grid of subfolders + files (with thumbnails when available)
///   * Long-press context menu — Open, Download, Rename, Move to…, Info,
///     Delete
///   * FABs — Create folder, Upload file (client-side thumbnails included
///     for images/videos)
///   * Upload progress dialog with a Cancel button
///
/// Drop it into a `MaterialApp` as the home widget. If you want a different
/// UX, build your own screen using the lower-level widgets
/// ([CloudFolderGrid], [CloudFolderBreadcrumb], [CloudMediaViewer],
/// [CloudUploadDialog], [pickCloudFolder], [generateThumbnails]).
class CloudFolderScreen extends StatefulWidget {
  const CloudFolderScreen({
    super.key,
    required this.storage,
    this.folderId = kRootFolderId,
    this.initialChain,
    this.rootLabel,
    this.readOnly = false,
  });

  final CloudStorage storage;
  final String folderId;

  /// Ancestor chain (root → ... → current). When null, the breadcrumb
  /// self-loads on first show — used for deep-links / cold start.
  final List<CloudNode>? initialChain;

  /// Label shown for the root folder in breadcrumbs. When null, the
  /// localized default (`CloudGalleryLocalizations.of(context).rootLabel`)
  /// is used.
  final String? rootLabel;

  /// When true, hides the write-oriented UI:
  ///
  /// * Both floating action buttons (Create folder, Upload file).
  /// * The mutation entries in the long-press popup menu — Rename,
  ///   Move to…, Delete.
  ///
  /// Read-only actions (Open, Download, Info) remain available. Use this
  /// to distinguish viewer users from editor users. Access is NOT enforced
  /// client-side — pair with Firestore/Storage security rules if you rely
  /// on it for protection.
  final bool readOnly;

  @override
  State<CloudFolderScreen> createState() => _CloudFolderScreenState();
}

class _CloudFolderScreenState extends State<CloudFolderScreen> {
  CloudStorage get _storage => widget.storage;

  /// Chain known for THIS screen. Passed down to child screens so their
  /// breadcrumb renders synchronously without a fetch.
  late final List<CloudNode>? _chain = widget.initialChain ??
      (widget.folderId == kRootFolderId
          ? <CloudNode>[_syntheticRoot()]
          : null);

  static CloudFolder _syntheticRoot() => CloudFolder(
        id: kRootFolderId,
        name: '',
        parentId: '',
        path: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  // ── Selection mode ─────────────────────────────────────────────────────

  /// Currently-selected nodes keyed by id. Non-empty = selection mode is
  /// active. Kept as a map so bulk operations don't have to re-fetch each
  /// node from Firestore just to know whether it's a file or folder.
  final Map<String, CloudNode> _selected = <String, CloudNode>{};

  bool get _inSelectionMode => _selected.isNotEmpty;

  void _toggleSelection(CloudNode node) {
    setState(() {
      if (_selected.containsKey(node.id)) {
        _selected.remove(node.id);
      } else {
        _selected[node.id] = node;
      }
    });
  }

  void _enterSelection(CloudNode node) {
    setState(() => _selected[node.id] = node);
  }

  void _clearSelection() {
    if (_selected.isEmpty) return;
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CloudGalleryLocalizations.of(context);
    return Scaffold(
      appBar: _inSelectionMode
          ? _buildSelectionAppBar(l10n)
          : _buildBrowseAppBar(l10n),
      // SafeArea keeps the grid clear of gesture bars, curved edges, and
      // any other system-decoration insets. AppBar already covers the top;
      // requesting `top: false` avoids double padding.
      body: SafeArea(
        top: false,
        child: CloudFolderGrid(
        storage: _storage,
        folderId: widget.folderId,
        onFolderTap: (folder) {
          // Append tapped folder to our known chain — child renders its
          // breadcrumb without any Firestore round-trip.
          final chain = _chain;
          final childChain =
              chain == null ? null : <CloudNode>[...chain, folder];
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CloudFolderScreen(
                storage: _storage,
                folderId: folder.id,
                initialChain: childChain,
                rootLabel: widget.rootLabel,
                readOnly: widget.readOnly,
              ),
            ),
          );
        },
        onFileTap: (file, mediaSiblings) {
          if (!file.isMedia) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _MediaViewerScaffold(
                files: mediaSiblings,
                initialIndex: mediaSiblings.indexOf(file),
              ),
            ),
          );
        },
        onNodeLongPress: (node, details) =>
            _showNodeMenu(node, details.globalPosition),
        selectedNodeIds: _selected.keys.toSet(),
        onNodeToggleSelection: widget.readOnly ? null : _toggleSelection,
      ),
      ),
      floatingActionButton: (widget.readOnly || _inSelectionMode)
          ? null
          : Wrap(
              direction: Axis.horizontal,
              spacing: 8,
              children: [
                FloatingActionButton(
                  heroTag: 'newFolder',
                  tooltip: l10n.createFolderTooltip,
                  onPressed: _createFolder,
                  child: const Icon(Icons.create_new_folder),
                ),
                FloatingActionButton(
                  heroTag: 'upload',
                  tooltip: l10n.uploadFileTooltip,
                  onPressed: _uploadFile,
                  child: const Icon(Icons.note_add_outlined),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildBrowseAppBar(CloudGalleryLocalizations l10n) {
    return AppBar(
      // The breadcrumb replaces the traditional AppBar title — it already
      // shows the current folder as its last (bold) segment.
      title: CloudFolderBreadcrumb(
        storage: _storage,
        folderId: widget.folderId,
        chain: _chain,
        rootLabel: widget.rootLabel,
        onNavigate: (node) {
          if (node.id == widget.folderId) return;
          // Sub-chain up to the tapped ancestor — child renders instantly.
          List<CloudNode>? childChain;
          final chain = _chain;
          if (chain != null) {
            final idx = chain.indexWhere((n) => n.id == node.id);
            if (idx >= 0) childChain = chain.sublist(0, idx + 1);
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => CloudFolderScreen(
                storage: _storage,
                folderId: node.id,
                initialChain: childChain,
                rootLabel: widget.rootLabel,
                readOnly: widget.readOnly,
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(CloudGalleryLocalizations l10n) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text(l10n.selectionCountLabel(_selected.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.drive_file_move),
          tooltip: l10n.menuMoveTo,
          onPressed: _bulkMove,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.menuDelete,
          onPressed: _bulkDelete,
        ),
      ],
    );
  }

  // ── FAB actions ─────────────────────────────────────────────────────────

  Future<void> _createFolder() async {
    final l10n = CloudGalleryLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.newFolderTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.buttonCreate),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _storage.createFolder(parentId: widget.folderId, name: name);
  }

  Future<void> _uploadFile() async {
    final result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    // Filter out picks without a real filesystem path (some pickers can
    // hand back streams-only entries).
    final picked = result.files
        .where((f) => f.path != null)
        .toList(growable: false);
    if (picked.isEmpty) return;

    final tasks = <UploadTask>[];
    for (final entry in picked) {
      final file = File(entry.path!);
      // Generate thumbnails client-side. Returns null for non-media types
      // (PDFs, docs, etc.) — those upload without variants.
      final thumbnails = await generateThumbnails(file);
      final task = _storage.upload(
        parentId: widget.folderId,
        name: entry.name,
        source: FileSource(file),
        thumbnail:
            thumbnails == null ? null : BytesSource(thumbnails.thumb),
        preview:
            thumbnails == null ? null : BytesSource(thumbnails.preview),
      );
      // We only use `task.progress` for UI. If a user cancels,
      // `task.result` completes with an error; without a listener that
      // becomes an unhandled zone error and Flutter treats it as a
      // crash. `.ignore()` attaches a no-op handler that absorbs it.
      task.result.ignore();
      tasks.add(task);
    }

    if (!mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => tasks.length == 1
            ? CloudUploadDialog(task: tasks.first)
            : CloudBatchUploadDialog(tasks: tasks),
      ),
    );
  }

  // ── Long-press popup menu + actions ────────────────────────────────────

  Future<void> _showNodeMenu(CloudNode node, Offset globalPos) async {
    final l10n = CloudGalleryLocalizations.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(globalPos, globalPos),
      Offset.zero & overlay.size,
    );

    final isFile = node is CloudFile;
    final isMedia = isFile && node.isMedia;

    final canMutate = !widget.readOnly;

    final choice = await showMenu<String>(
      context: context,
      position: position,
      items: [
        if (canMutate)
          PopupMenuItem(
            value: 'select',
            child: ListTile(
              leading: const Icon(Icons.check_box_outlined),
              title: Text(l10n.menuSelect),
            ),
          ),
        if (isMedia || node is CloudFolder)
          PopupMenuItem(
            value: 'open',
            child: ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(l10n.menuOpen),
            ),
          ),
        if (isFile)
          PopupMenuItem(
            value: 'download',
            child: ListTile(
              leading: const Icon(Icons.download),
              title: Text(l10n.menuDownload),
            ),
          ),
        if (isFile && canMutate)
          PopupMenuItem(
            value: 'thumbnail',
            child: ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.menuSetThumbnail),
            ),
          ),
        if (canMutate)
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(l10n.menuRename),
            ),
          ),
        if (canMutate)
          PopupMenuItem(
            value: 'move',
            child: ListTile(
              leading: const Icon(Icons.drive_file_move),
              title: Text(l10n.menuMoveTo),
            ),
          ),
        PopupMenuItem(
          value: 'info',
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.menuInfo),
          ),
        ),
        if (canMutate) const PopupMenuDivider(),
        if (canMutate)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.menuDelete),
            ),
          ),
      ],
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case 'select':
        _enterSelection(node);
      case 'open':
        _openNode(node);
      case 'download':
        await _downloadFile(node as CloudFile);
      case 'thumbnail':
        await _setThumbnail(node as CloudFile);
      case 'rename':
        await _renameNode(node);
      case 'move':
        await _moveNode(node);
      case 'info':
        await _showInfo(node);
      case 'delete':
        await _deleteNode(node);
    }
  }

  void _openNode(CloudNode node) {
    if (node is CloudFolder) {
      final chain = _chain;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CloudFolderScreen(
            storage: _storage,
            folderId: node.id,
            initialChain: chain == null ? null : <CloudNode>[...chain, node],
            rootLabel: widget.rootLabel,
            readOnly: widget.readOnly,
          ),
        ),
      );
      return;
    }
    if (node is CloudFile && node.isMedia) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _MediaViewerScaffold(
            files: [node],
            initialIndex: 0,
          ),
        ),
      );
    }
  }

  Future<void> _downloadFile(CloudFile file) async {
    final l10n = CloudGalleryLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.downloadingSnack(file.name))),
    );
    try {
      final localFile = await _storage.download(file.id);
      await Share.shareXFiles(
        [XFile(localFile.path, name: file.name)],
        subject: file.name,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.downloadFailedSnack(e))),
      );
    }
  }

  Future<void> _setThumbnail(CloudFile file) async {
    final l10n = CloudGalleryLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final pathStr = result.files.single.path;
    if (pathStr == null) return;

    // Resize the picked image into thumb (256w) + preview (1024w) JPEGs.
    // generateThumbnails returns null for non-image sources — but the
    // FilePicker restriction above guarantees an image was chosen.
    final imageFile = File(pathStr);
    final thumbnails = await generateThumbnails(imageFile);
    if (thumbnails == null || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloudBulkProgressDialog<CloudFile>(
        title: l10n.uploadingTitle,
        items: [file],
        operation: (f) async {
          await _storage.setThumbnail(
            f.id,
            thumbnail: BytesSource(thumbnails.thumb),
            preview: BytesSource(thumbnails.preview),
          );
        },
      ),
    );
  }

  Future<void> _renameNode(CloudNode node) async {
    final l10n = CloudGalleryLocalizations.of(context);
    final controller = TextEditingController(text: node.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.renameTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.buttonRename),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == node.name) return;
    if (node is CloudFile) {
      await _storage.renameFile(node.id, newName);
    } else if (node is CloudFolder) {
      await _storage.renameFolder(node.id, newName);
    }
  }

  Future<void> _moveNode(CloudNode node) async {
    final l10n = CloudGalleryLocalizations.of(context);
    final target = await pickCloudFolder(
      context,
      storage: _storage,
      // For a folder move, exclude the folder itself. Descendants are
      // also invalid targets but aren't guarded here; the CloudStorage
      // impl or security rules should surface any resulting error.
      excludeFolderId: node is CloudFolder ? node.id : null,
      rootLabel: widget.rootLabel,
    );
    if (target == null || target == node.parentId || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloudBulkProgressDialog<CloudNode>(
        title: l10n.movingTitle,
        items: [node],
        operation: (n) async {
          if (n is CloudFile) {
            await _storage.moveFile(n.id, newParentId: target);
          } else if (n is CloudFolder) {
            await _storage.moveFolder(n.id, newParentId: target);
          }
        },
      ),
    );
  }

  Future<void> _showInfo(CloudNode node) async {
    final l10n = CloudGalleryLocalizations.of(context);
    final rows = <MapEntry<String, String>>[
      MapEntry(l10n.infoLabelName, node.name),
      MapEntry(
        l10n.infoLabelType,
        node is CloudFolder ? l10n.infoTypeFolder : l10n.infoTypeFile,
      ),
      MapEntry(l10n.infoLabelPath, node.path.isEmpty ? '/' : node.path),
      MapEntry(l10n.infoLabelCreated, node.createdAt.toLocal().toString()),
      MapEntry(l10n.infoLabelUpdated, node.updatedAt.toLocal().toString()),
      if (node is CloudFile) MapEntry(l10n.infoLabelMime, node.mimeType),
      if (node is CloudFile)
        MapEntry(l10n.infoLabelSize, _formatBytes(node.sizeBytes, l10n)),
    ];
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(node.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in rows) ...[
                Text(
                  e.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(e.value),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.buttonClose),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNode(CloudNode node) async {
    final l10n = CloudGalleryLocalizations.of(context);
    final isFolder = node is CloudFolder;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle(node.name)),
        content: Text(
          isFolder ? l10n.deleteFolderBody : l10n.deleteFileBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.buttonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloudBulkProgressDialog<CloudNode>(
        title: l10n.deletingTitle,
        items: [node],
        operation: (n) async {
          if (n is CloudFile) {
            await _storage.deleteFile(n.id);
          } else if (n is CloudFolder) {
            await _storage.deleteFolder(n.id, recursive: true);
          }
        },
      ),
    );
  }

  // ── Bulk actions (selection mode) ──────────────────────────────────────

  Future<void> _bulkDelete() async {
    final l10n = CloudGalleryLocalizations.of(context);
    final nodes = _selected.values.toList(growable: false);
    if (nodes.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteMultipleTitle(nodes.length)),
        content: Text(l10n.deleteFileBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.buttonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloudBulkProgressDialog<CloudNode>(
        title: l10n.deletingTitle,
        items: nodes,
        operation: (node) async {
          if (node is CloudFile) {
            await _storage.deleteFile(node.id);
          } else if (node is CloudFolder) {
            await _storage.deleteFolder(node.id, recursive: true);
          }
        },
      ),
    );
    _clearSelection();
  }

  Future<void> _bulkMove() async {
    final l10n = CloudGalleryLocalizations.of(context);
    final nodes = _selected.values.toList(growable: false);
    if (nodes.isEmpty) return;
    // Exclude any selected FOLDER from valid destinations — you can't
    // move a folder into itself. Files-only selections have no exclusions.
    final firstSelectedFolderId = nodes
        .whereType<CloudFolder>()
        .map((f) => f.id)
        .firstOrNull;
    final target = await pickCloudFolder(
      context,
      storage: _storage,
      excludeFolderId: firstSelectedFolderId,
      rootLabel: widget.rootLabel,
    );
    if (target == null || !mounted) return;
    final toMove = nodes
        .where((n) => n.parentId != target && n.id != target)
        .toList(growable: false);
    if (toMove.isEmpty) {
      _clearSelection();
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloudBulkProgressDialog<CloudNode>(
        title: l10n.movingTitle,
        items: toMove,
        operation: (node) async {
          if (node is CloudFile) {
            await _storage.moveFile(node.id, newParentId: target);
          } else if (node is CloudFolder) {
            await _storage.moveFolder(node.id, newParentId: target);
          }
        },
      ),
    );
    _clearSelection();
  }

  static String _formatBytes(int bytes, CloudGalleryLocalizations l10n) {
    if (bytes < 1024) return '$bytes ${l10n.unitBytes}';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} ${l10n.unitKilobytes}';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} ${l10n.unitMegabytes}';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} ${l10n.unitGigabytes}';
  }
}

/// Scaffold + AppBar wrapper for [CloudMediaViewer] that keeps its title
/// in sync with the currently-visible file as the user swipes.
class _MediaViewerScaffold extends StatefulWidget {
  const _MediaViewerScaffold({
    required this.files,
    required this.initialIndex,
  });

  final List<CloudFile> files;
  final int initialIndex;

  @override
  State<_MediaViewerScaffold> createState() => _MediaViewerScaffoldState();
}

class _MediaViewerScaffoldState extends State<_MediaViewerScaffold> {
  late CloudFile _current = widget.files[widget.initialIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_current.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: CloudMediaViewer(
        files: widget.files,
        initialIndex: widget.initialIndex,
        onPageChanged: (i, file) => setState(() => _current = file),
      ),
    );
  }
}
