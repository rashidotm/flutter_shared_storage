import 'dart:async';
import 'dart:io';

import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'cloud_breadcrumb.dart';
import 'cloud_folder_grid.dart';
import 'cloud_folder_picker.dart';
import 'cloud_media_viewer.dart';
import 'cloud_upload_dialog.dart';
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
    this.rootLabel = 'Home',
    this.readOnly = false,
  });

  final CloudStorage storage;
  final String folderId;

  /// Ancestor chain (root → ... → current). When null, the breadcrumb
  /// self-loads on first show — used for deep-links / cold start.
  final List<CloudNode>? initialChain;

  /// Label shown for the root folder in breadcrumbs.
  final String rootLabel;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The breadcrumb replaces the traditional AppBar title — it already
      // shows the current folder as its last (bold) segment.
      appBar: AppBar(
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
      ),
      body: CloudFolderGrid(
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
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(file.name)),
                body: CloudMediaViewer(
                  files: mediaSiblings,
                  initialIndex: mediaSiblings.indexOf(file),
                ),
              ),
            ),
          );
        },
        onNodeLongPress: (node, details) =>
            _showNodeMenu(node, details.globalPosition),
      ),
      floatingActionButton: widget.readOnly
          ? null
          : Wrap(
              direction: Axis.horizontal,
              spacing: 8,
              children: [
                FloatingActionButton(
                  heroTag: 'newFolder',
                  tooltip: 'Create folder',
                  onPressed: _createFolder,
                  child: const Icon(Icons.create_new_folder),
                ),
                FloatingActionButton(
                  heroTag: 'upload',
                  tooltip: 'Upload file',
                  onPressed: _uploadFile,
                  child: const Icon(Icons.note_add_outlined),
                ),
              ],
            ),
    );
  }

  // ── FAB actions ─────────────────────────────────────────────────────────

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _storage.createFolder(parentId: widget.folderId, name: name);
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final pathStr = picked.path;
    if (pathStr == null) return;

    final file = File(pathStr);

    // Generate thumbnails client-side. Returns null for non-media types
    // (PDFs, docs, etc.) — those upload without variants.
    final thumbnails = await generateThumbnails(file);

    final task = _storage.upload(
      parentId: widget.folderId,
      name: picked.name,
      source: FileSource(file),
      thumbnail: thumbnails == null ? null : BytesSource(thumbnails.thumb),
      preview: thumbnails == null ? null : BytesSource(thumbnails.preview),
    );

    // We only use `task.progress` for UI. If the user cancels, `task.result`
    // completes with an error; without a listener, that becomes an unhandled
    // zone error and Flutter treats it as a crash. `.ignore()` attaches a
    // no-op handler so the error is silently absorbed.
    task.result.ignore();

    if (!mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CloudUploadDialog(task: task),
      ),
    );
  }

  // ── Long-press popup menu + actions ────────────────────────────────────

  Future<void> _showNodeMenu(CloudNode node, Offset globalPos) async {
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
        if (isMedia || node is CloudFolder)
          const PopupMenuItem(
            value: 'open',
            child: ListTile(
              leading: Icon(Icons.open_in_new),
              title: Text('Open'),
            ),
          ),
        if (isFile)
          const PopupMenuItem(
            value: 'download',
            child: ListTile(
              leading: Icon(Icons.download),
              title: Text('Download'),
            ),
          ),
        if (canMutate)
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.drive_file_rename_outline),
              title: Text('Rename'),
            ),
          ),
        if (canMutate)
          const PopupMenuItem(
            value: 'move',
            child: ListTile(
              leading: Icon(Icons.drive_file_move),
              title: Text('Move to…'),
            ),
          ),
        const PopupMenuItem(
          value: 'info',
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Info'),
          ),
        ),
        if (canMutate) const PopupMenuDivider(),
        if (canMutate)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Delete'),
            ),
          ),
      ],
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case 'open':
        _openNode(node);
      case 'download':
        await _downloadFile(node as CloudFile);
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
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(node.name)),
            body: CloudMediaViewer(files: [node]),
          ),
        ),
      );
    }
  }

  Future<void> _downloadFile(CloudFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Downloading ${file.name}…')),
    );
    try {
      final localFile = await _storage.download(file.id);
      await Share.shareXFiles(
        [XFile(localFile.path, name: file.name)],
        subject: file.name,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _renameNode(CloudNode node) async {
    final controller = TextEditingController(text: node.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
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
    final target = await pickCloudFolder(
      context,
      storage: _storage,
      // For a folder move, exclude the folder itself. Descendants are
      // also invalid targets but aren't guarded here; the CloudStorage
      // impl or security rules should surface any resulting error.
      excludeFolderId: node is CloudFolder ? node.id : null,
      rootLabel: widget.rootLabel,
    );
    if (target == null || target == node.parentId) return;
    if (node is CloudFile) {
      await _storage.moveFile(node.id, newParentId: target);
    } else if (node is CloudFolder) {
      await _storage.moveFolder(node.id, newParentId: target);
    }
  }

  Future<void> _showInfo(CloudNode node) async {
    final rows = <MapEntry<String, String>>[
      MapEntry('Name', node.name),
      MapEntry('Type', node is CloudFolder ? 'Folder' : 'File'),
      MapEntry('Path', node.path.isEmpty ? '/' : node.path),
      MapEntry('Created', node.createdAt.toLocal().toString()),
      MapEntry('Updated', node.updatedAt.toLocal().toString()),
      if (node is CloudFile) MapEntry('MIME', node.mimeType),
      if (node is CloudFile) MapEntry('Size', _formatBytes(node.sizeBytes)),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNode(CloudNode node) async {
    final isFolder = node is CloudFolder;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${node.name}?'),
        content: Text(
          isFolder
              ? 'This will delete the folder and all its contents. This cannot be undone.'
              : 'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (node is CloudFile) {
      await _storage.deleteFile(node.id);
    } else if (node is CloudFolder) {
      await _storage.deleteFolder(node.id, recursive: true);
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}
