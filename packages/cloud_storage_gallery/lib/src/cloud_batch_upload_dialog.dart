import 'dart:async';

import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

import 'localizations/cloud_gallery_localizations.dart';

/// Progress dialog for a batch of concurrent uploads. Shows a total
/// "X of N complete" bar at the top and a scrollable per-file list
/// where each row renders its own byte-level progress bar and terminal
/// state (success / cancelled / error).
///
/// Pops itself when every task in [tasks] has reached a terminal state
/// (success, canceled, or error). The Cancel button cancels every
/// not-yet-terminal task and then pops.
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
  late final List<UploadProgress?> _last;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _last = List<UploadProgress?>.filled(widget.tasks.length, null);
    for (var i = 0; i < widget.tasks.length; i++) {
      final task = widget.tasks[i];
      // Prevent unhandled Future errors on individual tasks — the dialog
      // only cares about progress.
      task.result.ignore();
      _subs.add(
        task.progress.listen((p) {
          if (!mounted) return;
          setState(() => _last[i] = p);
          if (_last.every((v) => v != null && v.isTerminal)) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _popOnce());
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

  int get _completedCount =>
      _last.where((p) => p != null && p.isTerminal).length;

  @override
  Widget build(BuildContext context) {
    final l10n = CloudGalleryLocalizations.of(context);
    final total = widget.tasks.length;
    final done = _completedCount;
    final fraction = total == 0 ? 0.0 : done / total;
    return AlertDialog(
      title: Text(widget.title ?? l10n.uploadingTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: fraction),
            const SizedBox(height: 8),
            Text(l10n.bulkProgressLabel(done, total)),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: total,
                  itemBuilder: (context, i) => _UploadRow(
                    task: widget.tasks[i],
                    last: _last[i],
                  ),
                ),
              ),
            ),
          ],
        ),
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

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.task, required this.last});

  final UploadTask task;
  final UploadProgress? last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = last;
    // Byte progress is optional (total may be unknown early). Null means
    // the bar renders indeterminate.
    // Byte progress is optional — fraction is null when totalBytes is
    // unknown (e.g. streaming source).
    final byteFraction = p?.fraction;
    final Widget leading = switch (p?.status) {
      null => Icon(
          Icons.radio_button_unchecked,
          color: scheme.onSurfaceVariant,
        ),
      UploadStatus.running || UploadStatus.paused => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      UploadStatus.success => Icon(Icons.check_circle, color: scheme.primary),
      UploadStatus.canceled => Icon(
          Icons.cancel_outlined,
          color: scheme.onSurfaceVariant,
        ),
      UploadStatus.error => Icon(Icons.error_outline, color: scheme.error),
    };
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: SizedBox(width: 24, height: 24, child: leading),
      title: Text(
        task.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: p != null && p.status == UploadStatus.running
          ? LinearProgressIndicator(value: byteFraction)
          : null,
    );
  }
}
