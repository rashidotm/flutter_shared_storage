import 'dart:async';

import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

import 'localizations/cloud_gallery_localizations.dart';

/// Progress dialog for a batch of concurrent uploads. Shows a single
/// "X of N complete" progress bar and a cancel-all button.
///
/// Pops itself when every task in [tasks] has reached a terminal state
/// (success, canceled, or error). The Cancel button and the auto-pop are
/// guarded with a single-fire flag so the underlying route isn't popped
/// twice.
class CloudBatchUploadDialog extends StatefulWidget {
  const CloudBatchUploadDialog({
    super.key,
    required this.tasks,
    this.title,
    this.cancelLabel,
  });

  final List<UploadTask> tasks;

  /// Dialog title. When null, uses the localized default.
  final String? title;

  /// Cancel button label. When null, uses the localized default.
  final String? cancelLabel;

  @override
  State<CloudBatchUploadDialog> createState() => _CloudBatchUploadDialogState();
}

class _CloudBatchUploadDialogState extends State<CloudBatchUploadDialog> {
  final _subs = <StreamSubscription<UploadProgress>>[];

  /// Count of tasks that have reached ANY terminal state (success, canceled,
  /// or error). The dialog auto-pops when this equals `widget.tasks.length`.
  int _completed = 0;

  bool _popped = false;

  @override
  void initState() {
    super.initState();
    for (final task in widget.tasks) {
      // Prevent unhandled Future errors on individual tasks — the dialog
      // only cares about progress. Errors are reflected in the completion
      // count via the terminal progress event.
      task.result.ignore();
      _subs.add(
        task.progress.listen((p) {
          if (p.isTerminal) {
            setState(() => _completed++);
            if (_completed >= widget.tasks.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _popOnce());
            }
          } else {
            setState(() {});
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _popOnce() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CloudGalleryLocalizations.of(context);
    final total = widget.tasks.length;
    final fraction = total == 0 ? 0.0 : _completed / total;
    return AlertDialog(
      title: Text(widget.title ?? l10n.uploadingTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 8),
          Text(l10n.bulkProgressLabel(_completed, total)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Cancel every not-yet-terminal task. Individual `cancel()`
            // calls tolerate already-finished tasks — safe to call on all.
            await Future.wait(widget.tasks.map((t) => t.cancel()));
            _popOnce();
          },
          child: Text(widget.cancelLabel ?? l10n.buttonCancel),
        ),
      ],
    );
  }
}
