import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

/// Progress dialog that tracks an [UploadTask] and offers a Cancel button.
///
/// Pops itself when the underlying task reaches a terminal state (success,
/// canceled, or error). Handles the race between the Cancel button and the
/// terminal-status auto-pop so we never pop twice.
class CloudUploadDialog extends StatefulWidget {
  const CloudUploadDialog({
    super.key,
    required this.task,
    this.title = 'Uploading',
    this.cancelLabel = 'Cancel',
  });

  final UploadTask task;
  final String title;
  final String cancelLabel;

  @override
  State<CloudUploadDialog> createState() => _CloudUploadDialogState();
}

class _CloudUploadDialogState extends State<CloudUploadDialog> {
  // Guards against double-pop: the cancel button and the terminal-status
  // handler in the StreamBuilder can both race to dismiss the dialog. If
  // both fire and each calls Navigator.pop, we'd pop whatever's under it.
  bool _popped = false;

  void _popOnce() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: StreamBuilder<UploadProgress>(
        stream: widget.task.progress,
        builder: (context, snap) {
          final p = snap.data;
          if (p == null) {
            return const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (p.isTerminal) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _popOnce());
          }
          final fraction = p.fraction;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: fraction),
              const SizedBox(height: 8),
              Text(
                fraction == null
                    ? '${p.bytesTransferred} bytes'
                    : '${(fraction * 100).toStringAsFixed(0)}%',
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await widget.task.cancel();
            _popOnce();
          },
          child: Text(widget.cancelLabel),
        ),
      ],
    );
  }
}
