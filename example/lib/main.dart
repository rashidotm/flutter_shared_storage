import 'dart:async';
import 'dart:io';

import 'package:cloud_storage/cloud_storage.dart';
import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'firebase_options.dart';
import 'folder_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Anonymous sign-in keeps the demo dependency-free. The package itself is
  // auth-agnostic — sign in however your real app does.
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  // The package no longer assumes any particular layout — supply both
  // prefixes. Scoping by uid mirrors what most apps want.
  final storage = defaultCloudStorage(
    firestorePath: 'files',
    storagePath: 'files',
  );

  runApp(ExampleApp(storage: storage));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.storage});

  final CloudStorage storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cloud_storage example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      // MaterialApp creates its own Directionality from `locale`, so an outer
      // `Directionality(...)` wrapper is silently overridden. To force a
      // direction for testing, inject one via `builder` — it wraps every
      // route between MaterialApp's Directionality and the route content.
      // In a real app, just set `locale` / rely on the device locale.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: child!,
      ),
      home: FolderScreen(
        storage: storage,
        folderId: kRootFolderId,
      ),
    );
  }
}

class FolderScreen extends StatefulWidget {
  const FolderScreen({
    super.key,
    required this.storage,
    required this.folderId,
    this.initialChain,
  });

  final CloudStorage storage;
  final String folderId;

  /// Ancestor chain (root → ... → current). When null, the breadcrumb
  /// self-loads on first show — used for deep-links / cold start.
  final List<CloudNode>? initialChain;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  CloudStorage get _storage => widget.storage;

  /// Chain known for THIS screen. Passed down to child screens so their
  /// breadcrumb renders synchronously without a fetch.
  late final List<CloudNode>? _chain = widget.initialChain ?? (widget.folderId == kRootFolderId ? <CloudNode>[_syntheticRoot()] : null);

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
                builder: (_) => FolderScreen(
                  storage: _storage,
                  folderId: node.id,
                  initialChain: childChain,
                ),
              ),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CloudFolderGrid(
              storage: _storage,
              folderId: widget.folderId,
              onFolderTap: (folder) {
                // Append tapped folder to our known chain — child renders
                // its breadcrumb without any Firestore round-trip.
                final chain = _chain;
                final childChain = chain == null ? null : <CloudNode>[...chain, folder];
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FolderScreen(
                      storage: _storage,
                      folderId: folder.id,
                      initialChain: childChain,
                    ),
                  ),
                );
              },
              onFileTap: (file, mediaSiblings) {
                if (!file.isMedia) return;
                // CloudMediaViewer is headless — wrap it in a Scaffold so the
                // developer controls chrome (back button, title, actions).
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
              onNodeLongPress: (node, details) => _showNodeMenu(node, details.globalPosition),
            ),
          ),
        ],
      ),
      floatingActionButton: Wrap(
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
            child: const Icon(Icons.note_add),
          ),
        ],
      ),
    );
  }

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

    final task = _storage.upload(
      parentId: widget.folderId,
      name: picked.name,
      source: FileSource(File(pathStr)),
    );

    if (!mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UploadDialog(task: task),
      ),
    );
  }

  // ── Long-press popup menu + actions ─────────────────────────────────────

  Future<void> _showNodeMenu(CloudNode node, Offset globalPos) async {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(globalPos, globalPos),
      Offset.zero & overlay.size,
    );

    final isFile = node is CloudFile;
    final isMedia = isFile && node.isMedia;

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
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.drive_file_rename_outline),
            title: Text('Rename'),
          ),
        ),
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
        const PopupMenuDivider(),
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
          builder: (_) => FolderScreen(
            storage: _storage,
            folderId: node.id,
            initialChain: chain == null ? null : <CloudNode>[...chain, node],
          ),
        ),
      );
      return;
    }
    if (node is CloudFile && node.isMedia) {
      // Reuse the media viewer with just this file for simplicity.
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
    messenger.showSnackBar(SnackBar(content: Text('Downloading ${file.name}…')));
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
    final target = await pickFolder(
      context,
      storage: _storage,
      // For a folder move, exclude the folder itself (can't be moved into
      // itself). Descendants are also invalid targets but we don't fully
      // guard against them here — Firestore would surface the eventual bug.
      excludeFolderId: node is CloudFolder ? node.id : null,
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
          isFolder ? 'This will delete the folder and all its contents. This cannot be undone.' : 'This cannot be undone.',
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

class _UploadDialog extends StatelessWidget {
  const _UploadDialog({required this.task});
  final UploadTask task;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Uploading'),
      content: StreamBuilder<UploadProgress>(
        stream: task.progress,
        builder: (context, snap) {
          final p = snap.data;
          if (p == null) {
            return const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (p.isTerminal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            });
          }
          final fraction = p.fraction;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: fraction),
              const SizedBox(height: 8),
              Text(
                fraction == null ? '${p.bytesTransferred} bytes' : '${(fraction * 100).toStringAsFixed(0)}%',
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await task.cancel();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
