import 'dart:async';
import 'dart:io';

import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cloud_batch_upload_dialog.dart';
import 'cloud_bulk_progress_dialog.dart';
import 'cloud_folder_grid.dart';
import 'cloud_folder_picker.dart';
import 'cloud_media_viewer.dart';
import 'cloud_node_sort.dart';
import 'cloud_path_bar.dart';
import 'cloud_upload_dialog.dart';
import 'localizations/cloud_gallery_localizations.dart';
import 'thumbnail_generator.dart';

/// Sentinel values emitted from the sort popup for the two non-field
/// toggles. Field values are [CloudNodeSortField] enum members
/// directly.
enum _SortMenuAction { toggleDirection, toggleFoldersFirst }

/// A ready-to-use, full-featured folder browser backed by [CloudStorage].
///
/// **Embeddable, not a page.** The widget is not a `Scaffold` and does
/// not host `ScaffoldMessenger` snackbars itself — put it anywhere in
/// your widget tree. Wrap it in your own `Scaffold` when using it as a
/// top-level screen; drop it inside a tab, a split-view pane, or a
/// sheet without wrapping.
///
/// **Self-navigating.** Tapping a subfolder does NOT push a new route
/// — it updates the current folder in place. An internal history stack
/// backs the [CloudPathBar]'s back button, and the OS back button is
/// intercepted via `PopScope` to walk that history before propagating
/// to the outer navigator.
///
/// Ships with everything a typical file-manager screen needs:
///
///   * Optional in-body AppBar via [appBar]
///   * Path bar beneath the AppBar — current path + back/up buttons
///   * Grid of subfolders + files (with thumbnails when available)
///   * Long-press context menu — Open, Download, Rename, Move to…, Info,
///     Delete
///   * FABs — Select / Create folder / Add link / Upload, positioned
///     bottom-end via a `Stack` overlay (no Scaffold slot needed)
///   * Upload progress dialog with a Cancel button
///
/// If you want a completely different UX, build your own screen using
/// the lower-level widgets ([CloudFolderGrid], [CloudPathBar],
/// [CloudFolderBreadcrumb], [CloudMediaViewer], [CloudUploadDialog],
/// [pickCloudFolder], [generateThumbnails]).
class CloudFolderScreen extends StatefulWidget {
  const CloudFolderScreen({
    super.key,
    required this.storage,
    this.folderId = kRootFolderId,
    this.initialChain,
    this.appBar,
    this.rootLabel,
    this.readOnly = false,
  });

  final CloudStorage storage;

  /// The folder to start on. The screen then manages its own internal
  /// navigation (folder taps, back, up) without pushing routes.
  final String folderId;

  /// Ancestor chain (root → ... → [folderId]) as a cold-start hint.
  /// When null, the chain is fetched on first show.
  final List<CloudNode>? initialChain;

  /// Optional AppBar to render above the built-in path bar. Consumers
  /// wire this to whatever they need — title, theme actions, back to
  /// their outer navigator. Passing null renders the widget without an
  /// AppBar (the path bar becomes the top of the screen).
  final PreferredSizeWidget? appBar;

  /// Label shown for the root folder in the path bar breadcrumb. When
  /// null, the localized default (`CloudGalleryLocalizations.of(context)
  /// .rootLabel`) is used.
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

  /// Folder currently in view. Mutated by [_navigateTo] — replaces the
  /// pre-refactor pattern of pushing a new route per folder.
  late String _currentFolderId = widget.folderId;

  /// Ancestor chain (root → ... → current). Kept in sync with
  /// [_currentFolderId] by [_navigateTo]. Nullable to signal "not yet
  /// loaded" during the first fetch.
  late List<CloudNode>? _chain = widget.initialChain ??
      (widget.folderId == kRootFolderId
          ? <CloudNode>[_syntheticRoot()]
          : null);

  /// Internal navigation history for the path bar's back button. Each
  /// entry is a snapshot of `_chain` — never just an id — so going back
  /// restores the chain without a refetch. Stack behavior: most recent
  /// on the end.
  final List<List<CloudNode>> _history = <List<CloudNode>>[];

  /// Current sort. Session-scoped — resets to default when the widget
  /// is recreated.
  CloudNodeSort _sort = const CloudNodeSort();

  static CloudFolder _syntheticRoot() => CloudFolder(
        id: kRootFolderId,
        name: '',
        parentId: '',
        path: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  void initState() {
    super.initState();
    // If the caller landed us on a non-root folder without an
    // initialChain, resolve it once so the path bar can render the full
    // path. Fire-and-forget — the path bar shows the root as a
    // placeholder in the meantime.
    if (_chain == null) {
      _loadChainFor(_currentFolderId);
    }
  }

  Future<void> _loadChainFor(String folderId) async {
    try {
      if (folderId == kRootFolderId) {
        final root = await _storage.getNode(kRootFolderId);
        if (!mounted || _currentFolderId != folderId) return;
        setState(() => _chain = <CloudNode>[root]);
        return;
      }
      final tail = <CloudNode>[];
      var current = await _storage.getNode(folderId);
      tail.add(current);
      while (current.parentId.isNotEmpty) {
        current = await _storage.getNode(current.parentId);
        tail.add(current);
      }
      final root = await _storage.getNode(kRootFolderId);
      if (!mounted || _currentFolderId != folderId) return;
      setState(() => _chain = <CloudNode>[root, ...tail.reversed]);
    } catch (_) {
      // Best-effort: leave _chain null if we can't resolve. Path bar
      // still renders the root placeholder — no user-facing crash.
    }
  }

  // ── Internal navigation ─────────────────────────────────────────────────

  /// Push [newChain] onto the history and jump to its tail folder.
  /// Selection is always cleared — carrying selected IDs from folder A
  /// into folder B is confusing (they're not visible in the new grid).
  void _navigateTo(List<CloudNode> newChain) {
    final currentChain = _chain;
    if (currentChain != null) {
      _history.add(currentChain);
    }
    setState(() {
      _chain = newChain;
      _currentFolderId = newChain.last.id;
      _selectionActive = false;
      _selected.clear();
    });
  }

  /// Enter a subfolder. The chain is extended by one — fast path, no
  /// refetch.
  void _openSubfolder(CloudFolder folder) {
    final currentChain = _chain;
    if (currentChain == null) return;
    _navigateTo(<CloudNode>[...currentChain, folder]);
  }

  /// Jump to any ancestor in the current chain (or the current folder
  /// itself — that's a no-op).
  void _jumpToAncestor(CloudNode node) {
    final chain = _chain;
    if (chain == null) return;
    if (node.id == _currentFolderId) return;
    final idx = chain.indexWhere((n) => n.id == node.id);
    if (idx < 0) return;
    _navigateTo(chain.sublist(0, idx + 1));
  }

  /// Go to the parent of the current folder. No-op at root.
  bool get _canGoUp {
    final chain = _chain;
    return chain != null && chain.length > 1;
  }

  void _goUp() {
    final chain = _chain;
    if (chain == null || chain.length < 2) return;
    _navigateTo(chain.sublist(0, chain.length - 1));
  }

  /// Restore the previous chain from history.
  bool get _canGoBack => _history.isNotEmpty;

  void _goBack() {
    if (_history.isEmpty) return;
    final prev = _history.removeLast();
    setState(() {
      _chain = prev;
      _currentFolderId = prev.last.id;
      _selectionActive = false;
      _selected.clear();
    });
  }

  // ── Selection mode ─────────────────────────────────────────────────────

  /// Currently-selected nodes keyed by id. Kept as a map so bulk operations
  /// don't have to re-fetch each node from Firestore just to know whether
  /// it's a file, folder, or link.
  final Map<String, CloudNode> _selected = <String, CloudNode>{};

  /// True whenever the user is browsing in selection mode — either because
  /// they long-pressed → Select on a node, or tapped the "Select items"
  /// FAB. Independent of whether [_selected] has any entries yet, so the
  /// user can enter selection mode with zero items and then tap tiles to
  /// pick.
  bool _selectionActive = false;

  bool get _inSelectionMode => _selectionActive;

  void _toggleSelection(CloudNode node) {
    setState(() {
      if (_selected.containsKey(node.id)) {
        _selected.remove(node.id);
      } else {
        _selected[node.id] = node;
      }
    });
  }

  void _enterSelection([CloudNode? node]) {
    setState(() {
      _selectionActive = true;
      if (node != null) _selected[node.id] = node;
    });
  }

  void _clearSelection() {
    if (!_selectionActive && _selected.isEmpty) return;
    setState(() {
      _selectionActive = false;
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CloudGalleryLocalizations.of(context);
    // Intercept the OS/hardware back button: if we have internal history
    // to unwind, consume the pop and step back. Otherwise let the pop
    // propagate up so the caller's Navigator can close this route.
    return PopScope(
      canPop: !_canGoBack && !_inSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_inSelectionMode) {
          _clearSelection();
        } else if (_canGoBack) {
          _goBack();
        }
      },
      // Not a Scaffold — the widget is embeddable. Consumers wrap it in
      // their own Scaffold (or don't) as they see fit. SnackBars still
      // work as long as a ScaffoldMessenger is available higher up
      // (MaterialApp provides one by default).
      child: SafeArea(
        top: widget.appBar == null,
        child: Column(
          children: [
            if (widget.appBar != null) widget.appBar!,
            // Top-of-body chrome: path bar in browse mode, selection
            // header in selection mode. Same slot — swapping avoids
            // shifting the grid.
            _inSelectionMode
                ? _buildSelectionBar(l10n)
                : CloudPathBar(
                    storage: _storage,
                    folderId: _currentFolderId,
                    chain: _chain,
                    rootLabel: widget.rootLabel,
                    onBack: _canGoBack ? _goBack : null,
                    onUp: _canGoUp ? _goUp : null,
                    onNavigate: _jumpToAncestor,
                    trailing: [_buildSortMenu(l10n)],
                  ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CloudFolderGrid(
                      storage: _storage,
                      folderId: _currentFolderId,
                      sort: _sort,
                      onFolderTap: _openSubfolder,
                      onFileTap: (file, mediaSiblings) {
                        if (file.isMedia) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _MediaViewerScaffold(
                                files: mediaSiblings,
                                initialIndex: mediaSiblings.indexOf(file),
                              ),
                            ),
                          );
                          return;
                        }
                        // Non-media (PDF, docs, etc.): download + hand off
                        // to the OS.
                        _openFileExternally(file);
                      },
                      onLinkTap: _openLink,
                      onNodeLongPress: (node, details) =>
                          _showNodeMenu(node, details.globalPosition),
                      selectionMode: _selectionActive,
                      selectedNodeIds: _selected.keys.toSet(),
                      onNodeToggleSelection:
                          widget.readOnly ? null : _toggleSelection,
                    ),
                  ),
                  // FABs positioned bottom-end of the grid area — same
                  // visual position as Scaffold's endFloat FAB slot, but
                  // no Scaffold needed. Directional so it flips in RTL.
                  if (!widget.readOnly)
                    PositionedDirectional(
                      bottom: 16,
                      end: 16,
                      child: _inSelectionMode
                          ? _buildSelectionFabs(l10n)
                          : _buildBrowseFabs(l10n),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Browse-mode FAB cluster — Select / New folder / Add link / Upload.
  Widget _buildBrowseFabs(CloudGalleryLocalizations l10n) {
    return Wrap(
      direction: Axis.horizontal,
      spacing: 8,
      children: [
        FloatingActionButton(
          heroTag: 'select',
          tooltip: l10n.menuSelect,
          onPressed: () => _enterSelection(),
          child: const Icon(Icons.checklist),
        ),
        FloatingActionButton(
          heroTag: 'newFolder',
          tooltip: l10n.createFolderTooltip,
          onPressed: _createFolder,
          child: const Icon(Icons.create_new_folder),
        ),
        FloatingActionButton(
          heroTag: 'addLink',
          tooltip: l10n.addLinkTooltip,
          onPressed: _createLink,
          child: const Icon(Icons.add_link),
        ),
        FloatingActionButton(
          heroTag: 'upload',
          tooltip: l10n.uploadFileTooltip,
          onPressed: _uploadFile,
          child: const Icon(Icons.note_add_outlined),
        ),
      ],
    );
  }

  /// Trailing sort selector for the path bar. Popup menu with radio
  /// options for the field, a divider, a direction toggle, and a
  /// folders-first toggle. The whole thing writes back into [_sort].
  Widget _buildSortMenu(CloudGalleryLocalizations l10n) {
    String fieldLabel(CloudNodeSortField f) => switch (f) {
          CloudNodeSortField.name => l10n.sortFieldName,
          CloudNodeSortField.createdAt => l10n.sortFieldDateCreated,
          CloudNodeSortField.updatedAt => l10n.sortFieldDateModified,
          CloudNodeSortField.size => l10n.sortFieldSize,
          CloudNodeSortField.type => l10n.sortFieldType,
        };
    return PopupMenuButton<Object>(
      tooltip: l10n.sortTooltip,
      icon: const Icon(Icons.sort),
      itemBuilder: (context) => <PopupMenuEntry<Object>>[
        PopupMenuItem<Object>(
          enabled: false,
          child: Text(
            l10n.sortByHeader,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        for (final f in CloudNodeSortField.values)
          CheckedPopupMenuItem<Object>(
            value: f,
            checked: _sort.field == f,
            child: Text(fieldLabel(f)),
          ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<Object>(
          value: _SortMenuAction.toggleDirection,
          checked: !_sort.ascending,
          child: Text(
            _sort.ascending
                ? l10n.sortDirectionAscending
                : l10n.sortDirectionDescending,
          ),
        ),
        CheckedPopupMenuItem<Object>(
          value: _SortMenuAction.toggleFoldersFirst,
          checked: _sort.foldersFirst,
          child: Text(l10n.sortFoldersFirst),
        ),
      ],
      onSelected: (value) {
        setState(() {
          if (value is CloudNodeSortField) {
            _sort = _sort.copyWith(field: value);
          } else if (value == _SortMenuAction.toggleDirection) {
            _sort = _sort.copyWith(ascending: !_sort.ascending);
          } else if (value == _SortMenuAction.toggleFoldersFirst) {
            _sort = _sort.copyWith(foldersFirst: !_sort.foldersFirst);
          }
        });
      },
    );
  }

  /// Top-of-body chrome in selection mode. Same slot as [CloudPathBar];
  /// swapping keeps the grid below at a fixed offset. Bulk actions live
  /// in the FAB — see [_buildSelectionFabs].
  Widget _buildSelectionBar(CloudGalleryLocalizations l10n) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                l10n.selectionCountLabel(_selected.length),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bulk-action FABs that take over the FAB slot while selection mode is
  // active. Placed exactly where the browse-mode FABs sat, so the user's
  // thumb doesn't have to reach for the app bar after a long-press.
  Widget _buildSelectionFabs(CloudGalleryLocalizations l10n) {
    final hasSelection = _selected.isNotEmpty;
    return Wrap(
      direction: Axis.horizontal,
      spacing: 8,
      children: [
        FloatingActionButton(
          heroTag: 'bulkMove',
          tooltip: l10n.menuMoveTo,
          onPressed: hasSelection ? _bulkMove : null,
          child: const Icon(Icons.drive_file_move),
        ),
        FloatingActionButton(
          heroTag: 'bulkDelete',
          tooltip: l10n.menuDelete,
          onPressed: hasSelection ? _bulkDelete : null,
          child: const Icon(Icons.delete_outline),
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
    await _storage.createFolder(parentId: _currentFolderId, name: name);
  }

  Future<void> _uploadFile() async {
    final l10n = CloudGalleryLocalizations.of(context);
    final result =
        await FilePicker.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    // Filter out picks without a real filesystem path (some pickers can
    // hand back streams-only entries).
    final picked = result.files
        .where((f) => f.path != null)
        .toList(growable: false);
    if (picked.isEmpty || !mounted) return;

    // Phase 1: generate thumbnails per file. Runs while a per-item
    // progress dialog is on screen — without this, large batches would
    // block for several seconds after the picker closed with no
    // feedback. Thumbnails are collected side-by-side with the source
    // file so phase 2 has everything it needs.
    final prepared = <_PreparedUpload>[];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloudBulkProgressDialog<PlatformFile>(
        title: l10n.preparingUploadsTitle,
        items: picked,
        itemLabel: (f) => f.name,
        operation: (entry) async {
          final file = File(entry.path!);
          // Returns null for non-media types (PDFs, docs, etc.) — those
          // upload without variants.
          final thumbnails = await generateThumbnails(file);
          prepared.add(_PreparedUpload(entry, file, thumbnails));
        },
      ),
    );

    if (!mounted || prepared.isEmpty) return;

    // Phase 2: kick off upload tasks and show the batch upload dialog.
    // Uploads only start now, so a cancel in phase 1 never leaves
    // half-started uploads dangling.
    final tasks = <UploadTask>[];
    for (final entry in prepared) {
      final task = _storage.upload(
        parentId: _currentFolderId,
        name: entry.picked.name,
        source: FileSource(entry.file),
        thumbnail: entry.thumbnails == null
            ? null
            : BytesSource(entry.thumbnails!.thumb),
        preview: entry.thumbnails == null
            ? null
            : BytesSource(entry.thumbnails!.preview),
      );
      // If a user cancels, `task.result` completes with an error;
      // without a listener that becomes an unhandled zone error and
      // Flutter treats it as a crash. `.ignore()` attaches a no-op
      // handler that absorbs it.
      task.result.ignore();
      tasks.add(task);
    }

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
    final isLink = node is CloudLink;
    // Files and links can carry a custom thumbnail; folders can't.
    final canHaveThumbnail = isFile || isLink;

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
        if (isMedia || node is CloudFolder || isLink)
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
        if (canHaveThumbnail && canMutate)
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
        await _setThumbnail(node);
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
      // In-place navigation — no route push. Selection is cleared inside
      // [_openSubfolder] so a long-press → "Open" from selection mode
      // exits cleanly into the child folder.
      _openSubfolder(node);
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
      return;
    }
    if (node is CloudLink) {
      unawaited(_openLink(node));
    }
  }

  /// Downloads [file] to the local cache and hands it off to the OS
  /// default handler via `open_filex`. If no compatible app is installed
  /// (or the platform can't route directly), falls back to the OS share
  /// sheet so the user can pick a target app themselves.
  Future<void> _openFileExternally(CloudFile file) async {
    final l10n = CloudGalleryLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloudBulkProgressDialog<CloudFile>(
        title: l10n.openingTitle,
        items: [file],
        itemLabel: (f) => f.name,
        operation: (f) async {
          final localFile = await _storage.download(f.id);
          final result = await OpenFilex.open(
            localFile.path,
            type: f.mimeType.isEmpty ? null : f.mimeType,
          );
          if (result.type != ResultType.done) {
            // Fallback: hand the file to the OS share sheet so the user
            // can pick an app. Also gracefully handles the "no app
            // installed" case reported by open_filex on some devices.
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile(localFile.path, name: f.name)],
                subject: f.name,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _downloadFile(CloudFile file) async {
    final l10n = CloudGalleryLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.downloadingSnack(file.name))),
    );
    try {
      final localFile = await _storage.download(file.id);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(localFile.path, name: file.name)],
          subject: file.name,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.downloadFailedSnack(e))),
      );
    }
  }

  Future<void> _setThumbnail(CloudNode node) async {
    if (node is CloudFolder) return;
    final l10n = CloudGalleryLocalizations.of(context);
    final result = await FilePicker.pickFiles(type: FileType.image);
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
      builder: (_) => CloudBulkProgressDialog<CloudNode>(
        title: l10n.uploadingTitle,
        items: [node],
        itemLabel: (n) => n.name,
        operation: (n) async {
          await _storage.setThumbnail(
            n.id,
            thumbnail: BytesSource(thumbnails.thumb),
            preview: BytesSource(thumbnails.preview),
          );
        },
      ),
    );
  }

  // ── Link actions ────────────────────────────────────────────────────────

  Future<void> _createLink() async {
    final l10n = CloudGalleryLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final result = await showDialog<({String name, String url})>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.newLinkTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.linkNameLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: l10n.linkUrlLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              (name: nameCtrl.text.trim(), url: urlCtrl.text.trim()),
            ),
            child: Text(l10n.buttonCreate),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result.name.isEmpty || result.url.isEmpty) return;
    await _storage.createLink(
      parentId: _currentFolderId,
      name: result.name,
      url: _normalizeUrl(result.url),
    );
  }

  Future<void> _openLink(CloudLink link) async {
    final l10n = CloudGalleryLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(_normalizeUrl(link.url));
    if (uri == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.linkOpenFailedSnack(link.url))),
      );
      return;
    }
    // Don't gate on `canLaunchUrl` — on Android 11+ it returns false
    // unless the host app declares matching <queries> in its manifest,
    // even when launching would actually succeed. `launchUrl` itself
    // handles the missing-handler case by returning false / throwing.
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.linkOpenFailedSnack(link.url))),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.linkOpenFailedSnack(link.url))),
      );
    }
  }

  /// Ensures a URL has a scheme so `launchUrl` can dispatch it correctly.
  static String _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed)) return trimmed;
    return 'https://$trimmed';
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
    } else if (node is CloudLink) {
      await _storage.renameLink(node.id, newName);
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
        itemLabel: (n) => n.name,
        operation: (n) async {
          if (n is CloudFile) {
            await _storage.moveFile(n.id, newParentId: target);
          } else if (n is CloudFolder) {
            await _storage.moveFolder(n.id, newParentId: target);
          } else if (n is CloudLink) {
            await _storage.moveLink(n.id, newParentId: target);
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
        switch (node) {
          CloudFolder() => l10n.infoTypeFolder,
          CloudLink() => 'Link',
          CloudFile() => l10n.infoTypeFile,
        },
      ),
      MapEntry(l10n.infoLabelPath, node.path.isEmpty ? '/' : node.path),
      MapEntry(l10n.infoLabelCreated, node.createdAt.toLocal().toString()),
      MapEntry(l10n.infoLabelUpdated, node.updatedAt.toLocal().toString()),
      if (node is CloudFile) MapEntry(l10n.infoLabelMime, node.mimeType),
      if (node is CloudFile)
        MapEntry(l10n.infoLabelSize, _formatBytes(node.sizeBytes, l10n)),
      if (node is CloudLink) MapEntry(l10n.infoLabelUrl, node.url),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
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
        itemLabel: (n) => n.name,
        operation: (n) async {
          if (n is CloudFile) {
            await _storage.deleteFile(n.id);
          } else if (n is CloudFolder) {
            await _storage.deleteFolder(n.id, recursive: true);
          } else if (n is CloudLink) {
            await _storage.deleteLink(n.id);
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
        itemLabel: (n) => n.name,
        operation: (node) async {
          if (node is CloudFile) {
            await _storage.deleteFile(node.id);
          } else if (node is CloudFolder) {
            await _storage.deleteFolder(node.id, recursive: true);
          } else if (node is CloudLink) {
            await _storage.deleteLink(node.id);
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
        itemLabel: (n) => n.name,
        operation: (node) async {
          if (node is CloudFile) {
            await _storage.moveFile(node.id, newParentId: target);
          } else if (node is CloudFolder) {
            await _storage.moveFolder(node.id, newParentId: target);
          } else if (node is CloudLink) {
            await _storage.moveLink(node.id, newParentId: target);
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

/// Package-private wrapper carrying a picked entry together with its
/// generated thumbnails, so the upload phase doesn't have to redo the
/// thumbnail work.
class _PreparedUpload {
  const _PreparedUpload(this.picked, this.file, this.thumbnails);

  final PlatformFile picked;
  final File file;
  final MediaThumbnails? thumbnails;
}
