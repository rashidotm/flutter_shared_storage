import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;

import 'firestore_schema.dart';

/// Resolves naming conflicts by appending " (n)" until [desiredName] is free
/// among the children of [parentId].
///
/// Examples (assuming `report.pdf` exists):
///   `report.pdf`            -> `report (1).pdf`
///   `report (1).pdf` exists -> `report (2).pdf`
///   `notes`                 -> `notes (1)`            (no extension)
class NameResolver {
  NameResolver(this._nodes);
  final CollectionReference<Map<String, dynamic>> _nodes;

  Future<String> resolve({
    required String parentId,
    required String desiredName,
  }) async {
    if (!await _exists(parentId, desiredName)) return desiredName;

    final ext = p.extension(desiredName);
    final stem = ext.isEmpty
        ? desiredName
        : desiredName.substring(0, desiredName.length - ext.length);

    for (var n = 1; n < 1000; n++) {
      final candidate = '$stem ($n)$ext';
      if (!await _exists(parentId, candidate)) return candidate;
    }
    // Astronomically unlikely; fall through with a timestamp.
    return '$stem (${DateTime.now().millisecondsSinceEpoch})$ext';
  }

  Future<bool> _exists(String parentId, String name) async {
    final q = await _nodes
        .where(kFieldParentId, isEqualTo: parentId)
        .where(kFieldName, isEqualTo: name)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }
}
