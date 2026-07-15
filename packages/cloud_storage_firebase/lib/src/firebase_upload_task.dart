import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:firebase_storage/firebase_storage.dart' as fbs;

import 'node_codec.dart';

/// Adapts a Firebase [fbs.UploadTask] to the platform-interface [UploadTask],
/// committing the Firestore metadata document on success.
class FirebaseUploadTask implements UploadTask {
  FirebaseUploadTask({
    required fbs.UploadTask storageTask,
    required DocumentReference<Map<String, dynamic>> nodeDoc,
    required Future<void> Function(fbs.TaskSnapshot snap) onSuccess,
    required this.name,
  })  : _storageTask = storageTask,
        _nodeDoc = nodeDoc,
        _onSuccess = onSuccess {
    _wire();
  }

  @override
  final String name;

  final fbs.UploadTask _storageTask;
  final DocumentReference<Map<String, dynamic>> _nodeDoc;
  final Future<void> Function(fbs.TaskSnapshot snap) _onSuccess;

  final _progress = StreamController<UploadProgress>.broadcast();
  final _result = Completer<CloudFile>();

  void _wire() {
    _storageTask.snapshotEvents.listen(
      (snap) {
        // When the underlying storage task reports success we're NOT
        // actually done — the onSuccess block below still has to upload
        // thumbnail + preview variants (if any) and commit URLs to
        // Firestore. Mask that state as `running` with an indeterminate
        // total so the progress stream stays non-terminal until every
        // piece of work is finished. The real terminal success event is
        // emitted after onSuccess resolves.
        final storageDone = snap.state == fbs.TaskState.success;
        _progress.add(
          UploadProgress(
            bytesTransferred: snap.bytesTransferred,
            totalBytes: storageDone
                ? null
                : (snap.totalBytes <= 0 ? null : snap.totalBytes),
            status: storageDone ? UploadStatus.running : _statusFor(snap.state),
          ),
        );
      },
      onError: (Object e, StackTrace st) {
        _progress.add(
          UploadProgress(
            bytesTransferred: 0,
            totalBytes: null,
            status: UploadStatus.error,
            error: e,
          ),
        );
        if (!_result.isCompleted) {
          _result.completeError(
            UploadFailedException('Upload failed', cause: e),
            st,
          );
        }
        unawaited(_progress.close());
      },
    );

    unawaited(() async {
      try {
        final snap = await _storageTask;
        await _onSuccess(snap);
        final doc = await _nodeDoc.get();
        final node = nodeFromSnapshot(doc);
        if (node is! CloudFile) {
          throw const UploadFailedException(
            'Uploaded node is not a file (schema mismatch)',
          );
        }
        _progress.add(
          UploadProgress(
            bytesTransferred: snap.bytesTransferred,
            totalBytes: snap.totalBytes <= 0 ? null : snap.totalBytes,
            status: UploadStatus.success,
          ),
        );
        _result.complete(node);
      } catch (e, st) {
        // Rollback: drop the pre-created Firestore doc so cancelled/failed
        // uploads don't leave orphaned entries in the folder listing.
        // Best-effort — swallow any secondary error.
        try {
          await _nodeDoc.delete();
        } catch (_) {
          // ignored
        }
        // Emit a terminal error to the progress stream so any listening
        // dialog can pop. Without this, if the storage task succeeded
        // but onSuccess (thumbnail uploads / Firestore update) threw,
        // no terminal event would fire — because our snapshot listener
        // masks storage success as `running` — and the UI would hang.
        _progress.add(
          UploadProgress(
            bytesTransferred: 0,
            totalBytes: null,
            status: UploadStatus.error,
            error: e,
          ),
        );
        if (!_result.isCompleted) {
          _result.completeError(
            e is CloudStorageException
                ? e
                : UploadFailedException('Upload failed', cause: e),
            st,
          );
        }
      } finally {
        await _progress.close();
      }
    }());
  }

  @override
  Stream<UploadProgress> get progress => _progress.stream;

  @override
  Future<CloudFile> get result => _result.future;

  @override
  Future<void> cancel() async {
    await _storageTask.cancel();
  }

  static UploadStatus _statusFor(fbs.TaskState state) {
    switch (state) {
      case fbs.TaskState.running:
        return UploadStatus.running;
      case fbs.TaskState.paused:
        return UploadStatus.paused;
      case fbs.TaskState.success:
        return UploadStatus.success;
      case fbs.TaskState.canceled:
        return UploadStatus.canceled;
      case fbs.TaskState.error:
        return UploadStatus.error;
    }
  }
}
