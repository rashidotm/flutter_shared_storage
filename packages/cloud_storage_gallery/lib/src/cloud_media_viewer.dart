import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';

/// Pageable viewer for a list of [CloudFile] media (images + videos).
///
/// Headless — this widget is just the swipeable content. The consumer is
/// responsible for placing it inside a [Scaffold] (or any bounded parent),
/// providing an app bar / back button, and reacting to page changes via
/// [onPageChanged] if they want to display the current file's name.
///
/// Typical use:
///
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => Scaffold(
///     appBar: AppBar(), // gives you the back button automatically
///     body: CloudMediaViewer(
///       files: mediaSiblings,
///       initialIndex: mediaSiblings.indexOf(tappedFile),
///     ),
///   ),
/// ));
/// ```
class CloudMediaViewer extends StatefulWidget {
  const CloudMediaViewer({
    super.key,
    required this.files,
    this.initialIndex = 0,
    this.onPageChanged,
  });

  final List<CloudFile> files;
  final int initialIndex;
  final void Function(int index, CloudFile file)? onPageChanged;

  @override
  State<CloudMediaViewer> createState() => _CloudMediaViewerState();
}

class _CloudMediaViewerState extends State<CloudMediaViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SafeArea keeps content (especially Chewie's video controls) above
    // the bottom gesture bar / on-screen buttons on Android and away from
    // notches / rounded corners on iOS. The consumer's Scaffold+AppBar
    // handles the top; we still request `top: true` so this widget stays
    // correct if consumers use it without an AppBar.
    return SafeArea(
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.files.length,
        onPageChanged: (i) => widget.onPageChanged?.call(i, widget.files[i]),
        itemBuilder: (context, i) {
          final f = widget.files[i];
          if (f.isVideo) return _VideoPage(file: f);
          return _ImagePage(file: f);
        },
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.file});
  final CloudFile file;

  @override
  Widget build(BuildContext context) {
    final url = file.previewUrl?.isNotEmpty == true
        ? file.previewUrl!
        : file.downloadUrl;
    final theme = Theme.of(context);
    return PhotoViewGallery(
      pageOptions: [
        PhotoViewGalleryPageOptions.customChild(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, _) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (_, _, _) =>
                const Center(child: Icon(Icons.broken_image, size: 64)),
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
        ),
      ],
      // photo_view requires a background decoration. Use the M3 surface
      // color so the viewer follows the app's light/dark theme consistently
      // with the rest of the gallery widgets.
      backgroundDecoration: BoxDecoration(color: theme.colorScheme.surface),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.file});
  final CloudFile file;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    VideoPlayerController? created;
    try {
      final url = widget.file.downloadUrl;
      final cacheManager = DefaultCacheManager();

      // If a cached copy already exists, play it directly — instant start,
      // no network. Otherwise, stream from the network for immediate
      // playback and kick off a background download so the NEXT view uses
      // the cache. Same "stream now, cache for later" behavior that
      // dedicated caching video players (like cached_video_player_plus)
      // implement internally, but compatible with Chewie.
      final cached = await cacheManager.getFileFromCache(url);
      final VideoPlayerController controller;
      if (cached != null) {
        controller = VideoPlayerController.file(cached.file);
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        unawaited(cacheManager.downloadFile(url).then((_) {}, onError: (_) {}));
      }
      created = controller;

      await controller.initialize();
      if (!mounted) {
        // Page was swiped away / closed mid-initialize. dispose() already
        // ran with _video == null, so this controller is ours to release.
        await controller.dispose();
        return;
      }
      setState(() {
        _video = controller;
        _chewie = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          // Chewie pushes its fullscreen page as a new route, outside the
          // bridge wrapped around the inline player in build(). Rebuild
          // that page ourselves (material_ui Scaffold, black backdrop —
          // same as Chewie's default) and bridge Chewie's legacy-Material
          // controls there too.
          routePageBuilder: (context, animation, secondary, provider) =>
              Scaffold(
                resizeToAvoidBottomInset: false,
                body: Container(
                  alignment: Alignment.center,
                  color: Colors.black,
                  // Temporary migration utility; remove with #4 once chewie
                  // is on material_ui.
                  // ignore: deprecated_member_use
                  child: MaterialUiCompatibilityBridge(child: provider),
                ),
              ),
        );
      });
    } catch (e) {
      // A failed initialize() still owns native resources.
      await created?.dispose();
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Failed to load video: $_error'));
    }
    final c = _chewie;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Chewie still builds its controls with `package:flutter/material.dart`,
    // whose Theme / MaterialLocalizations are distinct types from
    // material_ui's. The bridge maps our ambient material_ui theme and
    // localizations onto the legacy ones so the controls stay themed and
    // don't assert on missing MaterialLocalizations. Drop once chewie
    // migrates to material_ui (tracked in #4).
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(child: Chewie(controller: c));
  }
}
