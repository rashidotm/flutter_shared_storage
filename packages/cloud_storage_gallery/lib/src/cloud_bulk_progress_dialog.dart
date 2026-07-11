import 'package:flutter/material.dart';

import 'localizations/cloud_gallery_localizations.dart';

/// Generic progress dialog that iterates a list of [items] and calls
/// [operation] on each one in sequence. Shows both a total "X of N
/// complete" bar AND a scrollable per-item list where each row renders
/// its own state (pending / in-progress / done / failed).
///
/// Individual failures are counted but don't abort the batch. Failed
/// rows get an error icon; successful rows get a check. Callers that
/// need finer error handling can aggregate inside their [operation]
/// closure.
///
/// The Cancel button stops iteration BEFORE the next item begins; the
/// currently-in-flight operation completes normally.
class CloudBulkProgressDialog<T> extends StatefulWidget {
  const CloudBulkProgressDialog({
    super.key,
    required this.title,
    required this.items,
    required this.operation,
    required this.itemLabel,
    this.cancelLabel,
  });

  final String title;
  final List<T> items;
  final Future<void> Function(T item) operation;

  /// Renders each item's display name in the per-item list.
  final String Function(T item) itemLabel;

  final String? cancelLabel;

  @override
  State<CloudBulkProgressDialog<T>> createState() =>
      _CloudBulkProgressDialogState<T>();
}

enum _RowState { pending, running, done, failed }

class _CloudBulkProgressDialogState<T>
    extends State<CloudBulkProgressDialog<T>> {
  late final List<_RowState> _rowStates;
  int _currentIndex = -1;
  bool _cancelled = false;
  bool _popped = false;
  final _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    _rowStates =
        List<_RowState>.filled(widget.items.length, _RowState.pending);
    _run();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    for (var i = 0; i < widget.items.length; i++) {
      if (_cancelled) break;
      setState(() {
        _currentIndex = i;
        _rowStates[i] = _RowState.running;
      });
      _scrollToCurrent();
      try {
        await widget.operation(widget.items[i]);
        if (!mounted) return;
        setState(() => _rowStates[i] = _RowState.done);
      } catch (_) {
        if (!mounted) return;
        setState(() => _rowStates[i] = _RowState.failed);
      }
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _popOnce());
  }

  void _scrollToCurrent() {
    if (!_listController.hasClients) return;
    // Estimate per-row height (dense ListTile). Enough to keep the
    // currently-running row visible without exact per-tile geometry.
    const rowHeight = 56.0;
    final target = (_currentIndex * rowHeight).clamp(
      _listController.position.minScrollExtent,
      _listController.position.maxScrollExtent,
    );
    _listController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _popOnce() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  int get _completedCount => _rowStates
      .where((s) => s == _RowState.done || s == _RowState.failed)
      .length;

  @override
  Widget build(BuildContext context) {
    final l10n = CloudGalleryLocalizations.of(context);
    final total = widget.items.length;
    // Single-item operations don't have a meaningful "X of N" progress
    // and there's nothing sensible to cancel once the one op has started,
    // so show an indeterminate bar without a count / cancel button.
    final isSingle = total == 1;
    final done = _completedCount;
    final fraction = total == 0 ? 0.0 : done / total;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: isSingle ? null : fraction),
            if (!isSingle) ...[
              const SizedBox(height: 8),
              Text(l10n.bulkProgressLabel(done, total)),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  controller: _listController,
                  shrinkWrap: true,
                  itemCount: total,
                  itemBuilder: (context, i) => _BulkRow(
                    name: widget.itemLabel(widget.items[i]),
                    state: _rowStates[i],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: isSingle
          ? null
          : [
              TextButton(
                onPressed: _cancelled
                    ? null
                    : () => setState(() => _cancelled = true),
                child: Text(widget.cancelLabel ?? l10n.buttonCancel),
              ),
            ],
    );
  }
}

class _BulkRow extends StatelessWidget {
  const _BulkRow({required this.name, required this.state});

  final String name;
  final _RowState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: SizedBox(
        width: 24,
        height: 24,
        child: switch (state) {
          _RowState.pending => Icon(
              Icons.radio_button_unchecked,
              color: scheme.onSurfaceVariant,
            ),
          _RowState.running =>
            const CircularProgressIndicator(strokeWidth: 2),
          _RowState.done => Icon(Icons.check_circle, color: scheme.primary),
          _RowState.failed =>
            Icon(Icons.error_outline, color: scheme.error),
        },
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
