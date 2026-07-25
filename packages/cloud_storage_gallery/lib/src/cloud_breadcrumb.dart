import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

import 'localizations/cloud_gallery_localizations.dart';

/// Renders a `/foo/bar/baz` style breadcrumb for the current folder, with
/// each segment tappable.
///
/// If [chain] is supplied, it's used verbatim — no async work, immediate
/// render. This is the fast path: parents that already know the ancestor
/// chain (e.g. because they computed it when navigating into this folder)
/// should pass it in.
///
/// If [chain] is null, the breadcrumb self-loads by walking `parentId` from
/// [folderId] up to root via [storage.getNode]. Once loaded, the chain is
/// cached and retained across rebuilds and mid-navigation loads to avoid
/// flashes of empty space.
class CloudFolderBreadcrumb extends StatefulWidget {
  const CloudFolderBreadcrumb({
    super.key,
    required this.storage,
    required this.folderId,
    required this.onNavigate,
    this.chain,
    this.rootLabel,
    this.foregroundColor,
    this.scrollToCurrent = true,
  });

  final CloudStorage storage;
  final String folderId;

  /// Pre-computed ancestor chain (root → ... → current). When supplied,
  /// no fetching happens.
  final List<CloudNode>? chain;

  /// Called with the [CloudFolder] (or a synthetic root) to navigate to.
  final void Function(CloudNode folder) onNavigate;

  /// Label shown for the root segment. When null, the localized default
  /// (`CloudGalleryLocalizations.of(context).rootLabel`) is used.
  final String? rootLabel;

  /// Override for both the segment text color and the separator chevron
  /// color. When null (default), the segments inherit their color from
  /// `theme.textTheme.titleMedium` and the chevron from the ambient
  /// `IconTheme`. Pass this when the breadcrumb sits on a coloured
  /// background (e.g. the move-to picker paints its list area with
  /// `colorScheme.primary`, and the segments render in `onPrimary`).
  final Color? foregroundColor;

  /// When true (default), the internal scroll view snaps to the end of
  /// the chain each time the folder or chain changes, keeping the
  /// current folder visible on long paths. Set to false to keep the
  /// scroll pinned at the start — the root segment stays at the row's
  /// leading edge regardless of depth.
  final bool scrollToCurrent;

  @override
  State<CloudFolderBreadcrumb> createState() => _CloudFolderBreadcrumbState();
}

class _CloudFolderBreadcrumbState extends State<CloudFolderBreadcrumb> {
  /// Last-known chain — retained across rebuilds so we don't flash empty
  /// while a new chain loads. `null` only before the very first resolve.
  List<CloudNode>? _chain;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.chain != null) {
      _chain = widget.chain;
    } else {
      _load();
    }
    _scheduleScrollToEnd();
  }

  @override
  void didUpdateWidget(CloudFolderBreadcrumb old) {
    super.didUpdateWidget(old);
    if (widget.chain != null && !identical(widget.chain, old.chain)) {
      setState(() => _chain = widget.chain);
      _scheduleScrollToEnd();
    } else if (widget.chain == null &&
        (old.folderId != widget.folderId || old.storage != widget.storage)) {
      _load();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final chain = await _ancestorChain();
    if (!mounted) return;
    // Guard against a stale response: if folderId changed while we were
    // fetching, discard the result — a newer _load() is in flight.
    if (chain.isEmpty || chain.last.id != widget.folderId) return;
    setState(() => _chain = chain);
    _scheduleScrollToEnd();
  }

  /// Nudge the scroll view to reveal the current folder (end of the chain)
  /// after the next layout. Short chains that fit have maxScrollExtent == 0
  /// so this is a no-op; long chains snap to their end. Skipped when the
  /// caller opts out via [CloudFolderBreadcrumb.scrollToCurrent].
  void _scheduleScrollToEnd() {
    if (!widget.scrollToCurrent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max > 0) _scrollController.jumpTo(max);
    });
  }

  Future<List<CloudNode>> _ancestorChain() async {
    final root = await widget.storage.getNode(kRootFolderId);
    if (widget.folderId == kRootFolderId) return [root];
    final tail = <CloudNode>[];
    var current = await widget.storage.getNode(widget.folderId);
    tail.add(current);
    while (current.parentId.isNotEmpty) {
      current = await widget.storage.getNode(current.parentId);
      tail.add(current);
    }
    return [root, ...tail.reversed];
  }

  @override
  Widget build(BuildContext context) {
    // Icons.chevron_right carries `matchTextDirection: true`, so the
    // Icon widget auto-mirrors it based on the ambient Directionality
    // — natural `>` in LTR, flipped to `<` in RTL. Do NOT swap to
    // Icons.chevron_left in RTL: that icon also has matchTextDirection
    // set, and combining a manual swap with the auto-mirror ends up
    // double-flipping and putting `>` back on screen.
    final rootLabel =
        widget.rootLabel ?? CloudGalleryLocalizations.of(context).rootLabel;
    // Placed inside an AppBar.title the ambient DefaultTextStyle is
    // titleLarge; when used stand-alone it's the inherited body style.
    // Either way, deriving from the current textTheme makes the intent
    // explicit and keeps the fontWeight override obvious.
    final ambient = Theme.of(context).textTheme.titleMedium;
    final baseStyle = widget.foregroundColor == null
        ? ambient
        : ambient?.copyWith(color: widget.foregroundColor);

    // While the very first load is in flight, show the root label alone —
    // still meaningful, still tappable, no visible "empty then populated"
    // pop-in. On subsequent navigations, `_chain` retains the old value
    // until the new one arrives.
    final chain = _chain ??
        <CloudNode>[
          CloudFolder(
            id: kRootFolderId,
            name: '',
            parentId: '',
            path: '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ];

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < chain.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: widget.foregroundColor,
                ),
              ),
            InkWell(
              onTap: () => widget.onNavigate(chain[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Text(
                  i == 0 ? rootLabel : chain[i].name,
                  style: baseStyle?.copyWith(
                    fontWeight: i == chain.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
