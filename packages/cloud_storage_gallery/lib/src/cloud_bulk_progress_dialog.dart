import 'package:flutter/material.dart';

import 'localizations/cloud_gallery_localizations.dart';

/// Generic progress dialog that iterates a list of [items] and calls
/// [operation] on each one in sequence. Shows a "X of N complete" bar
/// that updates after every item finishes, then auto-pops.
///
/// Individual failures are swallowed and counted as done — a single item
/// error doesn't abort the batch. If you need finer error handling,
/// aggregate failures inside your [operation] closure.
///
/// The Cancel button stops iteration BEFORE the next item begins; the
/// currently-in-flight operation completes normally.
class CloudBulkProgressDialog<T> extends StatefulWidget {
  const CloudBulkProgressDialog({
    super.key,
    required this.title,
    required this.items,
    required this.operation,
    this.cancelLabel,
  });

  final String title;
  final List<T> items;
  final Future<void> Function(T item) operation;
  final String? cancelLabel;

  @override
  State<CloudBulkProgressDialog<T>> createState() =>
      _CloudBulkProgressDialogState<T>();
}

class _CloudBulkProgressDialogState<T>
    extends State<CloudBulkProgressDialog<T>> {
  int _done = 0;
  bool _cancelled = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (final item in widget.items) {
      if (_cancelled) break;
      try {
        await widget.operation(item);
      } catch (_) {
        // Swallow per-item errors — count as done. Caller aggregates
        // failure info inside `operation` if it needs to.
      }
      if (!mounted) return;
      setState(() => _done++);
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _popOnce());
  }

  void _popOnce() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CloudGalleryLocalizations.of(context);
    final total = widget.items.length;
    final fraction = total == 0 ? 0.0 : _done / total;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 8),
          Text(l10n.bulkProgressLabel(_done, total)),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _cancelled ? null : () => setState(() => _cancelled = true),
          child: Text(widget.cancelLabel ?? l10n.buttonCancel),
        ),
      ],
    );
  }
}
