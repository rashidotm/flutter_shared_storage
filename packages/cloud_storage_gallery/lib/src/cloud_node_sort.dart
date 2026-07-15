import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// Field that a [CloudNodeSort] orders on.
enum CloudNodeSortField {
  /// Alphabetical, case-insensitive.
  name,

  /// Newer / older by [CloudNode.createdAt].
  createdAt,

  /// Newer / older by [CloudNode.updatedAt].
  updatedAt,

  /// Bigger / smaller by [CloudFile.sizeBytes]. Folders and links have
  /// no size — they compare as 0 (i.e. cluster at the low end when
  /// ascending, the high end when descending).
  size,

  /// Group by kind: folders → links → files. Ties are broken by name.
  type,
}

/// Immutable description of how the gallery grid should order its nodes.
///
/// Applied client-side by [sortCloudNodes] — no backend index required.
@immutable
class CloudNodeSort {
  const CloudNodeSort({
    this.field = CloudNodeSortField.name,
    this.ascending = true,
    this.foldersFirst = true,
  });

  final CloudNodeSortField field;

  /// `true` for A→Z / oldest-first / smallest-first, depending on [field].
  final bool ascending;

  /// When `true`, folders always sort before non-folder nodes regardless
  /// of [field]. Ties within the folder / non-folder group are broken by
  /// [field] as usual.
  final bool foldersFirst;

  CloudNodeSort copyWith({
    CloudNodeSortField? field,
    bool? ascending,
    bool? foldersFirst,
  }) =>
      CloudNodeSort(
        field: field ?? this.field,
        ascending: ascending ?? this.ascending,
        foldersFirst: foldersFirst ?? this.foldersFirst,
      );

  @override
  bool operator ==(Object other) =>
      other is CloudNodeSort &&
      other.field == field &&
      other.ascending == ascending &&
      other.foldersFirst == foldersFirst;

  @override
  int get hashCode => Object.hash(field, ascending, foldersFirst);
}

/// Returns a new list of [nodes] sorted according to [sort]. Does not
/// mutate the input.
List<CloudNode> sortCloudNodes(List<CloudNode> nodes, CloudNodeSort sort) {
  final sorted = List<CloudNode>.of(nodes);
  sorted.sort((a, b) {
    if (sort.foldersFirst) {
      final aIsFolder = a is CloudFolder;
      final bIsFolder = b is CloudFolder;
      if (aIsFolder != bIsFolder) return aIsFolder ? -1 : 1;
    }
    final cmp = switch (sort.field) {
      CloudNodeSortField.name =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      CloudNodeSortField.createdAt => a.createdAt.compareTo(b.createdAt),
      CloudNodeSortField.updatedAt => a.updatedAt.compareTo(b.updatedAt),
      CloudNodeSortField.size => _sizeOf(a).compareTo(_sizeOf(b)),
      CloudNodeSortField.type => _typeOrder(a).compareTo(_typeOrder(b)),
    };
    // Stable tiebreaker: nodes with the same primary key sort by name so
    // the order is deterministic even when the primary comparator is a
    // draw (e.g. two files with identical sizes).
    final tie =
        cmp != 0 ? cmp : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return sort.ascending ? tie : -tie;
  });
  return sorted;
}

int _sizeOf(CloudNode n) => n is CloudFile ? n.sizeBytes : 0;

int _typeOrder(CloudNode n) => switch (n) {
      CloudFolder() => 0,
      CloudLink() => 1,
      CloudFile() => 2,
    };
