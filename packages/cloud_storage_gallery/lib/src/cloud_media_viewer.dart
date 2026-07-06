import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_storage_platform_interface/cloud_storage_platform_interface.dart';
import 'package:flutter/material.dart';
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
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

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
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, size: 64),
            ),
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
        ),
      ],
      // photo_view requires a background decoration. Use the scaffold color
      // so the viewer follows the app's light/dark theme.
      backgroundDecoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
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

      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _video = controller;
        _chewie = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
        );
      });
    } catch (e) {
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
      return Center(
        child: Text('Failed to load video: $_error'),
      );
    }
    final c = _chewie;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: c);
  }
}
