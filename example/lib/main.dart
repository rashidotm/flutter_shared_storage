import 'dart:async';
import 'dart:io';

import 'package:cloud_storage/cloud_storage.dart';
import 'package:cloud_storage_gallery/cloud_storage_gallery.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Anonymous sign-in keeps the demo dependency-free. The package itself is
  // auth-agnostic — sign in however your real app does.
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  final uid = FirebaseAuth.instance.currentUser!.uid;

  // The package no longer assumes any particular layout — supply both
  // prefixes. Scoping by uid mirrors what most apps want.
  final storage = defaultCloudStorage(
    firestorePath: 'users/$uid/nodes',
    storagePath: 'users/$uid/blobs',
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
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: FolderScreen(
        storage: storage,
        folderId: kRootFolderId,
        title: 'Home',
      ),
    );
  }
}

class FolderScreen extends StatefulWidget {
  const FolderScreen({
    super.key,
    required this.storage,
    required this.folderId,
    required this.title,
  });

  final CloudStorage storage;
  final String folderId;
  final String title;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  CloudStorage get _storage => widget.storage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          CloudFolderBreadcrumb(
            storage: _storage,
            folderId: widget.folderId,
            onNavigate: (node) {
              if (node.id == widget.folderId) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => FolderScreen(
                    storage: _storage,
                    folderId: node.id,
                    title: node.id == kRootFolderId ? 'Home' : node.name,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: CloudFolderGrid(
              storage: _storage,
              folderId: widget.folderId,
              onFolderTap: (folder) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FolderScreen(
                      storage: _storage,
                      folderId: folder.id,
                      title: folder.name,
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
              onFileLongPress: (node) async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Delete ${node.name}?'),
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
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Wrap(
        direction: Axis.vertical,
        spacing: 8,
        children: [
          FloatingActionButton.small(
            heroTag: 'newFolder',
            onPressed: _createFolder,
            child: const Icon(Icons.create_new_folder),
          ),
          FloatingActionButton(
            heroTag: 'upload',
            onPressed: _uploadFile,
            child: const Icon(Icons.upload_file),
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
