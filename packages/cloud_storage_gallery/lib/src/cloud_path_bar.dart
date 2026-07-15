import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';

import 'cloud_breadcrumb.dart';

/// A path/navigation bar rendered inside the body of a folder browser
/// (typically the first row below the consumer-supplied `AppBar`).
///
/// Layout: `[back] [up] <breadcrumb>` where the breadcrumb is a scrollable
/// [CloudFolderBreadcrumb] filling the remaining horizontal space.
///
/// * [onBack] — invoked by the leading arrow. When null, the button
///   renders disabled. Wire this to your in-app folder-history stack.
/// * [onUp] — invoked by the "one level up" arrow. When null, the
///   button renders disabled — pass null when the current folder is the
///   root or when the parent isn't yet known.
/// * [onNavigate] — invoked when the user taps any breadcrumb segment.
///   Argument is the tapped ancestor (or the synthetic root).
///
/// Icons are direction-aware: in RTL, "back" points right and the
/// breadcrumb chevrons point left. Standard Material icons that
/// auto-mirror are used where available.
class CloudPathBar extends StatelessWidget {
  const CloudPathBar({
    super.key,
    required this.storage,
    required this.folderId,
    required this.onNavigate,
    this.onBack,
    this.onUp,
    this.chain,
    this.rootLabel,
  });

  final CloudStorage storage;
  final String folderId;
  final List<CloudNode>? chain;
  final String? rootLabel;
  final void Function(CloudNode) onNavigate;
  final VoidCallback? onBack;
  final VoidCallback? onUp;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      // Subtle divider line beneath the bar to visually separate the
      // path chrome from the grid below.
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: onUp,
            ),
            Expanded(
              child: CloudFolderBreadcrumb(
                storage: storage,
                folderId: folderId,
                chain: chain,
                rootLabel: rootLabel,
                onNavigate: onNavigate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
