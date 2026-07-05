import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

/// Renders a `/foo/bar/baz` style breadcrumb for the current folder, with
/// each segment tappable.
class CloudFolderBreadcrumb extends StatelessWidget {
  const CloudFolderBreadcrumb({
    super.key,
    required this.storage,
    required this.folderId,
    required this.onNavigate,
    this.rootLabel = 'Home',
  });

  final CloudStorage storage;
  final String folderId;

  /// Called with the [CloudFolder] (or a synthetic root) to navigate to.
  final void Function(CloudNode folder) onNavigate;
  final String rootLabel;

  @override
  Widget build(BuildContext context) {
    // chevron_right is NOT auto-mirroring — pick the icon that points
    // "deeper" in the current text direction.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final chevron = isRtl ? Icons.chevron_left : Icons.chevron_right;

    return FutureBuilder<List<CloudNode>>(
      future: _ancestorChain(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 32);
        final chain = snap.data!;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              for (var i = 0; i < chain.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(chevron, size: 18),
                  ),
                InkWell(
                  onTap: () => onNavigate(chain[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      i == 0 ? rootLabel : chain[i].name,
                      style: TextStyle(
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
      },
    );
  }

  Future<List<CloudNode>> _ancestorChain() async {
    final chain = <CloudNode>[await storage.getNode(kRootFolderId)];
    if (folderId == kRootFolderId) return chain;
    final tail = <CloudNode>[];
    var current = await storage.getNode(folderId);
    tail.add(current);
    while (current.parentId.isNotEmpty) {
      current = await storage.getNode(current.parentId);
      tail.add(current);
    }
    return chain + tail.reversed.toList();
  }
}
